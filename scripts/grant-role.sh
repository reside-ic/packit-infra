#!/usr/bin/env bash
set -eu

if [[ "$#" -ne 3 ]]; then
  echo >&2 "Usage: $0 INSTANCE USERNAME ROLE"
  exit 1
fi

INSTANCE=$1
USERNAME=$2
ROLE=$3

psql -U "$INSTANCE" -d "$INSTANCE" -v "username='$USERNAME'" -v "role='$ROLE'" <<EOF
INSERT INTO user_role (user_id, role_id)
SELECT u.id, r.id
FROM "user" u
CROSS JOIN "role" r
WHERE u.username = :username AND r.name = :role;
EOF
