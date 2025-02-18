{
  imports = [
    ./common/hardware-configuration.nix
    ./common/disk-config.nix
    ./common/base.nix
    ./common/services.nix
  ];

  networking.hostName = "wpia-packit";

  vault.secrets = {
    "ssl-certificate".key = "packit/ssl/production/cert";
    "ssl-key".key = "packit/ssl/production/key";
    "github-oauth".key = "packit/oauth/production";
  };

  services.multi-packit = {
    enable = true;
    domain = "packit.dide.ic.ac.uk";
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

        service.policies = [
          {
            issuer = "https://token.actions.githubusercontent.com";
            jwkSetUri = "https://token.actions.githubusercontent.com/.well-known/jwks";
            requiredClaims.repository = "mrc-ide/orderly-action";
            grantedPermissions = [ "outpack.read" "outpack.write" ];
          }
          {
            issuer = "https://token.actions.githubusercontent.com";
            jwkSetUri = "https://token.actions.githubusercontent.com/.well-known/jwks";
            requiredClaims.repository = "reside-ic/packit-infra-test-repo";
            grantedPermissions = [ "outpack.read" "outpack.write" "packet.run" ];
          }
        ];
      };

      runner = {
        enable = true;
        repositoryUrl = "https://github.com/reside-ic/packit-infra-test-repo.git";
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

  services.orderly-runner = {
    enable = true;
    workers = 4;
  };
}
