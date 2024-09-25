#!/usr/bin/env bash
set -eu

export VAULT_ADDR="https://vault.dide.ic.ac.uk:8200"

VAULT_TOKEN=$(cat /sys/firmware/qemu_fw_cfg/by_name/opt/vault-token/raw)
export VAULT_TOKEN

PACKIT_GITHUB_CLIENT_ID=$(vault kv get -mount=secret -field=id packit/githubauth/auth/githubclient)
PACKIT_GITHUB_CLIENT_SECRET=$(vault kv get -mount=secret -field=secret packit/githubauth/auth/githubclient)

cat > /var/secrets/github-oauth <<EOF
PACKIT_GITHUB_CLIENT_ID=$PACKIT_GITHUB_CLIENT_ID
PACKIT_GITHUB_CLIENT_SECRET=$PACKIT_GITHUB_CLIENT_SECRET
EOF
