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

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./authorized_keys
  ];

  system.stateVersion = "24.05";
}
