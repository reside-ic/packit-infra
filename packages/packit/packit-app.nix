{ fetchFromGitHub
, buildNpmPackage
, lib
, nodejs_22
}:
let
  sources = lib.importJSON ./sources.json;
in
buildNpmPackage rec {
  name = "packit-app";
  src = fetchFromGitHub sources.src;
  npmDepsHash = sources.npmDepsHash;
  sourceRoot = "${src.name}/app";

  nodejs = nodejs_22;

  installPhase = ''
    runHook preInstall
    cp -r build $out
    runHook postInstall
  '';
}
