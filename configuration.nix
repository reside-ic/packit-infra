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

  users.users.vscan-dide = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDG/MCRfHKu4trSoii5eeozpZlOQJ5t8YwowTBy5q5rDCUr/pcZNFmfzEfeTerOV2ON8CiAfx/LADCJFRNRvSiMawGqF6U3Xstk/JTh6IXbowukhdKqpqom/BF2Oryy6iDFlnUTX3wJJGdsV/9DnSBzudngsmSMOFs8aFbVKrQ3V6mI7itq2+Qfg4a428uU1912TG2n9SnEYTnufYtPIivz+Kx/3YP5o5u2YW9FgZJlp502ce4harols28wsmVd2jZ9yrlRGlQSyuRnSf45PKiVdv4CEhCb7ppSrE7u0lGnhT2uENm+jpHoJ4/CSxtrUgQFDCqJarQuipojhPurRqEXT+NX6wjgqOXof2ouBrVKvJ3NoSCuMAltPxDazC+UELy0y67uiAq5APnwzny7w+VxkbBz3b1tetI9igZ13AjhVu0R4SeSHjb/TZkYdx+kUHEzLzv1NgzeGCVY7NKjTOFnqqneIQIeOwW/0bxQ9FoPsz/u3D3OYwyjnhNG9GUySHk= ic/elton@icsecwop2" ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.05";
}
