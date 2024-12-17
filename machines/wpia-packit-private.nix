{
  imports = [
    ./common/hardware-configuration.nix
    ./common/disk-config.nix
    ./common/base.nix
    ./common/services.nix
  ];

  networking.hostName = "wpia-packit-private";

  services.multi-packit = {
    enable = true;
    domain = "packit-private.dide.ic.ac.uk";
    instances = [ "kipling" ];
  };

  vault.secrets = {
    "ssl-certificate".key = "packit/ssl/private/cert";
    "ssl-key".key = "packit/ssl/private/key";
    "github-oauth".key = "packit/oauth/private";
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
