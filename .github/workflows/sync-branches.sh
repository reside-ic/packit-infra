#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo >&2 "Usage: $0 <hostname>"
  exit 1
fi

machine=$1
branch=deploy/$machine
ref=refs/heads/$branch
rev=$(git rev-parse HEAD)
revShort=$(git rev-parse --short HEAD)
tree=$(git rev-parse $rev:)

if ! previous=$(git rev-parse --quiet --verify "$ref"); then
  echo "Creating new branch $branch"
  empty=$(git hash-object -t tree /dev/null)
  previous=$(git commit-tree -m "Initial deployment to $machine" $empty)
fi

if git rev-parse "$previous^@" | grep -q $rev; then
  echo "$revShort is already of parent of $branch, nothing to do."
  exit
else
  commit=$(git commit-tree -m "Deploy $rev to $machine" -p $previous -p $rev $tree)
fi

echo "Updating $branch with $revShort as a parent."
git update-ref $ref $commit
