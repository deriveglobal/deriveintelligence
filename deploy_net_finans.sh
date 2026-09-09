#!/usr/bin/env bash
# NET_GECIKMIS_FINANS_V1 deploy. SUNUCUDA. scp: bu .sh + patch_net_finans.py + net_finans_fp.sql AYNI klasore.
#   ./deploy_net_finans.sh        -> FAZ1: patch + node --check + grep + net dogrulama (BUILD YOK)
#   ./deploy_net_finans.sh build  -> FAZ2: docker build + up + konteyner grep + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment
PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
T=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: HOST patch + dogrulama ==='
  python3 "$HERE/patch_net_finans.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "node --check OK"
  echo "HOST marker (2 beklenir): $(grep -c NET_GECIKMIS_FINANS_V1 "$APPDIR/server_container.mjs")"
  echo "--- net gecikmis (53,4M civari beklenir) ---"
  docker exec "$PG" psql -U "$DBU" -d "$DBN" -c "SELECT round(sum(net_gecikmis)/1e6,1) net_m, count(*) FILTER (WHERE net_gecikmis>0) musteri FROM v_net_gecikmis_musteri WHERE tenant_id::text='$T';"
  echo '=== FAZ1 bitti. marker=2 ise: ./deploy_net_finans.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .
  docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER marker (2 beklenir): $(docker exec "$APP" grep -c NET_GECIKMIS_FINANS_V1 /app/server.mjs)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/net_finans_fp.sql"
  echo '=== FAZ2 bitti. Finans deger-agaci gecikmis artik NET. ==='
fi
