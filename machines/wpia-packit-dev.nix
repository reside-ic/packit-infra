{ pkgs, config, lib, self, ... }:
{
  imports = [
    ./common/hardware-configuration.nix
    ./common/disk-config.nix
    ./common/base.nix
    ./common/services.nix
    ./common/autodeploy.nix
  ];

  networking.hostName = "wpia-packit-dev";

  vault.secrets = {
    "ssl-certificate".key = "packit/ssl/dev/cert";
    "ssl-key".key = "packit/ssl/dev/key";
    "github-oauth".key = "packit/oauth/dev";
  };
  services.multi-packit = {
    enable = true;
    domain = "packit-dev.dide.ic.ac.uk";
    instances = [ "reside-dev" ];
  };
  services.packit-api.instances = {
    reside-dev = {
      defaultRoles = [ "ADMIN" ];
      authentication = {
        method = "github";
        github.org = "reside-ic";
      };
    };
  };
}