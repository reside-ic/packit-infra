{
  perSystem = { pkgs, system, self', ... }: {
    packages = {
      outpack_server = pkgs.callPackage ./outpack_server { };
      packit-app = pkgs.callPackage ./packit/packit-app.nix { };
      packit-api = pkgs.callPackage ./packit/packit-api.nix { };
      packit = pkgs.callPackage ./packit {
        inherit (self'.packages) packit-app packit-api;
      };
    };
  };
}
