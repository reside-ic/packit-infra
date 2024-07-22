{ pkgs, lib, config, ... }:
let
  inherit (lib) types;
  instanceModule = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "the outpack server";
      path = lib.mkOption {
        description = "Path to the outpack store";
        default = "/var/lib/outpack/${name}";
        type = types.path;
      };
    };
  };

  cfg = config.services.outpack;
  enabledInstances = lib.filterAttrs (name: cfg: cfg.enable) cfg.instances;
in
{
  options.services.outpack = {
    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
    };
  };

  config.systemd.services = lib.mapAttrs'
    (name: cfg: lib.nameValuePair "outpack-${name}" {
      description = "Outpack ${name}";
      wantedBy = [ "multi-user.target" ];
      preStart = ''
        if [[ ! -d ${cfg.path} ]]; then
          ${pkgs.outpack_server}/bin/outpack init --require-complete-tree --use-file-store ${cfg.path}
        fi
      '';
      serviceConfig = {
        ExecStart = "${pkgs.outpack_server}/bin/outpack start-server --root ${cfg.path}";
      };
    })
    enabledInstances;
}
