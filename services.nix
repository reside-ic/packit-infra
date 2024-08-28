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
    authenticationMethod = "github";

    sslCertificate = "/var/secrets/packit.cert";
    sslCertificateKey = "/var/secrets/packit.key";
    githubOAuthSecret = "/var/secrets/github-oauth";

    instances = {
      priority-pathogens = {
        github_org = "mrc-ide";
        github_team = "priority-pathogens";
        ports = {
          outpack = 8000;
          packit = 8080;
        };
      };

      reside = {
        github_org = "reside-ic";
        github_team = "everyone";
        ports = {
          outpack = 8001;
          packit = 8081;
        };
      };

      malariaverse-sitefiles = {
        github_org = "mrc-ide";
        github_team = "malaria-orderly";
        ports = {
          outpack = 8002;
          packit = 8082;
        };
      };
    };
  };

  services.metrics-proxy = {
    enable = true;
    domain = "packit.dide.ic.ac.uk";
    endpoints."/node_exporter" = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      port = 9001;
    };
  };
}
