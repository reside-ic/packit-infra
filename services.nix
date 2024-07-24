{ pkgs, ... }:
{
  services.openssh.enable = true;
  services.multi-packit = {
    enable = true;
    domain = "packit.dide.ic.ac.uk";
    instances = {
      priority-pathogens = {
        github_org = "mrc-ide";
        github_team = "priority-pathogens";
        ports = {
          outpack = 8000;
          packit = 8080;
        };
      };
    };
  };
}
