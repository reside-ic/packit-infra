#!/usr/bin/env sh

USERS="plietar M-Kusumgar"

for username in $USERS; do
  curl -sS "https://github.com/$username.keys"
done > authorized_keys
