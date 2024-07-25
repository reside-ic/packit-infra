#!/usr/bin/env bash
set -eu

VAULT_ADDR=https://vault.dide.ic.ac.uk:8200
export VAULT_ADDR

VAULT_TOKEN=$(vault login -method=github -token-only)
export VAULT_TOKEN

mkdir -p /var/secrets

vault kv get -mount=secret -field=value packit/ssl/production/cert > /var/secrets/packit.cert
vault kv get -mount=secret -field=value packit/ssl/production/key > /var/secrets/packit.key

cat > /var/secrets/github-oauth <<EOF
PACKIT_GITHUB_CLIENT_ID=$(vault kv get -mount=secret -field=clientId packit/oauth/production)
PACKIT_GITHUB_CLIENT_SECRET=$(vault kv get -mount=secret -field=clientSecret packit/oauth/production)
EOF
