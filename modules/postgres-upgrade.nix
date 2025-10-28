# This module exposes a script to ease postgres upgrades.
# It is based off the NixOS manual: https://nixos.org/manual/nixos/stable/#module-services-postgres-upgrading

{ config
, lib
, options
, pkgs
, ...
}:
let
  cfg = config.services.postgresql;
  oldPostgres = cfg.finalPackage;
  newPostgres = cfg.upgradePackage;
  upgradeScript = pkgs.writeScriptBin "upgrade-pg-cluster" ''
    set -eux

    # packit-api has a Requires on postgresql so will stop automatically.
    systemctl stop postgresql

    export NEWDATA="/var/lib/postgresql/${newPostgres.psqlSchema}"
    export NEWBIN="${newPostgres}/bin"

    export OLDDATA="${cfg.dataDir}"
    export OLDBIN="${cfg.finalPackage}/bin"

    install -d -m 0700 -o postgres -g postgres "$NEWDATA"
    cd "$NEWDATA"
    sudo -u postgres "$NEWBIN/initdb" -D "$NEWDATA" ${lib.escapeShellArgs cfg.initdbArgs}

    sudo -u postgres "$NEWBIN/pg_upgrade" \
      --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
      --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
      "$@"
  '';

  enableScript = options.services.postgresql.upgradePackage.isDefined;
in
{
  config = lib.mkIf enableScript {
    environment.systemPackages = [ upgradeScript ];
    warnings = lib.mkIf (newPostgres.psqlSchema == oldPostgres.psqlSchema) [
      "Target Postgres version already matches current one"
    ];
  };

  options.services.postgresql = {
    upgradePackage = lib.mkOption {
      type = lib.types.package;

      example = lib.literalExpression "pkgs.postgresql_17";
      description = ''
        The postgres package that we will upgrade to.
      '';
    };
  };
}
