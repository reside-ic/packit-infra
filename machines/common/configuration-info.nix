# NixOS allows us to configure our machines declaratively and track the
# configuration in a GitHub repository. In theory, one can have a good
# understanding of the state of a machine by looking at the configuration files
# in the source repository.
#
# Unfortunately it is easy for a machine to become out of sync with the
# upstream repository and to "drift" away. There are two main reasons this can
# happen:
# - A change is made to the main branch of the repository, but that change
#   doesn't get deployed to all the machines it affects.
# - An experimental change is made on a local branch of the repository and is
#   deployed to one or more machines, but that change is never merged into main
#   (or it is merged in a different form).
#
# Either situation is harmless in the short term, but in the long term it is
# easy to forget to reconcile the state of the machines with the state of the
# repository, and find ourselves months later with machines that do not match
# their declarative configuration.
#
# This file attempts to detect and address this issue using Prometheus metrics
# and alerts. We configure each machine to expose as a metric the hash of its
# configuration. This metric is periodically scraped by Prometheus and stored
# in the TSDB. In parallel, we build the latest commit from the main branch on
# GitHub, compute its hash and store the result on GitHub pages. Prometheus is
# configured to scrape GitHub pages and scrape those hashes too. If the hash of
# a configuration deployed to a machine diverges from the hash produced by the
# upstream build, an alert is fired.
#
# There are two caveats to the way we implement this:
# - The configuration cannot include as one of its inputs the hash of its
#   output. That would be equivalent to solving the fixpoint of a cryptographic
#   hash, which is impossible.
# - We are interested in recording the Git revision that produced a system's
#   configuration, but at the same time we don't want to have to re-deploy a
#   machine if the Git revision has changed but the configuration has not (eg.
#   a documentation change, or a change that only affects a subset of machines).
#
# To work around both of the caveats, the system hash we measure is actually of
# an ever-so-slightly modified configuration, one where the metric for the
# configuration is not exposed. This hash does not depend on itself, nor does it
# depend on the exact Git revision of the input.

{ pkgs, inputs, extendModules, config, ... }:
let
  # Export the NAR hash of a derivation, writing it to a file.
  #
  # By setting `__structuredAttrs`, Nix provides a `NIX_ATTRS_JSON_FILE`
  # environment variable pointing to a JSON with lots of metadata about the
  # build context. Using `exportReferencesGraph`, that file includes
  # information about the given path, including its NAR hash.
  writeNarHash = p: pkgs.runCommand "${p.name}-narHash"
    {
      __structuredAttrs = true;
      exportReferencesGraph.closure = [ p ];
      nativeBuildInputs = [ pkgs.jq ];
    } ''
    jq -r --arg path "${p}" '.closure[] | select(.path == $path).narHash' < $NIX_ATTRS_JSON_FILE > $out
  '';

  # This is the modified system configuration whose hash is used. It is
  # identical to the actual system configuration, but the metric including the
  # system hash is removed to avoid the cyclic definition.
  withoutConfigurationInfo = extendModules {
    modules = [{
      environment.etc."metrics/configuration-info.prom".enable = false;
    }];
  };
  systemHash = writeNarHash withoutConfigurationInfo.config.system.build.toplevel;

  rev = inputs.self.rev or inputs.self.dirtyRev or "unknown";

  hostname = config.networking.hostName;
  sourceInfoMetrics = pkgs.runCommand "${hostname}-source-info.prom" { } ''
    cat >$out <<EOF
    nixos_source_info{hostname="${hostname}", revision="${rev}", narHash="$(cat ${systemHash})"} 1
    EOF
  '';

  configurationInfoMetrics = pkgs.runCommand "${hostname}-configuration-info.prom" { } ''
    cat > $out <<EOF
    nixos_configuration_info{hostname="${hostname}", revision="${rev}", narHash="$(cat ${systemHash})"} 1
    EOF
  '';
in
{
  system.build.withoutConfigurationInfo = withoutConfigurationInfo;
  system.build.sourceInfoMetrics = sourceInfoMetrics;
  environment.etc."metrics/configuration-info.prom".source = configurationInfoMetrics;
}
