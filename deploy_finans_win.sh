#!/usr/bin/env bash
# FINANS_WIN_V1 deploy. SUNUCUDA. scp: bu .sh + patch_finans_win.py + finans_win_fp.sql AYNI klasore.
#   ./deploy_finans_win.sh        -> FAZ1: patch + node --check + grep + akis-pencere ispati (BUILD YOK)
#   ./deploy_finans_win.sh build  -> FAZ2: docker build + up + konteyner grep + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment
PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
T=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: HOST patch + dogrulama ==='
  python3 "$HERE/patch_finans_win.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "node --check OK"
  echo "HOST marker (6 beklenir): $(grep -c FINANS_WIN_V1 "$APPDIR/server_container.mjs")"
  echo '--- akis pencere ispati: 3 ay vs 12 ay net satis+marj FARKLI olmali ---'
  docker exec "$PG" psql -U "$DBU" -d "$DBN" -c "SELECT '3 ay' w, round(sum(ciro)/1e6,1) net_m, round(sum(brut_kar)/nullif(sum(ciro),0)*100,1) marj FROM bi_marj_atom WHERE tenant_id::text='$T' AND ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text='$T')-3*INTERVAL '1 month') AND ay<=(SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text='$T') UNION ALL SELECT '12 ay', round(sum(ciro)/1e6,1), round(sum(brut_kar)/nullif(sum(ciro),0)*100,1) FROM bi_marj_atom WHERE tenant_id::text='$T' AND ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text='$T')-12*INTERVAL '1 month') AND ay<=(SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text='$T');"
  echo '=== FAZ1 bitti. marker=6 ise: ./deploy_finans_win.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER marker (6 beklenir): $(docker exec "$APP" grep -c FINANS_WIN_V1 /app/server.mjs)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/finans_win_fp.sql"
  echo '=== FAZ2 bitti. Server hazir (geriye-uyumlu). SIRADAKI: client finans.html (re-fetch + rozet + yeni kartlar). ==='
fi
