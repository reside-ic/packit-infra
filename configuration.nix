{ lib, pkgs, inputs, ... }: {
  imports = [
    ./disk-config.nix
    ./services.nix
    ./modules/multi-packit.nix
    ./modules/outpack.nix
    ./modules/packit-api.nix
    ./modules/metrics-proxy.nix

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
  networking.firewall.allowedTCPPorts = [ 22 80 443 9000 ];

  environment.systemPackages = [
    pkgs.curl
    pkgs.htop
    pkgs.vim
    pkgs.outpack_server
    pkgs.gitMinimal

    (pkgs.writeShellApplication {
      name = "fetch-secrets";
      runtimeInputs = [ pkgs.vault ];
      text = builtins.readFile ./scripts/fetch-secrets.sh;
    })

    (pkgs.writeShellApplication {
      name = "grant-role";
      runtimeInputs = [ pkgs.postgresql ];
      text = builtins.readFile ./scripts/grant-role.sh;
    })

    (pkgs.writeShellApplication {
      name = "create-basic-user";
      runtimeInputs = [
        pkgs.postgresql
        pkgs.apacheHttpd
      ];
      text = builtins.readFile ./scripts/create-basic-user.sh;
    })
  ];

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ./authorized_keys
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.05";
}
