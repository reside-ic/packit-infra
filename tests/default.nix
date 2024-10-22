{ pkgs, inputs }:
pkgs.testers.runNixOSTest {
  name = "boot";
  node.specialArgs = {
    inherit inputs;
  };
  nodes.machine = { lib, config, ... }: {
    imports = [
      ../machines/common/configuration.nix
      ../machines/common/services.nix

      # The `virtualisation.vmVariant` setting we use to import VM-specific
      # settings doesn't work for the test VMs, so re-import the vm module here.
      # https://github.com/NixOS/nixpkgs/pull/339511#issuecomment-2328611982
      ../vm.nix
    ];

    services.multi-packit = {
      enable = true;
      sslCertificate = "/var/secrets/packit.cert";
      sslCertificateKey = "/var/secrets/packit.key";
      githubOAuthSecret = "/var/secrets/github-oauth";
      instances = [ "reside" ];
    };

    services.packit-api.instances.reside = {
      authentication = {
        method = "basic";
        service.policies = [{
          jwkSetUri = "http://127.0.0.1:81/jwks.json";
          issuer = "https://token.actions.githubusercontent.com";
          grantedPermissions = [ "outpack.read" "outpack.write" ];
        }];
      };
    };

    # This sets up an additional HTTP service on port 81 to serve JWK keys.
    # The server supports GET and PUT, allowing the test script to upload its own keys
    systemd.tmpfiles.rules = [ "d /var/www 755 nginx nginx" ];
    systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/var/www" ];
    services.nginx.virtualHosts.jwk = {
      serverName = "localhost";
      listen = [{ addr = "0.0.0.0"; port = 81; ssl = false; }];
      root = "/var/www";
      extraConfig = ''
        dav_methods PUT;
      '';
    };

    # It's suprisingly easy to run qemu without hardware acceleration and not
    # notice it, which makes the VM so slow the tests tend to fail. This forces
    # KVM acceleration and will fail to start if missing.
    virtualisation.qemu.options = [ "-machine" "accel=kvm" ];
  };

  extraPythonPackages = ps: [ ps.jwcrypto ];
  testScript = builtins.readFile ./script.py;
}
