{ pkgs, self', lib, config, ... }:
let
  inherit (lib) types;
  instanceModule = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "the outpack server";
      port = lib.mkOption {
        description = "Port on which the outpack server listens to";
        default = 8000;
        type = types.port;
      };
      path = lib.mkOption {
        description = "Path to the outpack store";
        default = "/var/lib/outpack/${name}";
        type = types.path;
      };
    };
  };

  foreachInstance = f: lib.mkMerge (lib.mapAttrsToList f config.services.outpack.instances);
in
{
  options.services.outpack = {
    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
    };
  };

  config.systemd.services = foreachInstance (name: instanceCfg: lib.mkIf instanceCfg.enable {
    "outpack-${name}" = {
      description = "Outpack ${name}";
      wantedBy = [ "multi-user.target" ];
      preStart = ''
        if [[ ! -d ${instanceCfg.path} ]]; then
          printf >&2 "Initializing outpack root at %s" "${instanceCfg.path}"
          ${self'.packages.outpack_server}/bin/outpack init --require-complete-tree --use-file-store ${instanceCfg.path}
        fi
      '';
      serviceConfig = {
        ExecStart = "${self'.packages.outpack_server}/bin/outpack start-server --root ${instanceCfg.path} --listen 127.0.0.1:${toString instanceCfg.port}";
      };
    };
  });
}
