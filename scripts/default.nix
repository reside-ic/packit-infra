{ self, ... }:
{
  perSystem = { pkgs, lib, ... }:
    let
      # These capture the derivation (but not the output) of each machine's
      # configuration. The scripts that use these (eg. deploy/diff/start-vm)
      # are responsible for turning the drv into the final product when it is
      # needed.
      #
      # nix has a weird quirk that makes `drvPath` depend on all the input
      # sources recursively, even those not needed to build thanks to binary
      # caches. While scary sounding, `unsafeDiscardOutputDependency` works
      # well in this case to avoid that particular issue. There does seem to be
      # a plan to fix this eventually: https://github.com/NixOS/nix/issues/7910
      nixosDerivations = lib.mapAttrs
        (_: v: {
          fqdn = v.config.networking.fqdn;
          drvPath = builtins.unsafeDiscardOutputDependency v.config.system.build.toplevel.drvPath;
        })
        self.nixosConfigurations;

      vmDerivations = lib.mapAttrs
        (_: v: {
          vaultUrl = v.config.vault.url;
          drvPath = builtins.unsafeDiscardOutputDependency v.config.system.build.vm.drvPath;
          mainProgram = v.config.system.build.vm.meta.mainProgram;
        })
        self.nixosConfigurations;

      NIXOS_CONFIGURATIONS = pkgs.writers.writeJSON "hosts.json" nixosDerivations;
      VM_CONFIGURATIONS = pkgs.writers.writeJSON "hosts.json" vmDerivations;
    in
    {
      packages = {
        fetch-secrets = pkgs.writers.writePython3Bin "fetch-secrets"
          {
            libraries = [ pkgs.python3.pkgs.hvac ];
          } ./fetch-secrets.py;
      };

      apps = {
        update.program = pkgs.writers.writePython3Bin "update" { } ./update.py;
        update-image.program = pkgs.writers.writePython3Bin "update-image"
          {
            makeWrapperArgs = [ "--prefix PATH : ${lib.makeBinPath [ pkgs.nix-prefetch-docker ]}" ];
          } ./update-image.py;

        update-ssh-keys.program = pkgs.writeShellApplication {
          name = "update-ssh-keys";
          runtimeInputs = [ pkgs.curl ];
          text = builtins.readFile ./update-ssh-keys.sh;
        };

        deploy.program = pkgs.writeShellApplication {
          name = "deploy";
          text = builtins.readFile ./deploy.sh;
          runtimeInputs = [ pkgs.jq pkgs.nix pkgs.openssh ];
          runtimeEnv = { inherit NIXOS_CONFIGURATIONS; };
        };

        diff.program = pkgs.writeShellApplication {
          name = "diff";
          text = builtins.readFile ./diff.sh;
          runtimeInputs = [ pkgs.jq pkgs.nix pkgs.nix-diff pkgs.openssh ];
          runtimeEnv = { inherit NIXOS_CONFIGURATIONS; };
        };

        start-vm.program = pkgs.writeShellApplication {
          name = "start-vm";
          text = builtins.readFile ./start-vm.sh;
          runtimeInputs = [ pkgs.jq pkgs.nix pkgs.vault-bin ];
          runtimeEnv = { inherit VM_CONFIGURATIONS; };
        };
      };
    };
}
