{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, nixpkgs-unstable, disko, self, ... }: {
    overlays.default = (final: prev: {
      outpack_server = final.callPackage ./packages/outpack_server { };
      packit-app = final.callPackage ./packages/packit/packit-app.nix { };
      packit-api = final.callPackage ./packages/packit/packit-api.nix { };
    });

    nixosConfigurations.wpia-packit = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        ./disk-config.nix
        ./hardware-configuration.nix

        { nixpkgs.overlays = [ self.overlays.default ]; }
      ];
    };

    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./tests/setup.nix
        {
          services.getty.autologinUser = "root";
          nixpkgs.overlays = [ self.overlays.default ];
        }
      ];
    };

    packages.x86_64-linux =
      let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        pkgs-unstable = import nixpkgs-unstable { system = "x86_64-linux"; };
      in
      {
        outpack_server = pkgs.callPackage ./packages/outpack_server { };
        packit-app = pkgs.callPackage ./packages/packit/packit-app.nix { };
        packit-api = pkgs-unstable.callPackage ./packages/packit/packit-api.nix { };
      };

    checks.x86_64-linux.boots =
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ self.overlays.default ];
        };
      in
      pkgs.callPackage ./tests/boot.nix { };
  };
}
