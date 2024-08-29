{ fetchFromGitHub
, buildNpmPackage
, lib
, PUBLIC_URL ? null
, PACKIT_NAMESPACE ? null
}:
let
  sources = lib.importJSON ./sources.json;
in
buildNpmPackage rec {
  name = "packit-app";
  src = fetchFromGitHub sources.src;
  npmDepsHash = sources.npmDepsHash;
  sourceRoot = "${src.name}/app";

  installPhase = ''
    runHook preInstall
    cp -r build $out
    runHook postInstall
  '';

  inherit PUBLIC_URL;
  REACT_APP_PACKIT_NAMESPACE = PACKIT_NAMESPACE;
}
