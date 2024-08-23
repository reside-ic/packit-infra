#!/usr/bin/env bash
set -e

if [[ "$#" -ne 3 ]]; then
  echo >&2 "Usage: $0 INSTANCE USERNAME PASSWORD"
  exit 1
fi

INSTANCE=$1
USERNAME=$2
PASSWORD=$3
PASSWORD_BCRYPT=$(htpasswd -bnB "" "$PASSWORD" | tr -d ':\n')
UUID=$(uuidgen)

psql -U "$INSTANCE" -d "$INSTANCE" \
    -v "uuid=$UUID" \
    -v "username=$USERNAME" \
    -v "password=$PASSWORD_BCRYPT" <<EOF
INSERT INTO "user" (id, username, display_name, password, user_source, last_logged_in)
VALUES (:'uuid', :'username', :'username', :'password', 'basic', NOW());
EOF
