{ fetchFromGitHub
, buildNpmPackage
, lib
, PUBLIC_URL ? null
, PACKIT_NAMESPACE ? null
}:
buildNpmPackage rec {
  name = "packit-app";
  src = fetchFromGitHub (lib.importJSON ./sources.json);
  npmDepsHash = "sha256-o//+q3trkCnKpSAWEHPZOeiMYxzKOvrGDgEv63BsnxI=";
  sourceRoot = "${src.name}/app";

  installPhase = ''
    runHook preInstall
    cp -r build $out
    runHook postInstall
  '';

  inherit PUBLIC_URL;
  REACT_APP_PACKIT_NAMESPACE = PACKIT_NAMESPACE;
}
