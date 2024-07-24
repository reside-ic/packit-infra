{ pkgs }:
pkgs.nixosTest {
  name = "boot";
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
      "curl -s --fail --location --insecure https://packit.dide.ic.ac.uk/priority-pathogens/packit/api/auth/config"
    )
    data = json.loads(response)
    assert data["enableGithubLogin"] == True
  '';
}
