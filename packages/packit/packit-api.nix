{ stdenv, lib, fetchFromGitHub, gradle, jre, makeWrapper }:
let
  self = stdenv.mkDerivation rec {
    name = "packit-api";
    nativeBuildInputs = [ gradle makeWrapper ];

    src = fetchFromGitHub (lib.importJSON ./sources.json);
    sourceRoot = "${src.name}/api";

    mitmCache = gradle.fetchDeps {
      pkg = self;
      data = ./gradle-deps.json;

      # bwrap doesn't work on Ubuntu kernels
      useBwrap = false;
    };

    gradleBuildTask = ":app:bootJar";

    installPhase = ''
      mkdir -p $out/{bin,share/packit}
      cp app/build/libs/app.jar $out/share/packit/app.jar
      makeWrapper ${jre}/bin/java $out/bin/packit-api \
        --add-flags "-jar $out/share/packit/app.jar"
    '';
  };
in
self
