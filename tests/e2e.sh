#!/usr/bin/env bash
# End-to-end check of the OIDC login flow, the way a browser does it:
#   1. anonymous request to nginx is redirected to the Keycloak login page,
#      served through the same public entry point (Keycloak is not exposed)
#   2. the admin (master) realm is not reachable through the public entry point
#   3. wrong password is rejected by Keycloak
#   4. correct password lands on the protected page via /_callback
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

# 1. Anonymous request must be redirected to the realm's login, behind nginx
location="$(curl -sS -o /dev/null -w '%{redirect_url}' "$BASE_URL/")"
[[ "$location" == "$BASE_URL/realms/$REALM/protocol/openid-connect/auth"* ]] \
  || fail "anonymous request not redirected to Keycloak via $BASE_URL (got: '${location:-no redirect}')"
pass "anonymous request redirected to Keycloak login behind nginx"

# 2. Admin realm must be blocked at the public entry point
status="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/realms/master/.well-known/openid-configuration")"
[[ "$status" == "404" ]] || fail "master realm reachable through $BASE_URL (HTTP $status)"
pass "master realm not exposed"

# 3. Wrong password must not reach the protected page
action="$(login_form_action "$workdir/bad.jar")"
[[ -n "$action" ]] || fail "Keycloak login form not found"
curl -sSL -c "$workdir/bad.jar" -b "$workdir/bad.jar" \
  --data-urlencode "username=$USERNAME" --data-urlencode "password=wrong-$PASSWORD" \
  "$action" -o "$workdir/bad.html"
grep -q "$EXPECTED_TEXT" "$workdir/bad.html" && fail "wrong password reached the protected page"
pass "wrong password rejected"

# 4. Correct password must end on the protected page
action="$(login_form_action "$workdir/good.jar")"
curl -sSL -c "$workdir/good.jar" -b "$workdir/good.jar" \
  --data-urlencode "username=$USERNAME" --data-urlencode "password=$PASSWORD" \
  "$action" -o "$workdir/good.html"
grep -q "$EXPECTED_TEXT" "$workdir/good.html" \
  || fail "login did not reach the protected page (Keycloak may require an action, e.g. profile update)"
pass "login reached the protected page"

# 5. The session cookie alone must now be enough
status="$(curl -sS -o /dev/null -w '%{http_code}' -b "$workdir/good.jar" "$BASE_URL/")"
[[ "$status" == "200" ]] || fail "authenticated session not accepted (HTTP $status)"
pass "session cookie accepted"
