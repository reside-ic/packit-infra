{ fetchFromGitHub, buildNpmPackage, lib, PUBLIC_URL ? null }:
buildNpmPackage rec {
  name = "packit-static";
  src = fetchFromGitHub (lib.importJSON ./packit.json);
  npmDepsHash = "sha256-LiqPRDW/CulR6GN84v1VrbN4q4Qw0zcbJ+rzAk0cSOc=";
  sourceRoot = "${src.name}/app";

  # For some reason Packit is missing integrity and resolved fields
  postPatch = ''
    cp ${./packit-package-lock.json} ./package-lock.json
  '';

  installPhase = ''
    runHook preInstall
    cp -r build $out
    runHook postInstall
  '';

  inherit PUBLIC_URL;
}
