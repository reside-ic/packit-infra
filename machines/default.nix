{ withSystem, inputs, self, ... }:
let inherit (inputs.nixpkgs.lib) nixosSystem; in
{
  flake.nixosConfigurations = {
    wpia-packit = withSystem "x86_64-linux" ({ pkgs, system, self', ... }: nixosSystem {
      specialArgs = { inherit inputs self'; };
      modules = [
        ./wpia-packit.nix
        ./common/hardware-configuration.nix
        ./common/disk-config.nix
      ];
      inherit system pkgs;
    });

    wpia-packit-private = withSystem "x86_64-linux" ({ pkgs, system, self', ... }: nixosSystem {
      specialArgs = { inherit inputs self'; };
      modules = [
        ./wpia-packit-private.nix
        ./common/hardware-configuration.nix
        ./common/disk-config.nix
      ];
      inherit system pkgs;
    });
  };
}
