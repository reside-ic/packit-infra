{ pkgs, config, ... }:
{
  services.nginx.enable = true;
  services.openssh.enable = true;
  services.postgresql = {
    enable = true;
    authentication = ''
      local all      all                    trust
      host  all      all     127.0.0.1/32   trust
      host  all      all     ::1/128        trust
    '';
  };

  services.multi-packit = {
    enable = true;
    domain = "packit.dide.ic.ac.uk";

    sslCertificate = "/var/secrets/packit.cert";
    sslCertificateKey = "/var/secrets/packit.key";
    githubOAuthSecret = "/var/secrets/github-oauth";

    instances = [ "priority-pathogens" "reside" "malariaverse-sitefiles" ];
  };

  services.packit-api.instances = {
    priority-pathogens.authentication = {
      method = "github";
      github.org = "mrc-ide";
      github.team = "priority-pathogens";
    };

    reside.authentication = {
      method = "github";
      github.org = "reside-ic";
    };

    malariaverse-sitefiles = {
      defaultRoles = [ "USER" ];
      authentication = {
        method = "github";
        github.org = "malariaverse";
        github.team = "sitefiles";
      };
    };
  };

  services.metrics-proxy = {
    enable = true;
    domain = "packit.dide.ic.ac.uk";
    endpoints."node_exporter" = {
      upstream = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
      labels.job = "machine-metrics";
    };
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      port = 9001;
    };
  };
}
