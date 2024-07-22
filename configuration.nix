{ modulesPath, config, lib, pkgs, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./hardware-configuration.nix
  ];

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.openssh.enable = true;
  networking.hostName = "wpia-packit";
  networking.firewall.enable = false;

  environment.systemPackages = [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.vim
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExujNUD1itJ1VfxZexhJAYYNXatDgQJdCQL+qidb5fF pl2113@WPIA-DIDELT455"
  ];

  system.stateVersion = "24.05";
}
