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

  virtualisation.vmVariant.virtualisation.forwardPorts = [{
    from = "host";
    host.port = 8443;
    guest.port = 443;
  }];

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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.05";
}
