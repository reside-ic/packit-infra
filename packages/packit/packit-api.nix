{ fetchFromGitHub, stdenv, gradle, jre_headless, lib, perl, runtimeShell, writeText }:
let
  gradleDepsHash = "sha256-HTpu1hMNol+Shi2P1GdBnO1oLlqqEWTezdmy4I9ijKY=";

  makePackage = args@{ nativeBuildInputs ? [ ], ... }: stdenv.mkDerivation (finalAttrs: {
    src = fetchFromGitHub (lib.importJSON ./sources.json);
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
         | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
         | sh
      rm -rf $out/tmp
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = gradleDepsHash;
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
  installPhase = ''
    mkdir -p $out/bin $out/share/packit-api
    install -m644 app/build/libs/app.jar $out/share/packit-api/packit-api.jar

    cat > $out/bin/packit-api <<EOF
    #!${runtimeShell}
    export JAVA_HOME=${jre_headless}
    exec ${jre_headless}/bin/java -jar $out/share/packit-api/packit-api.jar "\$@"
    EOF
    chmod +x $out/bin/packit-api
  '';

  passthru.deps = deps;
}
