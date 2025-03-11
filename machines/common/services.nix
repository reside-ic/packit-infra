{ config, ... }:
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

  services.packit = {
    githubOAuthSecret = "/var/secrets/github-oauth";
  };

  vault.secrets.github-oauth = {
    path = "/var/secrets/github-oauth";
    format = "env";
    fields.PACKIT_GITHUB_CLIENT_ID = "clientId";
    fields.PACKIT_GITHUB_CLIENT_SECRET = "clientSecret";
  };

  services.metrics-proxy = {
    enable = true;
    domain = config.services.packit.domain;
    endpoints."node_exporter" = {
      upstream = "http://127.0.0.1:${toString config.services.prometheus.exporters.node.port}/metrics";
      labels.job = "machine-metrics";
    };
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = [ "systemd" "textfile" ];
      extraFlags = [ "--collector.textfile.directory=/etc/metrics" ];
      port = 9001;
    };
  };
}
