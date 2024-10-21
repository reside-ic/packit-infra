{ pkgs, config, lib, ... }: {
  imports = [
    ./common/configuration.nix
  ];

  networking.hostName = "wpia-packit";

  vault.secrets = [
    {
      key = "packit/ssl/production/cert";
      path = "/var/secrets/packit.cert";
    }
    {
      key = "packit/ssl/production/key";
      path = "/var/secrets/packit.key";
    }
    {
      key = "packit/oauth/production";
      path = "/var/secrets/github-oauth";
      fields.PACKIT_GITHUB_CLIENT_ID = "clientId";
      fields.PACKIT_GITHUB_CLIENT_SECRET = "clientSecret";
      format = "env";
    }
  ];

  services.multi-packit = {
    enable = true;
    domain = "packit.dide.ic.ac.uk";

    sslCertificate = "/var/secrets/packit.cert";
    sslCertificateKey = "/var/secrets/packit.key";
    githubOAuthSecret = "/var/secrets/github-oauth";

    instances = [
      "priority-pathogens"
      "reside"
      "malariaverse-sitefiles"
      "training"
    ];
  };

  services.packit-api.instances = {
    priority-pathogens.authentication = {
      method = "github";
      github.org = "mrc-ide";
      github.team = "priority-pathogens";

      service.policies = [{
        issuer = "https://token.actions.githubusercontent.com";
        jwkSetUri = "https://token.actions.githubusercontent.com/.well-known/jwks";
        requiredClaims.repository = "mrc-ide/priority-pathogens";
        grantedPermissions = [ "outpack.read" "outpack.write" ];
      }];
    };

    reside = {
      defaultRoles = [ "ADMIN" ];
      authentication = {
        method = "github";
        github.org = "reside-ic";

        service.policies = [{
          issuer = "https://token.actions.githubusercontent.com";
          jwkSetUri = "https://token.actions.githubusercontent.com/.well-known/jwks";
          requiredClaims.repository = "mrc-ide/orderly-action";
          grantedPermissions = [ "outpack.read" "outpack.write" ];
        }];
      };
    };

    malariaverse-sitefiles = {
      defaultRoles = [ "USER" ];
      authentication = {
        method = "github";
        github.org = "malariaverse";
        github.team = "sitefiles";
      };
    };

    training = {
      authentication = {
        method = "github";
        github.org = "mrc-ide";
      };
      defaultRoles = [ "USER" ];
    };
  };
}
