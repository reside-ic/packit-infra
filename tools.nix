{ pkgs, ... }:
let
  fetch-secrets = pkgs.writeShellApplication {
    name = "fetch-secrets";
    runtimeInputs = [ pkgs.vault-bin ];
    text = builtins.readFile ./scripts/fetch-secrets.sh;
  };

  grant-role = pkgs.writeShellApplication {
    name = "grant-role";
    runtimeInputs = [ pkgs.postgresql ];
    text = builtins.readFile ./scripts/grant-role.sh;
  };

  create-basic-user = pkgs.writeShellApplication {
    name = "create-basic-user";
    runtimeInputs = [
      pkgs.postgresql
      pkgs.apacheHttpd
    ];
    text = builtins.readFile ./scripts/create-basic-user.sh;
  };

  flyway-packit = pkgs.runCommand "flyway-packit" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper ${pkgs.flyway}/bin/flyway $out/bin/flyway-packit \
      --add-flags -locations=filesystem:${pkgs.packit-api.src}/api/app/src/main/resources/db/migration
  '';
in
{
  environment.systemPackages = [
    fetch-secrets
    grant-role
    create-basic-user
    flyway-packit
  ];
}
