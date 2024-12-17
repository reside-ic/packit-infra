{ pkgs, config, lib, inputs, ... }:
{
  services.nginx.enable = true;
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

  services.multi-packit = {
    sslCertificate = "/var/secrets/packit.cert";
    sslCertificateKey = "/var/secrets/packit.key";
    githubOAuthSecret = "/var/secrets/github-oauth";
  };

  vault.secrets = {
    ssl-certificate.path = "/var/secrets/packit.cert";
    ssl-key.path = "/var/secrets/packit.key";
    github-oauth = {
      path = "/var/secrets/github-oauth";
      fields.PACKIT_GITHUB_CLIENT_ID = "clientId";
      fields.PACKIT_GITHUB_CLIENT_SECRET = "clientSecret";
      format = "env";
    };
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
