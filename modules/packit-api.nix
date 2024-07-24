{ pkgs, config, lib, ... }:
let
  inherit (lib) types;

  instanceModule = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "the Packit API server";
      api_root = lib.mkOption {
        type = types.str;
      };
      port = lib.mkOption {
        default = 8080;
        type = types.port;
      };
      outpack_server_url = lib.mkOption {
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
      authentication.redirect_url = lib.mkOption {
        description = "URL to which to redirect following an authentication attempt";
        type = types.str;
      };
      authentication.org = lib.mkOption {
        description = "GitHub organisation used for authentication";
        type = types.str;
      };
      authentication.team = lib.mkOption {
        description = "GitHub team used for authentication";
        type = types.str;
      };
      environmentFiles = lib.mkOption {
        type = with types; listOf path;
        default = [ ];
      };
    };
  };

  cfg = config.services.packit-api;
  foreachInstance = f: lib.mkMerge (lib.mapAttrsToList f cfg.instances);

  mkInstanceEnv = instanceCfg: {
    SERVER_PORT = toString instanceCfg.port;
    PACKIT_OUTPACK_SERVER_URL = instanceCfg.outpack_server_url;
    PACKIT_DB_URL = instanceCfg.database.url;
    PACKIT_DB_USER = instanceCfg.database.user;
    PACKIT_DB_PASSWORD = instanceCfg.database.password;
    PACKIT_API_ROOT = instanceCfg.api_root;
    PACKIT_AUTH_METHOD = "github";
    PACKIT_AUTH_REDIRECT_URL = instanceCfg.authentication.redirect_url;
    PACKIT_AUTH_GITHUB_ORG = instanceCfg.authentication.org;
    PACKIT_AUTH_GITHUB_TEAM = instanceCfg.authentication.team;
  };
in
{
  options.services.packit-api = {
    image = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
    };

    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
    };
  };

  config.virtualisation.oci-containers.containers =
    lib.mkIf (cfg.image != null) (foreachInstance (name: instanceCfg: {
      "packit-api-${name}" = {
        image = cfg.image;
        extraOptions = [ "--network=host" ];
        inherit (instanceCfg) environmentFiles;
        environment = mkInstanceEnv instanceCfg;
      };
    }));

  config.systemd.services =
    lib.mkIf (cfg.image == null) (foreachInstance (name: instanceCfg: {
      "packit-api-${name}" = {
        description = "Packit API Server ${name}";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.packit-api}/bin/packit-api";
          Environment = lib.mapAttrsToList (k: v: "${k}=${v}");
          EnvironmentFile = instanceCfg.environmentFiles;
        };
      };
    }));
}
