{ lib, pkgs, inputs, ... }: {
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
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  environment.systemPackages = [
    pkgs.curl
    pkgs.vim
    pkgs.outpack_server

    (pkgs.writeShellApplication {
      name = "fetch-secrets";
      runtimeInputs = [ pkgs.vault ];
      text = builtins.readFile ./scripts/fetch-secrets.sh;
    })
  ];

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./authorized_keys
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vault"
  ];

  system.stateVersion = "24.05";
}
