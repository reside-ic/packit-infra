# Building with Gradle is a little tricky.
#
# As is usual with other build systems, we want to separate the dependency
# download phase from the build phase. The download phase is a fixed-output
# derivation, meaning its output hash is hardcoded, and it runs with network
# access. The build phase runs in the sandbox without network access and does
# not need a known output hash.
#
# Unfortunately Gradle doesn't have an easy way of just fetching the
# dependencies without performing a full build. Therefore that's what we do: we
# build the package once, throw away the result but keep the dependency cache.
# The package is built a second time, using the same dependency cache.
{ fetchFromGitHub, stdenv, gradle, jre_headless, lib, perl, runtimeShell, writeText, makeWrapper }:
let
  sources = lib.importJSON ./sources.json;

  makePackage = args@{ nativeBuildInputs ? [ ], ... }: stdenv.mkDerivation (finalAttrs: {
    src = fetchFromGitHub sources.src;
    sourceRoot = "${finalAttrs.src.name}/api";

    nativeBuildInputs = [ gradle ] ++ nativeBuildInputs;
    buildPhase = ''
      runHook preBuild

      export GRADLE_USER_HOME=$(mktemp -d)
      gradle --no-daemon --console=plain --info $gradleFlags :app:bootJar

      runHook postBuild
    '';
  } // (builtins.removeAttrs args [ "nativeBuildInputs" ]));

  deps = makePackage {
    name = "packit-api-deps";
    nativeBuildInputs = [ perl ];
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\|module\)' \
         | LC_ALL=C sort \
         | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
         | sh
      rm -rf $out/tmp
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = sources.gradleDepsHash;
  };

  gradleInit = writeText "init.gradle" ''
    logger.lifecycle 'Replacing Maven repositories with ${deps}...'
    gradle.projectsLoaded {
      rootProject.allprojects {
        buildscript {
          repositories {
            maven { url '${deps}' }
          }
        }
        repositories {
          maven { url '${deps}' }
        }
      }
    }
    settingsEvaluated { settings ->
      settings.pluginManagement {
        repositories {
          maven { url '${deps}' }
        }
      }
    }
  '';
in
makePackage {
  name = "packit-api";
  gradleFlags = "--offline --init-script ${gradleInit}";
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin $out/share
    install -m644 app/build/libs/app.jar $out/share/packit-api.jar

    makeWrapper ${jre_headless}/bin/java $out/bin/packit-api \
      --add-flags "-jar $out/share/packit-api.jar"
  '';

  passthru.gradleDeps = deps;
}
