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
      type = lib.types.attrsOf lib.types.str;
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
          mkLocation = name: url: lib.nameValuePair "= ${name}" {
            proxyPass = url;
          };
        in
        lib.mapAttrs' mkLocation cfg.endpoints;
    };
  };
}
