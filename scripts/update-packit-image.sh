#!/usr/bin/env

TAG=$(jq -r '.rev[:7]' packages/packit/sources.json)
nix-prefetch-docker --json mrcide/packit-api "$TAG" > packages/packit/image.json
