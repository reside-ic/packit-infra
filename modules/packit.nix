# This file provides the glue that links up all the other modules.
#
# For each Packit instance, it creates an outpack_server and a Packit API
# service, gives them sensible configuration defaults, sets up a database,
# configures nginx, configures metrics, ...
#
# Each individual service can be customized by configuring its own options, eg.
# under `services.packit-api`.

{ self', pkgs, config, lib, ... }:
let
  inherit (lib) types;

  cfg = config.services.packit;
  orderlyRunnerCfg = config.services.orderly-runner;

  landingPage = pkgs.runCommand "packit-index"
    {
      nativeBuildInputs = [ pkgs.jinja2-cli ];
      template = ../index.html.jinja;
      data = pkgs.writers.writeJSON "values.json" {
        inherit (cfg) domain instances;
      };
    }
    ''
      mkdir -p $out
      jinja2 $template $data > $out/index.html
    '';

  # Ports get assigned sequentially, starting at 8000 for outpack, 8080 for
  # packit-api, 8160 for packit-api's management interface and a single 
  # orderly runner api at port 8240 for all the instances.
  ports = lib.listToAttrs (lib.imap0
    (idx: name: lib.nameValuePair name {
      outpack = 8000 + idx;
      packit-api = 8080 + idx;
      packit-api-management = 8160 + idx;
    })
    cfg.instances);

  # `cfg.domain` may include a port, which we need to remove when configuring
  # nginx. In practice this only includes a port when running as a local VM,
  # where the server is exposed on the host as 8433.
  serverName = lib.head (lib.splitString ":" cfg.domain);

  commonVhostConfig = {
    forceSSL = true;
    sslCertificate = lib.mkIf (!cfg.enableACME) cfg.sslCertificate;
    sslCertificateKey = lib.mkIf (!cfg.enableACME) cfg.sslCertificateKey;

    # By default nginx will enable the http challenge and try to host
    # challenges under `/.well-known`. Set to null to not do that.
    acmeRoot = null;
    enableACME = cfg.enableACME;

    extraConfig = ''
      absolute_redirect off;
      client_max_body_size 2048M;
    '';
  };

  perInstanceConfig = name: {
    services.postgresql = {
      ensureDatabases = [ name ];
      ensureUsers = [{
        inherit name;
        ensureDBOwnership = true;
      }];
    };

    services.outpack.instances."${name}" = {
      enable = true;
      port = ports."${name}".outpack;
    };

    services.packit-api.instances."${name}" = ({ config, ... }: {
      enable = true;
      port = ports."${name}".packit-api;
      management-port = ports."${name}".packit-api-management;

      apiRoot = "https://${name}.${cfg.domain}/packit/api";
      outpackServerUrl = "http://127.0.0.1:${toString ports."${name}".outpack}";
      orderlyRunnerApiUrl = "http://127.0.0.1:${toString orderlyRunnerCfg.port}";
      authentication = {
        github.redirect_url = "https://${name}.${cfg.domain}/redirect";
        service.audience = lib.mkIf (lib.length config.authentication.service.policies > 0) "https://${name}.${cfg.domain}";
      };
      corsAllowedOrigins = [ "https://${name}.${cfg.domain}" ];

      database = {
        url = "jdbc:postgresql://127.0.0.1:5432/${name}?stringtype=unspecified";
        user = name;
        password = name;
      };

      environmentFiles = [
        "/var/secrets/packit/${name}/jwt-key"
      ] ++ lib.optionals (config.authentication.method == "github") [
        cfg.githubOAuthSecret
      ];
    });

    systemd.services."packit-${name}-jwt-secret" = {
      wantedBy = [ "packit-api-${name}.service" ];
      before = [ "packit-api-${name}.service" ];

      serviceConfig.Type = "oneshot";

      script = ''
        if [[ ! -f /var/secrets/packit/${name}/jwt-key ]]; then
          mkdir -p /var/secrets/packit/${name}
          cat > /var/secrets/packit/${name}/jwt-key <<EOF
        PACKIT_JWT_SECRET=$(${pkgs.openssl}/bin/openssl rand -hex 32)
        EOF
        fi
      '';
    };

    services.nginx.virtualHosts = {
      "${name}.${serverName}" = commonVhostConfig // {
        locations = {
          "/" = {
            root = self'.packages.packit-app;
            tryFiles = "$uri /index.html =404";
          };
          "/packit/api/" = {
            proxyPass = "http://127.0.0.1:${toString ports."${name}".packit-api}/";
          };
        };
      };

      # We used to host Packit at `https://<fqdn>/<instance>`, before moving to
      # `https://<instance>.<fqdn>`. These maintain compatibility:
      # - The API endpoints are mirrored and work using either URL.
      # - Anything else is a permanent redirect, preserving the subpath.
      "${serverName}".locations = {
        "^~ /${name}/packit/api/" = {
          proxyPass = "http://127.0.0.1:${toString ports."${name}".packit-api}/";
        };
        "~ ^/${name}(?<path>/[^\\r\\n]*)$" = {
          return = "301 https://${name}.${cfg.domain}$path";
        };
      };
    };

    services.metrics-proxy.endpoints = {
      "packit-api/${name}" = {
        upstream = "http://127.0.0.1:${toString ports."${name}".packit-api-management}/prometheus";
        labels = {
          job = "packit-api";
          project = name;
        };
      };
      "outpack_server/${name}" = {
        upstream = "http://127.0.0.1:${toString ports."${name}".outpack}/metrics";
        labels = {
          job = "outpack_server";
          project = name;
        };
      };
    };
  };

  globalConfig = lib.mkIf (cfg.instances != [ ]) {
    services.nginx.virtualHosts."${serverName}" = commonVhostConfig // {
      root = landingPage;
    };
  };

  # Ideally we would want to merge the configuration of each instance using
  # something like:
  #
  # config = lib.mkMerge (map perInstanceConfig config.services.packit.instances);
  #
  # Unfortunately this creates an infinite recursion: to construct the argument
  # to `mkMerge` we need to evaluate `config.services.packit.instances`, which
  # forces the evaluation of the top-level of the configuration, which needs to
  # evaluate `mkMerge`, which evaluates its arguments, etc..
  #
  # The workaround is to push the `mkMerge` deeper into the definition:
  #
  # config =
  #   let entries = (map perInstanceConfig config.services.packit.instances);
  #   in {
  #     systemd.services = lib.mkMerge (map (e: e.systemd.services) entries);
  #     services.packit-api = lib.mkMerge (map (e: e.services.packit-api) entries)
  #     ...
  #   };
  #
  # Crucially, this does not overlap with `services.packit.instances`, breaking
  # the cycle. Writing the full expansion is a bit tedious, so `mkNestedMerges`
  # does it instead.
  #
  # Inspired by https://gist.github.com/udf/4d9301bdc02ab38439fd64fbda06ea43.
  mkNestedMerges = paths: entries:
    let
      unset = lib.mkIf false (throw "unexpected");
      valuesForPath = p: map (e: lib.attrByPath p unset e) entries;
      mergedValueForPath = p: lib.mkMerge (valuesForPath p);
      updates = map (p: { path = p; update = lib.const (mergedValueForPath p); }) paths;
    in
    lib.updateManyAttrsByPath updates { };

  instancesConfig =
    let
      paths = [
        [ "services" "postgresql" ]
        [ "services" "outpack" ]
        [ "services" "packit-api" ]
        [ "services" "nginx" ]
        [ "services" "metrics-proxy" ]
        [ "systemd" "services" ]
      ];
    in
    mkNestedMerges paths (lib.map perInstanceConfig cfg.instances);
in
{
  options.services.packit = {
    domain = lib.mkOption {
      description = "The domain name on which the service is hosted";
      type = types.str;
    };
    instances = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
    enableACME = lib.mkOption {
      description = "Obtain certificates from Let's Encrypt";
      type = types.bool;
      default = false;
    };
    sslCertificate = lib.mkOption {
      type = types.path;
    };
    sslCertificateKey = lib.mkOption {
      type = types.path;
    };
    githubOAuthSecret = lib.mkOption {
      type = types.path;
    };
  };

  config = lib.mkMerge [ globalConfig instancesConfig ];
}
