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
        ];
      };
    in
    {
      overlays.default = (final: prev: {
        packit = final.callPackage ./packages/packit { };
        outpack_server = final.callPackage ./packages/outpack_server { };
        packit-app = final.callPackage ./packages/packit/packit-app.nix { };
        packit-api = final.callPackage ./packages/packit/packit-api.nix { };
      });

      nixosConfigurations.wpia-packit = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          { nixpkgs = pkgsArgs; }
        ];
      };

      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix
          ./tests/setup.nix
          { nixpkgs = pkgsArgs; }
        ];
      };

      packages.x86_64-linux =
        let pkgs = import nixpkgs ({ system = "x86_64-linux"; } // pkgsArgs);
        in {
          inherit (pkgs) outpack_server packit-app packit-api packit;

          default = self.nixosConfigurations."wpia-packit".config.system.build.toplevel;

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
          start-vm = self.nixosConfigurations."vm".config.system.build.vm;
        };

      checks.x86_64-linux.boots =
        let pkgs = import nixpkgs ({ system = "x86_64-linux"; } // pkgsArgs);
        in pkgs.callPackage ./tests/boot.nix { inherit inputs; };

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
