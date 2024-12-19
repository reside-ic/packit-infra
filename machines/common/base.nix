# This file defines the basic configuration for a functional NixOS machine.
# It won't enable any of packit/outpack/metrics, see `services.nix` for that.
{ self, config, lib, pkgs, self', inputs, ... }: {
  imports = [
    ../../modules/multi-packit.nix
    ../../modules/vault.nix
    ../../modules/outpack.nix
    ../../modules/packit-api.nix
    ../../modules/metrics-proxy.nix
    ./tools.nix
    inputs.disko.nixosModules.disko
    inputs.comin.nixosModules.comin
  ];

  virtualisation.vmVariant = {
    imports = [ ../../vm.nix ];
  };

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 9000 ];
  networking.domain = "dide.ic.ac.uk";

  environment.systemPackages = [
    pkgs.curl
    pkgs.htop
    pkgs.vim
    self'.packages.outpack_server
    pkgs.gitMinimal
  ];

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../authorized_keys
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Keep derivations when garbage collecting the Nix store. We use these
  # derivations to run `nix-diff` against a running system.
  nix.settings.keep-derivations = true;

  system.stateVersion = "24.05";
}
