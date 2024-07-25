{ pkgs, ... }:
{
  services.openssh.enable = true;
  services.multi-packit = {
    enable = true;
    domain = "packit.dide.ic.ac.uk";

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
    };
  };
}
