{ self, ... }:
{
  perSystem = { pkgs, lib, ... }: {
    packages = {
      fetch-secrets = pkgs.writers.writePython3Bin "fetch-secrets"
        {
          libraries = [ pkgs.python3.pkgs.hvac ];
        } ./fetch-secrets.py;
    };

    apps = {
      update.program = pkgs.writers.writePython3Bin "update" { } ./update.py;

      update-ssh-keys.program = pkgs.writeShellApplication {
        name = "update-ssh-keys";
        runtimeInputs = [ pkgs.curl ];
        text = builtins.readFile ./update-ssh-keys.sh;
      };

      deploy.program = pkgs.writeShellApplication {
        name = "deploy";
        runtimeInputs = [ pkgs.nix pkgs.openssh ];
        text = builtins.readFile ./deploy.sh;
      };

      start-vm.program = pkgs.writeShellApplication {
        name = "start-vm";
        runtimeInputs = [ pkgs.vault-bin ];
        text = builtins.readFile ./start-vm.sh;
      };

      diff.program = pkgs.writeShellApplication {
        name = "diff";
        runtimeInputs = [ pkgs.nix pkgs.openssh pkgs.nix-diff ];
        text = builtins.readFile ./diff.sh;
      };
    };
  };
}
