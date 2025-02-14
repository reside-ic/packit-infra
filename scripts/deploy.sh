#!/usr/bin/env bash
#
# This a rough equivalent of the standard nixos-rebuild command.
#
# The main difference is that in addition to pushing the built system, it also
# pushes its derivation. Having the derivation allows us to subsequently
# inspect the build and perform diffs against it.
#
# This script also has some other niceties, like figuring out the FQDN
# directly from the evaluted NixOS configuration.
set -eu

if [[ $# != 1 && $# != 2 ]]; then
  hostnames=$(jq -r 'keys.[] | join(",")' $NIXOS_CONFIGURATIONS)
  cat >&2 <<EOF
Usage: $0 hostname [switch|boot|test|dry-activate]
Valid hostnames: $hostnames

The second argument chooses the action to take:
- switch: Activate the configuration now and make it the default for future reboots.
- boot: Make the configuration the default for future reboots, but don't activate it.
- test: Activate the configuration now, but do not change the default boot option.
- dry-activate: Show what services would be affected if this configuration were to be activated, but don't perform any of it.

If no action is specified, the default is "switch".
EOF
  exit 1
fi

host="$1"
action="${2-switch}"

fqdn=$(jq --arg host "$host" -r '.[$host].fqdn' $NIXOS_CONFIGURATIONS)
drv=$(jq --arg host "$host" -r '.[$host].drvPath' $NIXOS_CONFIGURATIONS)

printf "Building system configuration for %s...\n" "$fqdn"
target=$(nix-store --realise "$drv")

printf "Copying system configuration to %s...\n" "$fqdn"

nix-copy-closure --use-substitutes --to "root@$fqdn" "$drv" "$target"

printf "Activating system configuration...\n"

# It is a bit annoying that we need to interpret $action, and that we are
# reponsible both for switching profiles and for activating the configuration.
#
# At some point NixOS may gain a high-level script that does all this for us:
# https://github.com/NixOS/nixpkgs/pull/344407

if [[ "$action" = switch || "$action" = boot ]]; then
  ssh "root@$fqdn" \
    nix-env -p /nix/var/nix/profiles/system \
    --set "$target"
fi

# We activate the system configuration inside a systemd-run unit.
# This ensures that if our SSH connection were to drop (eg. because network is
# unreliable or deployment causes openssh to restart), the activation runs to
# completion anyway. Without it we may abort the activation mid-way and leaves
# the system in an inconsistent state.
# 
# This idea comes from nixos-rebuild, see https://github.com/NixOS/nixpkgs/issues/39118
#
# shellcheck disable=SC2029
ssh "root@$fqdn" \
  systemd-run \
  -E LOCALE_ARCHIVE \
  --collect \
  --no-ask-password \
  --pipe \
  --quiet \
  --same-dir \
  --service-type=exec \
  --unit=nixos-rebuild-switch-to-configuration \
  --wait \
  "$target/bin/switch-to-configuration" "$action"
