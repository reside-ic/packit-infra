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
revShort=$(git rev-parse --short $rev)
tree=$(git rev-parse $rev:)

if ! previous=$(git rev-parse --quiet --verify "$ref"); then
  echo "Creating new branch $branch"
  empty=$(git hash-object -t tree /dev/null)
  previous=$(git commit-tree -m "Initial deployment to $machine" $empty)
else
  echo "Using existing branch $branch as $(git rev-parse --short $previous)"
fi

if git rev-parse "$previous^@" | grep -q $rev; then
  echo "$revShort is already of parent of $branch, nothing to do."
  exit
else
  commit=$(git commit-tree -m "Deploy $rev to $machine" -p $previous -p $rev $tree)
fi

echo "Deploying $(git rev-parse --short $commit) to $branch (using $revShort)"
git update-ref $ref $commit
