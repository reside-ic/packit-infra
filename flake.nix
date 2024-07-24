{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, self, ... } @inputs: {
    overlays.default = (final: prev: {
      outpack_server = final.callPackage ./packages/outpack_server { };
      packit-app = final.callPackage ./packages/packit { };
    });

    nixosConfigurations.wpia-packit = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        { nixpkgs.overlays = [ self.overlays.default ]; }
      ];
    };

    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./tests/setup.nix
        { nixpkgs.overlays = [ self.overlays.default ]; }
      ];
    };

    packages.x86_64-linux =
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ self.overlays.default ];
        };
      in
      {
        inherit (pkgs) outpack_server packit-app;
        update-ssh-keys = pkgs.writeShellApplication {
          name = "update-ssh-keys";
          runtimeInputs = [ pkgs.curl ];
          text = builtins.readFile ./scripts/update-ssh-keys.sh;
        };
      };

    checks.x86_64-linux.boots =
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ self.overlays.default ];
        };
      in
      pkgs.callPackage ./tests/boot.nix { inherit inputs; };
  };
}
