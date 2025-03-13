{
  imports = [
    ./common/hardware-configuration.nix
    ./common/disk-config.nix
    ./common/base.nix
    ./common/services.nix
  ];

  networking.hostName = "wpia-packit-private";

  vault.secrets.github-oauth.key = "packit/oauth/private";

  services.multi-packit = {
    enable = true;
    enableACME = true;
    domain = "packit-private.dide.ic.ac.uk";
    instances = [ "kipling" ];
  };

  services.packit-api.instances = {
    kipling = {
      defaultRoles = [ "ADMIN" ];
      authentication = {
        method = "github";
        github.org = "mrc-ide";
        github.team = "kipling";
      };
    };
  };
}
