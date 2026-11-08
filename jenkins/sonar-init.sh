#!/bin/sh
# Prepares SonarQube for Jenkins: admin password + analysis token.
set -eu
: "${SONAR_URL:?}" "${SONAR_ADMIN_PASSWORD:?}"

echo "Waiting for SonarQube at $SONAR_URL ..."
until curl -fs "$SONAR_URL/api/system/status" | grep -q '"status":"UP"'; do
  sleep 5
done

# First start only: replace the default admin/admin password.
if curl -fs -u admin:admin "$SONAR_URL/api/authentication/validate" | grep -q '"valid":true'; then
  curl -fsS -u admin:admin -X POST "$SONAR_URL/api/users/change_password" \
    --data-urlencode "login=admin" \
    --data-urlencode "previousPassword=admin" \
    --data-urlencode "password=$SONAR_ADMIN_PASSWORD"
  echo "Admin password set."
fi

# A fresh token each time (tokens can't be read back after creation).
curl -fs -u "admin:$SONAR_ADMIN_PASSWORD" -X POST "$SONAR_URL/api/user_tokens/revoke" \
  --data-urlencode "name=jenkins" >/dev/null || true
token=$(curl -fsS -u "admin:$SONAR_ADMIN_PASSWORD" -X POST "$SONAR_URL/api/user_tokens/generate" \
  --data-urlencode "name=jenkins" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$token" ] || { echo "Could not create the token" >&2; exit 1; }
printf '%s' "$token" > /sonar-token/token
echo "Token for Jenkins written."
