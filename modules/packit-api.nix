{ pkgs, config, lib, ... }:
let
  inherit (lib) types;

  instanceModule = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "the Packit API server";
      apiRoot = lib.mkOption {
        type = types.str;
      };
      port = lib.mkOption {
        default = 8080;
        type = types.port;
      };
      management-port = lib.mkOption {
        default = 8081;
        type = types.port;
      };
      outpackServerUrl = lib.mkOption {
        default = "http://localhost:8000";
        type = types.str;
      };
      database.url = lib.mkOption {
        description = "URL to database";
        default = "jdbc:postgresql://127.0.0.1:5432/packit?stringtype=unspecified";
        type = types.str;
      };
      database.user = lib.mkOption {
        type = types.str;
      };
      database.password = lib.mkOption {
        type = types.str;
      };
      authentication.method = lib.mkOption {
        description = "Authentication method";
        type = types.enum [ "basic" "github" ];
      };
      authentication.github.redirect_url = lib.mkOption {
        description = "URL to which to redirect following an authentication attempt";
        type = types.str;
      };
      authentication.github.org = lib.mkOption {
        description = "GitHub organisation used for authentication";
        type = types.str;
      };
      authentication.github.team = lib.mkOption {
        description = "GitHub team used for authentication";
        type = types.str;
        default = "";
      };
      corsAllowedOrigins = lib.mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      defaultRoles = lib.mkOption {
        description = "Default list of roles assigned to new users";
        type = types.listOf types.str;
        default = [ ];
      };
      environmentFiles = lib.mkOption {
        type = types.listOf types.path;
        default = [ ];
      };
    };
  };

  cfg = config.services.packit-api;
in
{
  options.services.packit-api.instances = lib.mkOption {
    type = types.attrsOf (types.submodule instanceModule);
    default = { };
  };

  config.systemd.services = lib.mkMerge
    (lib.mapAttrsToList
      (name: instanceCfg: {
        "packit-api-${name}" = {
          description = "Packit API ${name}";
          wantedBy = [ "multi-user.target" ];
          wants = [ "postgresql.service" ];
          after = [ "postgresql.service" ];
          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            ProtectSystem = true;
            ExecStart = "${pkgs.packit-api}/bin/packit-api";
            EnvironmentFile = instanceCfg.environmentFiles;
          };

          environment = {
            SERVER_PORT = toString instanceCfg.port;
            PACKIT_MANAGEMENT_PORT = toString instanceCfg.management-port;
            PACKIT_OUTPACK_SERVER_URL = instanceCfg.outpackServerUrl;
            PACKIT_DB_URL = instanceCfg.database.url;
            PACKIT_DB_USER = instanceCfg.database.user;
            PACKIT_DB_PASSWORD = instanceCfg.database.password;
            PACKIT_API_ROOT = instanceCfg.apiRoot;
            PACKIT_DEFAULT_ROLES = lib.concatStringsSep "," instanceCfg.defaultRoles;
            PACKIT_CORS_ALLOWED_ORIGINS = lib.concatStringsSep "," instanceCfg.corsAllowedOrigins;
            PACKIT_AUTH_METHOD = instanceCfg.authentication.method;
          } // (lib.optionalAttrs (instanceCfg.authentication.method == "github") {
            PACKIT_AUTH_REDIRECT_URL = instanceCfg.authentication.github.redirect_url;
            PACKIT_AUTH_GITHUB_ORG = instanceCfg.authentication.github.org;
            PACKIT_AUTH_GITHUB_TEAM = instanceCfg.authentication.github.team;
          });
        };
      })
      cfg.instances);
}
