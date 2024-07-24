{ pkgs, ... }:
{
  services.openssh.enable = true;
  services.packit-api.image = "mrcide/packit-api:0dd3d4e";
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
