{ pkgs, lib, config, ... }:
let
  inherit (lib) types;
  instanceModule = { name, ... }: {
    options = {
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

  cfg = config.services.outpack;
in
{
  options.services.outpack = {
    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
    };
  };

  config.systemd.services = lib.mapAttrs'
    (name: instanceCfg: lib.nameValuePair "outpack-${name}" {
      description = "Outpack ${name}";
      wantedBy = [ "multi-user.target" ];
      preStart = ''
        if [[ ! -d ${instanceCfg.path} ]]; then
          ${pkgs.outpack_server}/bin/outpack init --require-complete-tree --use-file-store ${instanceCfg.path}
        fi
      '';
      serviceConfig = {
        ExecStart = "${pkgs.outpack_server}/bin/outpack start-server --root ${instanceCfg.path}";
      };
    })
    cfg.instances;
}
