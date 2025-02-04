{ pkgs, config, inputs, ... }:
{
  services.nginx.enable = true;
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
      upstream = "http://127.0.0.1:${toString config.services.prometheus.exporters.node.port}/metrics";
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
