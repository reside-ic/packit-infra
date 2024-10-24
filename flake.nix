{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, lib, self, nixpkgs, ... }: {
    imports = [
      ./packages
      ./machines
      ./scripts
      ./tests
    ];
    perSystem = { system, pkgs, ... }: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
          "vault"
          "vault-bin"
        ];
      };

      devShells.default = pkgs.mkShell {
        buildInputs = [
          pkgs.nix-prefetch-github
          pkgs.nixos-rebuild
          pkgs.nix-diff
        ];
      };
    };

    systems = [ "x86_64-linux" ];
  });
}
