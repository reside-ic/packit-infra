{ pkgs, self', lib, config, ... }:
let
  secretModule = {
    options = {
      key = lib.mkOption {
        type = lib.types.str;
        description = "The path to the secret within the Vault KV store";
      };
      fields = lib.mkOption {
        type = lib.types.coercedTo
          (lib.types.listOf lib.types.str)
          (v: lib.listToAttrs (map (k: lib.nameValuePair k k) v))
          (lib.types.attrsOf lib.types.str);
        default = [ "value" ];
        description = ''
          The fields to read from the secret. If format is "plain", only a
          single value may be specified.

          If an attribute set is used and the format is "env", the keys
          represent the names of the environment variables and the values are
          the names of the fields in the KV.
        '';
      };
      mount = lib.mkOption {
        type = lib.types.str;
        default = "secret";
        description = "The name of the mount point of the KV store";
      };
      format = lib.mkOption {
        type = lib.types.enum [ "plain" "env" ];
        default = "plain";
        description = ''
          The format in which to store the format on disk. "plain" stores the
          secret directly in a text file. "env" creates an environment file
          containing a list of key-value assignment, suitable to be loaded, for
          example, via systemd's EnvironmentFile option.
        '';
      };
      path = lib.mkOption {
        type = lib.types.str;
        description = ''
          The path in which the secret will be stored.
        '';
      };
    };
  };
in
{
  options = {
    vault = {
      url = lib.mkOption {
        type = lib.types.str;
        description = "URL to the Vault server from which secrets are pulled";
        default = "https://vault.dide.ic.ac.uk:8200";
      };

      secrets = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule secretModule);
        default = { };
      };

      spec = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = pkgs.writers.writeJSON "secrets.json" config.vault.secrets;
      };

      tool = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = pkgs.runCommand "fetch-secrets"
          {
            nativeBuildInputs = [ pkgs.makeWrapper ];
            meta.mainProgram = "fetch-secrets";
          } ''
          mkdir -p $out/bin
          makeWrapper ${lib.getExe self'.packages.fetch-secrets} $out/bin/fetch-secrets \
            --add-flags --url --add-flags "${config.vault.url}" \
            --add-flags --spec --add-flags "${config.vault.spec}"
        '';
      };
    };
  };

  config = {
    environment.systemPackages = [
      config.vault.tool
    ];
  };
}
