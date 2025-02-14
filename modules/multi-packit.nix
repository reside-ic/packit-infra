{ self', pkgs, config, lib, ... }:
let
  inherit (lib) types;

  cfg = config.services.multi-packit;
  orderlyRunnerCfg = config.services.orderly-runner;
  foreachInstance = f: lib.mkMerge (lib.map f cfg.instances);

  landingPage = pkgs.runCommand "packit-index"
    {
      data = pkgs.writers.writeJSON "values.json" {
        inherit (cfg) instances;
      };
      template = ../index.html.jinja;
      nativeBuildInputs = [ pkgs.jinja2-cli ];
    } ''
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
in
{
  options.services.multi-packit = {
    enable = lib.mkEnableOption "multi-tenant Packit service";
    domain = lib.mkOption {
      description = "the domain name on which the service is hosted";
      type = types.str;
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
    instances = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      ensureUsers = foreachInstance (name: [{
        inherit name;
        ensureDBOwnership = true;
      }]);

      ensureDatabases = foreachInstance (name: [ name ]);
    };

    services.outpack.instances = foreachInstance (name: {
      "${name}" = {
        enable = true;
        port = ports."${name}".outpack;
      };
    });

    services.packit-api.instances = foreachInstance (name: {
      "${name}" = ({ config, ... }: {
        enable = true;
        port = ports."${name}".packit-api;
        management-port = ports."${name}".packit-api-management;

        apiRoot = "https://${cfg.domain}/${name}/packit/api";
        outpackServerUrl = "http://127.0.0.1:${toString ports."${name}".outpack}";
        orderlyRunnerApiUrl = "http://127.0.0.1:${toString orderlyRunnerCfg.port}";
        authentication = {
          github.redirect_url = "https://${cfg.domain}/${name}/redirect";
          service.audience = lib.mkIf (builtins.length config.authentication.service.policies > 0) "https://${cfg.domain}/${name}";
        };
        corsAllowedOrigins = [ "https://${cfg.domain}" ];

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
    });

    systemd.services = foreachInstance (name: {
      "packit-${name}-jwt-secret" = {
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
    });


    services.nginx.virtualHosts."${cfg.domain}" = {
      forceSSL = true;
      extraConfig = ''
        client_max_body_size 2048M;
        absolute_redirect OFF;
      '';

      inherit (cfg) sslCertificate sslCertificateKey;

      root = landingPage;
      locations = foreachInstance (name: {
        "= /${name}" = {
          return = "301 /${name}/";
        };

        "~ ^/${name}(?<path>/.*)$" = {
          root = self'.packages.packit-app.override {
            PUBLIC_URL = "/${name}";
            PACKIT_NAMESPACE = name;
          };
          tryFiles = "$path /index.html =404";
        };

        "^~ /${name}/packit/api/" = {
          priority = 999;
          proxyPass = "http://127.0.0.1:${toString ports."${name}".packit-api}/";
        };
      });
    };

    services.metrics-proxy.endpoints = foreachInstance (name: {
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
    });
  };
}
