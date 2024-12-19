{ pkgs, config, inputs, ... }:
{
  services.nginx.enable = true;
  services.openssh.enable = true;
  services.postgresql = {
    enable = true;
    ensureUsers = [{
      name = "root";
      ensureClauses.superuser = true;
      ensureClauses.login = true;
    }];
    authentication = ''
      local all      all                    trust
      host  all      all     127.0.0.1/32   trust
      host  all      all     ::1/128        trust
    '';
  };

  services.metrics-proxy = {
    enable = true;
    domain = config.services.multi-packit.domain;
    endpoints."node_exporter" = {
      upstream = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
      labels.job = "machine-metrics";
    };
  };

  services.prometheus.exporters = {
    node =
      let
        inherit (inputs) self;
        rev = self.rev or self.dirtyRev or "unknown";
        staticMetrics = pkgs.writeTextDir "static-metrics.prom" ''
          nixos_configuration_info{revision="${rev}", flake_hash="${self.narHash}"} 1
        '';
      in
      {
        enable = true;
        enabledCollectors = [ "systemd" "textfile" ];
        extraFlags = [ "--collector.textfile.directory=${staticMetrics}" ];
        port = 9001;
      };
  };
}
