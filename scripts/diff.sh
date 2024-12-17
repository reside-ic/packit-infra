#!/usr/bin/env bash
#
# This script runs nix-diff between the configuration declared in the local repo
# and the one that is currently running on the machine. It does so by resolving
# the derivation of /run/current-system on the machine and downloads it locally.
# 
# This only works if we always deploy derivations to the running system along
# with the system configuration. The `deploy.sh` script is designed to always do
# this. We also set `nix.settings.keep-derivations` to true on our machines to
# stop the derivations from being garbage-collected.
set -eu

if [[ $# -lt 1 ]]; then
  hostnames=$(nix eval --quiet --raw ".#nixosConfigurations" --apply 'x: builtins.concatStringsSep ", " (builtins.attrNames x)')
  cat >&2 <<EOF
Usage: $0 hostname
Valid hostnames: $hostnames

Additional arguments are passed to nix-diff
EOF
  exit 1
fi

host="$1"
data=$(nix eval ".#nixosConfigurations.$host" --json --apply 'm: { fqdn = m.config.networking.fqdn; drv = m.config.system.build.toplevel.drvPath; }')
fqdn=$(echo "$data" | jq -r .fqdn)
target=$(echo "$data" | jq -r .drv)

current=$(ssh "root@$fqdn" nix path-info --derivation /run/current-system)
nix-copy-closure --from "root@$fqdn" "$current"

exec nix-diff "${@:2}" "$current" "$target"
