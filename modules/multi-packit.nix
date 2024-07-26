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
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      authentication = ''
        local all      all                    trust
        host  all      all     127.0.0.1/32   trust
        host  all      all     ::1/128        trust
      '';

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
        authentication.redirect_url = "https://${cfg.domain}/${name}/redirect";
        authentication.org = instanceCfg.github_org;
        authentication.team = instanceCfg.github_team;
        database.url = "jdbc:postgresql://localhost:5432/${name}?stringtype=unspecified";
        database.user = name;
        database.password = name;
        environmentFiles = [ cfg.githubOAuthSecret ];
        environment.PACKIT_CORS_ALLOWED_ORIGINS = "https://${cfg.domain}";
      };
    });

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.domain}" = {
        forceSSL = true;
        extraConfig = ''
          client_max_body_size 100M;
        '';

        inherit (cfg) sslCertificate sslCertificateKey;

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
    };
  };
}
