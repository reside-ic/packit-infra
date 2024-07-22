{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, disko, self, ... }: {
    nixosConfigurations.wpia-packit = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        ./modules/outpack.nix
        {
          nixpkgs.overlays = [
            (final: prev: {
              inherit (self.packages.x86_64-linux) outpack_server;
            })
          ];
        }
      ];
    };

    packages.x86_64-linux =
      let pkgs = import nixpkgs { system = "x86_64-linux"; };
      in {
        outpack_server = pkgs.callPackage ./packages/outpack_server.nix { };
      };
  };
}
