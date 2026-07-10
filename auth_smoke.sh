#!/usr/bin/env bash
# auth_smoke.sh — auth-flow regression check. Run on the host: bash auth_smoke.sh
# Checks endpoint liveness + status codes, reset-token generation, and that the
# client/server guards are still in place. Prints PASS/FAIL per check.
set -uo pipefail
BASE="http://localhost:8080"   # host port -> container 3000
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tA -c"
PASS=0; FAIL=0
chk(){ if [ "$2" = "$3" ]; then echo "PASS  $1 ($3)"; PASS=$((PASS+1)); else echo "FAIL  $1 (want $2, got $3)"; FAIL=$((FAIL+1)); fi; }
grepchk(){ if docker exec krb-assessment grep -q -- "$3" "$2" 2>/dev/null; then echo "PASS  $1"; PASS=$((PASS+1)); else echo "FAIL  $1 (missing: $3)"; FAIL=$((FAIL+1)); fi; }
code(){ curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$@"; }

echo "== Endpoint liveness / status codes =="
chk "login rejects bad creds -> 401" 401 "$(code -X POST $BASE/api/auth/login -H 'Content-Type: application/json' -d '{"email":"nobody@example.com","password":"wrongwrongwrong"}')"
chk "me without auth -> 401" 401 "$(code $BASE/api/auth/me)"
chk "platform/me without auth -> 401" 401 "$(code $BASE/api/platform/me)"
chk "reset-password bad token -> 400" 400 "$(code -X POST $BASE/api/auth/reset-password -H 'Content-Type: application/json' -d '{"token":"invalidtoken","password":"abcd12345"}')"
chk "root with ?reset= serves app -> 200" 200 "$(code "$BASE/?reset=smoketest")"

echo "== Password-reset token generation =="
B=$($PSQL "SELECT count(*) FROM password_reset_tokens" | tr -d '[:space:]')
code -X POST $BASE/api/auth/request-password-reset -H 'Content-Type: application/json' -d '{"email":"fbilen@krb.com.tr"}' >/dev/null
sleep 1
A=$($PSQL "SELECT count(*) FROM password_reset_tokens" | tr -d '[:space:]')
if [ "${A:-0}" -gt "${B:-0}" ]; then echo "PASS  request-password-reset created a token (${B} -> ${A})"; PASS=$((PASS+1));
else echo "FAIL  request-password-reset created NO token (${B} -> ${A})"; FAIL=$((FAIL+1)); fi

echo "== Client guards (regression) =="
grepchk "reset link shows set-password form"        /app/app.js "RESET_LINK_FIX"
grepchk "reset link skips session restore/applyRole" /app/app.js "!sessionRestored && !activeResetToken"
grepchk "loading spinner during platform gap"        /app/app.js "_plLoad"
grepchk "no participant fallback while routing"      /app/app.js "__platformSessionPending) return"

echo "== Server auth endpoints present =="
for e in "/api/auth/login" "/api/auth/logout" "/api/auth/me" "/api/auth/request-password-reset" "/api/auth/reset-password" "/api/platform/me"; do
  grepchk "server has $e" /app/server.mjs "\"$e\""
done

echo ""
echo "TOTAL: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then echo "✅ AUTH OK"; else echo "❌ REGRESSIONS FOUND"; fi
