{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, self, ... } @inputs:
    let
      pkgsArgs = {
        overlays = [ self.overlays.default ];
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
          "vault"
          "vault-bin"
        ];
      };
    in
    {
      overlays.default = (final: prev: {
        packit = final.callPackage ./packages/packit { };
        outpack_server = final.callPackage ./packages/outpack_server { };
        packit-app = final.callPackage ./packages/packit/packit-app.nix { };
        packit-api = final.callPackage ./packages/packit/packit-api.nix { };
        fetch-secrets = final.writers.writePython3Bin "fetch-secrets"
          {
            libraries = [ final.python3.pkgs.hvac ];
          } ./scripts/fetch-secrets.py;
      });

      nixosConfigurations.wpia-packit = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          { nixpkgs = pkgsArgs; }
        ];
      };

      packages.x86_64-linux =
        let pkgs = import nixpkgs ({ system = "x86_64-linux"; } // pkgsArgs);
        in {
          inherit (pkgs) outpack_server packit-app packit-api packit fetch-secrets;

          default = self.nixosConfigurations.wpia-packit.config.system.build.toplevel;

          deploy = pkgs.writeShellApplication {
            name = "deploy-wpia-packit";
            runtimeInputs = [ pkgs.nixos-rebuild ];
            text = ''
              nixos-rebuild switch \
                --flake .#wpia-packit \
                --target-host root@packit.dide.ic.ac.uk \
                --use-substitutes
            '';
          };

          update-ssh-keys = pkgs.writeShellApplication {
            name = "update-ssh-keys";
            runtimeInputs = [ pkgs.curl ];
            text = builtins.readFile ./scripts/update-ssh-keys.sh;
          };

          diff = pkgs.writeShellApplication {
            name = "diff";
            runtimeInputs = [ pkgs.nix pkgs.nix-diff ];
            text = ''
              current=$(ssh root@packit.dide.ic.ac.uk readlink /run/current-system)
              nix-copy-closure --from root@packit.dide.ic.ac.uk "$current"

              # In theory .drvPath should allow us to use string interpolation
              # instead of re-evaluating the flake, but for some reason it
              # pulls all the build-time dependencies.
              target=$(nix path-info --derivation .#nixosConfigurations.wpia-packit.config.system.build.toplevel)
              nix-diff "$@" "$current" "$target"
            '';
          };

          update = pkgs.writers.writePython3Bin "update" { } ./scripts/update.py;

          start-vm = pkgs.writeShellApplication {
            name = "start-vm";
            runtimeInputs = [ pkgs.vault-bin ];
            text =
              let vaultUrl = self.nixosConfigurations.wpia-packit.config.vault.url;
              in ''
                token=$(vault print token)
                if [[ -z $token ]]; then
                  echo "Logging in to ${vaultUrl}"
                  token=$(env VAULT_ADDR="${vaultUrl}" vault login -method=github -field=token)
                fi

                exec ${nixpkgs.lib.getExe self.nixosConfigurations.wpia-packit.config.system.build.vm} \
                  -fw_cfg name=opt/vault-token,string="$token" "$@"
              '';
          };

          vm-test = self.checks.x86_64-linux.default.driver;
        };

      checks.x86_64-linux.default =
        let pkgs = import nixpkgs ({ system = "x86_64-linux"; } // pkgsArgs);
        in pkgs.callPackage ./tests { inherit inputs; };

      devShells.x86_64-linux.default =
        let pkgs = import nixpkgs ({ system = "x86_64-linux"; } // pkgsArgs);
        in pkgs.mkShell {
          buildInputs = [
            pkgs.nix-prefetch-github
            pkgs.nixos-rebuild
          ];
        };
    };
}
