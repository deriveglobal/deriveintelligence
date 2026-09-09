#!/usr/bin/env bash
# ANALIZ_FN — vade_makasi() + marka_saglik() fonksiyonlari + harita talimatlari. SUNUCUDA.
# scp: bu .sh + analiz_fn.sql + patch_analiz_map.py AYNI klasore (/opt/krb-assessment).
#   ./deploy_analiz.sh        -> FAZ1: fonksiyonlari kur+test (psql) + harita patch + JS check
#   ./deploy_analiz.sh build  -> FAZ2: docker build + up
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment; PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1a: fonksiyonlar + test (psql) ==='
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/analiz_fn.sql"
  echo '=== FAZ1b: sistem haritasi patch ==='
  python3 "$HERE/patch_analiz_map.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "SERVER JS OK"
  echo '=== FAZ1 bitti. Test ciktilari makul + JS OK ise: ./deploy_analiz.sh build ==='
else
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER vade marker: $(docker exec "$APP" grep -c 'vade_makasi(tenant_id) fonksiyonunu' /app/server.mjs)  saglik marker: $(docker exec "$APP" grep -c 'marka_saglik(tenant_id) fonksiyonunu' /app/server.mjs)"
  echo '=== FAZ2 bitti. Ekonomist tam: onsiparis_kaderi + vade_makasi + marka_saglik curated; asistan birlestirir. ==='
fi
