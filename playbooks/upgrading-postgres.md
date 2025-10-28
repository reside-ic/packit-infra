# Upgrading PostgreSQL

These instructions are based on [the NixOS manual][nixos-postgres-upgrading].
Refer to it for more context and details.

PostgreSQL requires manual offline intervention when upgrading to a new major
version. The broad steps are:
- Stop the existing PostgreSQL and services that depend on it.
- Run the Postgres migration tool to create a new database from the old one.
- Start the new PostgreSQL installation and services that depend on it.
- Delete the old database.

To make the migration easier and automate the process, we use a script defined
in [`modules/postgres-upgrade.nix`][postgres-upgrade.nix].

The steps below assuming we are upgrading from PostgreSQL 16 to 17. Adjust the
numbers are needed to match your needs.

1. Edit your local copy of [`machines/common/services.nix`][services.nix],
   setting a value for `upgradePackage`:
   ```nix
   services.postgresql = {
       # [...]
       package = pkgs.postgresql_16;
       upgradePackage = pkgs.postgresql_17;
   };
   ```
1. Deploy the modified configuration to the target server.
1. Connect to the server and run the `upgrade-pg-cluster` command. This will
   automatically stop postgresql and packit-api.
1. Edit [`machines/common/services.nix`][services.nix] again, updating the
   value of `package` and commenting out `upgradePackage`:
   ```nix
   services.postgresql = {
       # [...]
       package = pkgs.postgresql_17;
       # upgradePackage = pkgs.postgresql_17;
   };
   ```
1. Deploy the modified configuration to the target server.
1. Make sure everything looks as expected, by checking the server's logs and logging into Packit.
1. Connect to the server and run `/var/lib/postgresql/17/delete_old_cluster.sh` to delete the old files.
1. Make a PR with the final changes.

[nixos-postgres-upgrading]: https://nixos.org/manual/nixos/stable/#module-services-postgres-upgrading
[postgres-upgrade.nix]: ../modules/postgres-upgrade.nix
[services.nix]: ../machines/common/services.nix
