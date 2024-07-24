{ pkgs, inputs, ... }: {
  imports = [
    ./disk-config.nix
    ./modules/multi-packit.nix
    ./modules/outpack.nix
    ./modules/packit-api.nix
    ./services.nix

    inputs.disko.nixosModules.disko
  ];

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  networking.hostName = "wpia-packit";
  networking.firewall.enable = false;

  environment.systemPackages = [
    pkgs.curl
    pkgs.vim
    pkgs.outpack_server
  ];

  # TODO: fetch these from GitHub
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExujNUD1itJ1VfxZexhJAYYNXatDgQJdCQL+qidb5fF pl2113@WPIA-DIDELT455"
  ];

  system.stateVersion = "24.05";
}
