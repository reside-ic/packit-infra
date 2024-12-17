{ config, lib, root, pkgs, ... }:
let cfg = config.services.metrics-proxy;
in {
  options.services.metrics-proxy = {
    enable = lib.mkEnableOption "Monitoring proxy";
    domain = lib.mkOption {
      description = "the domain name on which the service is hosted";
      type = lib.types.str;
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
    };
    endpoints = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          upstream = lib.mkOption {
            type = lib.types.str;
          };
          labels = lib.mkOption {
            default = { };
            type = lib.types.attrsOf lib.types.str;
          };
        };
      });
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts.metrics = {
      serverName = cfg.domain;
      listen = [{
        addr = "0.0.0.0";
        port = cfg.port;
        ssl = false;
      }];
      root = pkgs.emptyDirectory;
      locations =
        let
          mkTarget = path: endpoint: {
            targets = [ "${cfg.domain}:${builtins.toString cfg.port}" ];
            labels = endpoint.labels // {
              "__metrics_path__" = "/targets/${path}";
            };
          };
          targets = lib.mapAttrsToList mkTarget cfg.endpoints;
          indexLocation = {
            "= /targets" = {
              alias = pkgs.writers.writeJSON "index.json" targets;
              extraConfig = ''
                default_type application/json;
              '';
            };
          };
          mkLocation = path: endpoint: lib.nameValuePair "= /targets/${path}" {
            proxyPass = endpoint.upstream;
          };
        in
        indexLocation // (lib.mapAttrs' mkLocation cfg.endpoints);
    };
  };
}
