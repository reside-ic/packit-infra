{ pkgs, inputs }:
pkgs.testers.runNixOSTest {
  name = "boot";
  node.specialArgs = {
    inherit inputs;
  };
  nodes.machine = { lib, config, ... }: {
    imports = [
      ../configuration.nix

      # The `virtualisation.vmVariant` setting we to import VM-specific settings
      # doesn't for the test VMs.
      # https://github.com/NixOS/nixpkgs/pull/339511#issuecomment-2328611982
      ../vm.nix
    ];

    services.packit-api.instances =
      let
        f = name: lib.nameValuePair name {
          authentication.method = lib.mkForce "basic";
        };
      in
      lib.listToAttrs (map f config.services.multi-packit.instances);

    # It's suprisingly easy to run qemu without hardware acceleration and not
    # notice it, which makes the VM so slow the tests tend to fail. This forces
    # KVM acceleration and will fail to start if missing.
    virtualisation.qemu.options = [ "-machine" "accel=kvm" ];
  };

  testScript = builtins.readFile ./script.py;
}
