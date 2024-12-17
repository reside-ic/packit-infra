{ pkgs, config, lib, inputs, ... }:
{
  services.nginx.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.HostKeyAlgorithms = lib.concatStringsSep "," [
    "rsa-sha2-512"
    "rsa-sha2-256"
    "ssh-ed25519"
    "ssh-rsa" # For ICT
  ];
  services.openssh.settings.Macs = [
    "hmac-sha2-512-etm@openssh.com"
    "hmac-sha2-256-etm@openssh.com"
    "umac-128-etm@openssh.com"
    "hmac-sha2-256" # For ICT
    "hmac-sha2-512" # For ICT
  ];

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

  environment.etc."metrics/static-metrics.prom".text =
    let
      inherit (inputs) self;
      rev = self.rev or self.dirtyRev or "unknown";
    in
    ''
      nixos_configuration_info{revision="${rev}"} 1
    '';

  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = [ "systemd" "textfile" ];
      extraFlags = [ "--collector.textfile.directory=/etc/metrics" ];
      port = 9001;
    };
  };
}
