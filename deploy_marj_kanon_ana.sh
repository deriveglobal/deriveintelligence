#!/usr/bin/env bash
# MARJ_KANON_ANA_V1 deploy. SUNUCUDA. scp: bu .sh + patch_marj_kanon_ana.py + marj_kanon_ana_verify.sql + marj_kanon_ana_fp.sql AYNI klasore.
#   ./deploy_marj_kanon_ana.sh         -> FAZ1: patch + node --check + HOST grep + DB verify (marj 11,5). BUILD YOK.
#   ./deploy_marj_kanon_ana.sh build   -> FAZ2: docker build (compose DEGIL) + up + konteyner grep + fingerprint.
set -uo pipefail
APPDIR=/opt/krb-assessment
HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment
PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: HOST patch + dogrulama (BUILD YOK) ==='
  python3 "$HERE/patch_marj_kanon_ana.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "node --check OK"
  echo "HOST marker (2 beklenir): $(grep -c MARJ_KANON_ANA_V1 "$APPDIR/server_container.mjs")"
  echo "Eski ERP marj motoru kalinti (0 beklenir): $(grep -c 's.maliyet AS smm' "$APPDIR/server_container.mjs")"
  echo '--- DB verify (marj_pct ~11,5 / ciro ~801 beklenir; 14,8 DEGIL) ---'
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/marj_kanon_ana_verify.sql"
  echo '=== FAZ1 bitti. marker=2 VE marj_pct 11,5 ise: ./deploy_marj_kanon_ana.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .
  docker compose up -d --force-recreate "$APP"
  sleep 3
  echo "KONTEYNER marker (2 beklenir): $(docker exec "$APP" grep -c MARJ_KANON_ANA_V1 /app/server.mjs)"
  echo '--- fingerprint ---'
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/marj_kanon_ana_fp.sql"
  echo '=== FAZ2 bitti. Bugun odasini yenile: marj %11,5 (Finans/Kokpit ile birebir). ==='
fi
