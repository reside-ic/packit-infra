set -eu

if [[ $# -lt 1 ]]; then
  hostnames=$(nix eval --quiet --raw ".#nixosConfigurations" --apply 'x: builtins.concatStringsSep ", " (builtins.attrNames x)')
  cat >&2 <<EOF
Usage: $0 hostname ...
Valid hostnames: $hostnames

Additional arguments are passed to qemu.
EOF
  exit 1
fi

host="$1"
url=$(nix eval ".#nixosConfigurations.$host".config.vault.url)
token=$(vault print token)
if [[ -z $token ]]; then
  printf "Logging in to %s\n" "$url"
  token=$(env VAULT_ADDR= "$url" vault login - method=github -field=token)
fi

nix run ".#nixosConfigurations.$1.config.system.build.vm" -- \
  -fw_cfg name=opt/vault-token,string="$token" "${@:2}"
