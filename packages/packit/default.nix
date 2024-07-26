{ fetchFromGitHub
, buildNpmPackage
, lib
, PUBLIC_URL ? null
, PACKIT_NAMESPACE ? null
}:
buildNpmPackage rec {
  name = "packit-app";
  src = fetchFromGitHub (lib.importJSON ./sources.json);
  npmDepsHash = "sha256-LiqPRDW/CulR6GN84v1VrbN4q4Qw0zcbJ+rzAk0cSOc=";
  sourceRoot = "${src.name}/app";

  # For some reason Packit is missing integrity and resolved fields
  postPatch = ''
    cp ${./package-lock.json} ./package-lock.json
  '';

  installPhase = ''
    runHook preInstall
    cp -r build $out
    runHook postInstall
  '';

  inherit PUBLIC_URL;
  REACT_APP_PACKIT_NAMESPACE = PACKIT_NAMESPACE;
}
