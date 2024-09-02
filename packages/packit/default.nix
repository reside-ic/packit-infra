{ packit-app, packit-api, stdenv, fetchFromGitHub, lib }:
stdenv.mkDerivation {
  name = "packit";
  src = fetchFromGitHub (lib.importJSON ./sources.json).src;
  buildPhase = ''
    echo >&2 "This is not a real package, it only exists to support the update script. You probably want packit-app or packit-api instead."
    exit 1
  '';
  passthru = {
    inherit (packit-app) npmDeps;
    inherit (packit-api) gradleDeps;
  };
}
