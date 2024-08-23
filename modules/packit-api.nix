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
      };
      environmentFiles = lib.mkOption {
        type = types.listOf types.path;
        default = [ ];
      };
      environment = lib.mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
    };
  };

  cfg = config.services.packit-api;
in
{
  options.services.packit-api = {
    image = lib.mkOption {
      type = types.str;
      default = "mrcide/packit-api:${lib.substring 0 7 pkgs.packit-app.src.rev}";
    };

    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
    };
  };

  # Building gradle apps with Nix is a hot mess. Gradle doesn't separate
  # fetching dependencies from building, which makes it very difficult to make
  # reproducible builds. nixpkgs is full of hacks to work around this, I tried
  # to reproduce some of them to build packit but nothing worked.
  # 
  # There's now a half decent solution available on the master branch of
  # nixpkgs we may want to consider in the future:
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/tools/build-managers/gradle/README.md
  #
  # Until this point, we just run the docker image that is build by the
  # Packit CI.
  config.virtualisation.oci-containers.containers =
    lib.mkMerge
      (lib.mapAttrsToList
        (name: instanceCfg: {
          "packit-api-${name}" = {
            image = "${image.finalImageName}:${image.finalImageTag}@${image.imageDigest}";
            imageFile = pkgs.dockerTools.pullImage image;
            extraOptions = [ "--network=host" ];
            inherit (instanceCfg) environmentFiles;
            environment = {
              SERVER_PORT = toString instanceCfg.port;
              PACKIT_OUTPACK_SERVER_URL = instanceCfg.outpack_server_url;
              PACKIT_DB_URL = instanceCfg.database.url;
              PACKIT_DB_USER = instanceCfg.database.user;
              PACKIT_DB_PASSWORD = instanceCfg.database.password;
              PACKIT_API_ROOT = instanceCfg.api_root;
              PACKIT_AUTH_METHOD = instanceCfg.authentication.method;
            } // (lib.optionalAttrs (instanceCfg.authentication.method == "github") {
              PACKIT_AUTH_REDIRECT_URL = instanceCfg.authentication.github.redirect_url;
              PACKIT_AUTH_GITHUB_ORG = instanceCfg.authentication.github.org;
              PACKIT_AUTH_GITHUB_TEAM = instanceCfg.authentication.github.team;
            }) // instanceCfg.environment;
          };
        })
        cfg.instances);
}
