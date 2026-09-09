#!/usr/bin/env bash
# AI_TENANT_KANON_V1 deploy. SUNUCUDA calistir. scp: bu .sh + patch_ai_tenant.py + ai_tenant_fp.sql AYNI klasore.
#   ./deploy_ai_tenant.sh         -> FAZ1: patch + node --check + HOST grep (marker=3, uuid=0). BUILD YOK.
#   ./deploy_ai_tenant.sh build   -> FAZ2: docker build (compose DEGIL) + up + konteyner grep + fingerprint.
set -uo pipefail
APPDIR=/opt/krb-assessment
HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure
APP=krb-assessment
PG=krb-assessment-postgres
DBU=assessment_app
DBN=assessment_platform

cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: HOST patch + dogrulama (BUILD YOK) ==='
  python3 "$HERE/patch_ai_tenant.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "node --check OK"
  echo "HOST marker (3 beklenir): $(grep -c AI_TENANT_KANON_V1 "$APPDIR/server_container.mjs")"
  echo "HOST KRB uuid literal (0 beklenir): $(grep -c f8a5d20f-ecf8-4ce2-a492-69268fbb03fa "$APPDIR/server_container.mjs")"
  echo '=== FAZ1 bitti. marker=3 VE uuid=0 ise: ./deploy_ai_tenant.sh build ==='
else
  echo '=== FAZ2: docker build (compose DEGIL) + up + fingerprint ==='
  docker build -t "$IMG" .
  docker compose up -d --force-recreate "$APP"
  sleep 3
  echo "KONTEYNER marker (3 beklenir): $(docker exec "$APP" grep -c AI_TENANT_KANON_V1 /app/server.mjs)"
  echo "KONTEYNER KRB uuid literal (0 beklenir): $(docker exec "$APP" grep -c f8a5d20f-ecf8-4ce2-a492-69268fbb03fa /app/server.mjs)"
  echo '--- fingerprint ---'
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/ai_tenant_fp.sql"
  echo '=== FAZ2 bitti. IT/dept-chat calisir; artik tenant $1 (session) — literal yok. ==='
fi
