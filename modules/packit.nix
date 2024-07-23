{ pkgs, config, lib, ... }:
let
  inherit (lib) types;

  instanceModule = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "the Packit API server";
      api_root = lib.mkOption {
        type = types.str;
      };
      redirect_url = lib.mkOption {
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
      environmentFiles = lib.mkOption {
        type = with types; listOf path;
        default = [ ];
      };
    };
  };

  cfg = config.services.packit-api;
  enabledInstances = lib.filterAttrs (name: cfg: cfg.enable) cfg.instances;
in
{
  options.services.packit-api = {
    image = lib.mkOption {
      type = types.str;
    };
    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
    };
  };

  config.virtualisation.oci-containers.containers = lib.mapAttrs'
    (name: instanceCfg: lib.nameValuePair "packit-api-${name}" {
      image = cfg.image;
      extraOptions = [ "--network=host" ];
      inherit (instanceCfg) environmentFiles;
      environment = {
        PACKIT_DB_URL = instanceCfg.database.url;
        PACKIT_DB_USER = instanceCfg.database.user;
        PACKIT_DB_PASSWORD = instanceCfg.database.password;

        PACKIT_API_ROOT = instanceCfg.api_root;
        PACKIT_AUTH_METHOD = "github";
        PACKIT_AUTH_REDIRECT_URL = instanceCfg.redirect_url;

        PACKIT_AUTH_GITHUB_ORG = "mrc-ide";
        PACKIT_AUTH_GITHUB_TEAM = "priority-pathogens";

        # PACKIT_CORS_ALLOWED_ORIGINS
      };
    })
    enabledInstances;
}
