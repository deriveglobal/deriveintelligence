#!/usr/bin/env bash
# LOGOUT_IDLE_FIX_V1 deploy. SUNUCUDA. scp: bu .sh + patch_logout_idle.py + logout_idle_fp.sql AYNI klasore.
#   ./deploy_logout_idle.sh        -> FAZ1: patch app.js + node --check + grep (BUILD YOK)
#   ./deploy_logout_idle.sh build  -> FAZ2: docker build + up + konteyner grep + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment
PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: HOST patch app.js + dogrulama ==='
  python3 "$HERE/patch_logout_idle.py" "$APPDIR/app.js"
  node --check "$APPDIR/app.js" && echo "node --check OK"
  echo "HOST marker (1 beklenir): $(grep -c LOGOUT_IDLE_FIX_V1 "$APPDIR/app.js")"
  echo "eski 3-dk kalinti (0 beklenir): $(grep -c 'IDLE_MS = 3 \* 60 \* 1000' "$APPDIR/app.js")"
  echo '=== FAZ1 bitti. marker=1 ise: ./deploy_logout_idle.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .
  docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER marker (1 beklenir): $(docker exec "$APP" grep -c LOGOUT_IDLE_FIX_V1 /app/app.js)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/logout_idle_fp.sql"
  echo '=== FAZ2 bitti. Rep uygulamasini kapat-ac (yeni app.js hash cache-bust); artik 3 dk yerine 30 dk. ==='
fi
