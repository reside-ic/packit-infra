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
{ fetchFromGitHub, stdenv, gradle, jre_headless, lib, perl, runtimeShell, writeTextDir, writeText, makeWrapper }:
let
  sources = lib.importJSON ./sources.json;
  gitProperties = writeTextDir "git.properties" ''
    git.commit.id = ${sources.src.rev}
  '';

  replaceGitProperties = writeText "skip-git-properties.gradle" ''
    gradle.projectsEvaluated {
      def project = getRootProject().findProject(":app")
      project.gitProperties.failOnNoGitDirectory = false
      project.sourceSets.main.resources.srcDir "${gitProperties}"
    }
  '';

  makePackage =
    { nativeBuildInputs ? [ ]
    , gradleFlags ? [ ]
    , ...
    }@args: stdenv.mkDerivation (finalAttrs: {
      src = fetchFromGitHub sources.src;
      sourceRoot = "${finalAttrs.src.name}/api";

      nativeBuildInputs = [ gradle ] ++ nativeBuildInputs;

      # The default gradle configure forces --offline, which we don't want for
      # our deps fetching phase. We do our own configure instead.
      dontUseGradleConfigure = true;

      gradleFlags = gradleFlags ++ [
        "--no-daemon"
        "--console=plain"
        "--init-script=${replaceGitProperties}"
      ];
      gradleBuildTask = ":app:bootJar";

      configurePhase = ''
        runHook preCofigure
        export GRADLE_USER_HOME=$(mktemp -d)
        runHook postConfigure
      '';
    } // (builtins.removeAttrs args [ "nativeBuildInputs" "gradleFlags" ]));

  deps = makePackage {
    name = "packit-api-deps";
    nativeBuildInputs = [ perl ];

    # This slight insanity searches the gradle cache and transforms it into a
    # file layout that looks like a Maven repository. The repository we create
    # can then be used as an input to the real build.
    #
    # We need the sort to keep things deterministic: the cache may contain the
    # same file name twice with different hashes, as long as we pick a winner
    # deterministically things are generally okay.
    #
    # The perl command transforms the paths, turning the following
    # /path/to/cache/org.springframework/spring-beans/6.0.4/30ee07d3fcc6bbf13ab4ddca2dff9ebad55dee51/spring-beans-6.0.4.pom
    # into
    # $out/org/springframework/spring-beans/6.0.4/spring-beans-6.0.4.pom
    #
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
  gradleFlags = [ "--offline" "--init-script=${gradleInit}" ];
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin $out/share
    install -m644 app/build/libs/app.jar $out/share/packit-api.jar

    makeWrapper ${jre_headless}/bin/java $out/bin/packit-api \
      --add-flags "-jar $out/share/packit-api.jar"
  '';

  passthru.gradleDeps = deps;
}
