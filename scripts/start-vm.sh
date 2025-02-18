set -eu

if [[ $# -lt 1 ]]; then
  hostnames=$(jq -r 'keys | join(", ")' $VM_CONFIGURATIONS)
  cat >&2 <<EOF
Usage: $0 hostname ...
Valid hostnames: $hostnames

Additional arguments are passed to qemu.
EOF
  exit 1
fi

host="$1"
url=$(jq --arg host "$host" -r '.[$host].vaultUrl' $VM_CONFIGURATIONS)
token=$(vault print token)
if [[ -z $token ]]; then
  printf "Logging in to %s\n" "$url"
  token=$(env VAULT_ADDR= "$url" vault login - method=github -field=token)
fi

drvPath=$(jq --arg host "$host" -r '.[$host].drvPath' $VM_CONFIGURATIONS)
mainProgram=$(jq --arg host "$host" -r '.[$host].mainProgram' $VM_CONFIGURATIONS)

exec "$(nix-store --realise "$drvPath")/bin/$mainProgram" \
   -fw_cfg name=opt/vault-token,string="$token" "${@:2}"
