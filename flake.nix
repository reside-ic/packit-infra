{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
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

      # This gets published to GitHub pages for Prometheus to scrape.
      packages.repository-metrics = pkgs.concatTextFile {
        name = "repository-metrics";
        files = lib.mapAttrsToList (_: c: c.config.system.build.sourceInfoMetrics or null) self.nixosConfigurations;
        destination = "/metrics";
      };
    };

    systems = [ "x86_64-linux" ];
  });
}
