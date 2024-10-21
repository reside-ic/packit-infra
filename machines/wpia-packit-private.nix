{ pkgs, config, lib, ... }: {
  imports = [
    ./common/configuration.nix
  ];

  networking.hostName = "wpia-packit-private";

  vault.secrets = [
    {
      key = "packit/ssl/private/cert";
      path = "/var/secrets/packit.cert";
    }
    {
      key = "packit/ssl/private/key";
      path = "/var/secrets/packit.key";
    }
    {
      key = "packit/oauth/private";
      path = "/var/secrets/github-oauth";
      fields.PACKIT_GITHUB_CLIENT_ID = "clientId";
      fields.PACKIT_GITHUB_CLIENT_SECRET = "clientSecret";
      format = "env";
    }
  ];

  services.multi-packit = {
    enable = true;
    domain = "packit-private.dide.ic.ac.uk";

    sslCertificate = "/var/secrets/packit.cert";
    sslCertificateKey = "/var/secrets/packit.key";
    githubOAuthSecret = "/var/secrets/github-oauth";

    instances = [
      "kipling"
    ];
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
