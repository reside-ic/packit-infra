{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, nixpkgs-unstable, disko, self, ... }: {
    nixosConfigurations.wpia-packit = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        ./modules/outpack.nix
        ./modules/packit.nix

        {
          nixpkgs.overlays = [
            (final: prev: {
              inherit (self.packages.x86_64-linux)
                outpack_server packit-app packit-api;
            })
          ];
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
  };
}
