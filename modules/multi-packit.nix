{ pkgs, config, lib, ... }:
let
  inherit (lib) types;

  instanceModule = { name, ... }: {
    options = {
      github_org = lib.mkOption {
        description = "GitHub organisation used for authentication";
        type = types.str;
      };
      github_team = lib.mkOption {
        description = "GitHub team used for authentication";
        type = types.str;
      };
      ports = {
        outpack = lib.mkOption { type = types.port; };
        packit = lib.mkOption { type = types.port; };
      };
    };
  };

  cfg = config.services.multi-packit;
  foreachInstance = f: lib.mkMerge (lib.mapAttrsToList f cfg.instances);

  landingPage = pkgs.runCommand "packit-index"
    {
      data = pkgs.writers.writeJSON "values.json" {
        instances = lib.attrNames cfg.instances;
      };
      template = ../index.html.jinja;
      nativeBuildInputs = [ pkgs.jinja2-cli ];
    } ''
    mkdir -p $out
    jinja2 $template $data > $out/index.html
  '';

in
{
  options.services.multi-packit = {
    enable = lib.mkEnableOption "multi-tenant Packit service";
    domain = lib.mkOption {
      description = "the domain name on which the service is hosted";
      type = types.str;
    };
    authenticationMethod = lib.mkOption {
      type = types.enum [ "basic" "github" ];
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
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
    };
    corsAllowedOrigins = lib.mkOption {
      type = types.commas;
      default = "https://${cfg.domain}";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      ensureUsers = foreachInstance (name: instanceCfg: [{
        inherit name;
        ensureDBOwnership = true;
      }]);

      ensureDatabases = foreachInstance (name: instanceCfg: [ name ]);
    };

    services.outpack.instances = foreachInstance (name: instanceCfg: {
      "${name}" = {
        port = instanceCfg.ports.outpack;
      };
    });

    services.packit-api.instances = foreachInstance (name: instanceCfg: {
      "${name}" = {
        api_root = "https://${cfg.domain}/${name}/packit/api";
        port = instanceCfg.ports.packit;
        outpack_server_url = "http://localhost:${toString instanceCfg.ports.outpack}";
        authentication = {
          method = cfg.authenticationMethod;
          github.redirect_url = "https://${cfg.domain}/${name}/redirect";
          github.org = instanceCfg.github_org;
          github.team = instanceCfg.github_team;
        };
        database.url = "jdbc:postgresql://localhost:5432/${name}?stringtype=unspecified";
        database.user = name;
        database.password = name;
        environmentFiles = [
          "/var/secrets/packit-jwt"
        ] ++ lib.optionals (cfg.authenticationMethod == "github") [
          cfg.githubOAuthSecret
        ];
        environment.PACKIT_CORS_ALLOWED_ORIGINS = cfg.corsAllowedOrigins;
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
      locations = foreachInstance (name: instanceCfg: {
        "= /${name}" = {
          return = "301 /${name}/";
        };

        "~ ^/${name}(?<path>/.*)$" = {
          root = pkgs.packit-app.override {
            PUBLIC_URL = "/${name}";
            PACKIT_NAMESPACE = name;
          };
          tryFiles = "$path /index.html =404";
        };

        "^~ /${name}/packit/api/" = {
          priority = 999;
          proxyPass = "http://localhost:${toString instanceCfg.ports.packit}/";
        };
      });
    };

    services.metrics-proxy.endpoints = foreachInstance (name: instanceCfg: {
      "outpack_server/${name}" = {
        upstream = "http://localhost:${toString instanceCfg.ports.outpack}/metrics";
        labels = {
          job = "outpack_server";
          project = name;
        };
      };
    });

    systemd.services."generate-jwt-secret" = {
      wantedBy = foreachInstance (name: _: [ "packit-api-${name}.service" ]);
      before = foreachInstance (name: _: [ "packit-api-${name}.service" ]);

      serviceConfig.Type = "oneshot";

      script = ''
        if [[ ! -f /var/secrets/packit-jwt ]]; then
          mkdir -p /var/secrets
          cat > /var/secrets/packit-jwt <<EOF
        PACKIT_JWT_SECRET=$(${pkgs.openssl}/bin/openssl rand -hex 32)
        EOF
        fi
      '';
    };
  };
}
