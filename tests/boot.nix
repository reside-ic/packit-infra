{ pkgs, inputs }:
pkgs.testers.runNixOSTest {
  name = "boot";
  node.specialArgs = {
    inherit inputs;
  };
  nodes.machine = { config, ... }: {
    imports = [
      ../configuration.nix
      ./setup.nix
    ];
  };

  testScript = ''
    import json

    machine.wait_for_unit("multi-user.target")
    response = machine.wait_until_succeeds(
      "curl -s --fail --location --insecure https://localhost/priority-pathogens/packit/api/auth/config"
    )
    data = json.loads(response)
    assert data["enableGithubLogin"] == True
  '';
}
