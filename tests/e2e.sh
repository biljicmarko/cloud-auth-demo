#!/usr/bin/env bash
# End-to-end check of the OIDC login flow, the way a browser does it:
#   1. anonymous request to nginx is redirected to the Keycloak login page
#   2. wrong password is rejected by Keycloak
#   3. correct password lands on the protected page via /_callback
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost}"
REALM="${KC_REALM:-demo}"
USERNAME="${KC_TEST_USER:-demo-user}"
PASSWORD="${KC_TEST_USER_PASSWORD:-demopass}"
EXPECTED_TEXT="successfully authenticated"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

# Fetch the Keycloak login form starting from nginx; print the form's action URL.
login_form_action() {
  local jar="$1"
  curl -sSL -c "$jar" -b "$jar" "$BASE_URL/" -o "$workdir/login.html"
  grep -o 'id="kc-form-login"[^>]*action="[^"]*"' "$workdir/login.html" \
    | sed -E 's/.*action="([^"]*)".*/\1/; s/&amp;/\&/g'
}

# 1. Anonymous request must be redirected to this realm's authorization endpoint
location="$(curl -sS -o /dev/null -w '%{redirect_url}' "$BASE_URL/")"
[[ "$location" == *"/realms/$REALM/protocol/openid-connect/auth"* ]] \
  || fail "anonymous request not redirected to Keycloak (got: '${location:-no redirect}')"
pass "anonymous request redirected to Keycloak"

# 2. Wrong password must not reach the protected page
action="$(login_form_action "$workdir/bad.jar")"
[[ -n "$action" ]] || fail "Keycloak login form not found"
curl -sSL -c "$workdir/bad.jar" -b "$workdir/bad.jar" \
  --data-urlencode "username=$USERNAME" --data-urlencode "password=wrong-$PASSWORD" \
  "$action" -o "$workdir/bad.html"
grep -q "$EXPECTED_TEXT" "$workdir/bad.html" && fail "wrong password reached the protected page"
pass "wrong password rejected"

# 3. Correct password must end on the protected page
action="$(login_form_action "$workdir/good.jar")"
curl -sSL -c "$workdir/good.jar" -b "$workdir/good.jar" \
  --data-urlencode "username=$USERNAME" --data-urlencode "password=$PASSWORD" \
  "$action" -o "$workdir/good.html"
grep -q "$EXPECTED_TEXT" "$workdir/good.html" \
  || fail "login did not reach the protected page (Keycloak may require an action, e.g. profile update)"
pass "login reached the protected page"

# 4. The session cookie alone must now be enough
status="$(curl -sS -o /dev/null -w '%{http_code}' -b "$workdir/good.jar" "$BASE_URL/")"
[[ "$status" == "200" ]] || fail "authenticated session not accepted (HTTP $status)"
pass "session cookie accepted"
