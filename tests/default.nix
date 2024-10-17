{ self, inputs, ... }: {
  perSystem = { self', pkgs, ... }: {
    checks.integration-test = pkgs.callPackage ./integration {
      specialArgs = { inherit self self' inputs; };
    };

    # Nix doesn't have any easy way to run just one check, so we re-expose it
    # as an "app" instead. It also works around the issue that checks often run
    # in a sandbox as the nixbld user, which may not have access to kvm
    # acceleration.
    apps.integration-test.program = self'.checks.integration-test.driver;
  };
}
