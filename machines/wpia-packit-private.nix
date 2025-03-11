{
  imports = [
    ./common/hardware-configuration.nix
    ./common/disk-config.nix
    ./common/base.nix
    ./common/services.nix
  ];

  networking.hostName = "wpia-packit-private";

  vault.secrets = {
    github-oauth.key = "packit/oauth/private";
    ssl-certificate = {
      path = "/var/secrets/packit.cert";
      key = "packit/ssl/private/cert";
    };
    ssl-key = {
      path = "/var/secrets/packit.key";
      key = "packit/ssl/private/key";
    };
  };

  services.multi-packit = {
    enable = true;
    domain = "packit-private.dide.ic.ac.uk";
    sslCertificate = "/var/secrets/packit.cert";
    sslCertificateKey = "/var/secrets/packit.key";
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
