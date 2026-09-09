#!/usr/bin/env bash
# KADERI_FN_MAP_V1 deploy — asistan haritasina onsiparis_kaderi() cagri talimati. SUNUCUDA.
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  python3 "$HERE/patch_kaderi_map.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "SERVER JS OK"
  echo '=== FAZ1 bitti. JS OK ise: ./deploy_kaderimap.sh build ==='
else
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER marker (1 beklenir): $(docker exec "$APP" grep -c 'onsiparis_kaderi(tenant_id) fonksiyonunu' /app/server.mjs)"
  echo '=== FAZ2 bitti. Asistana tekrar sor: "kis on-siparisinde nerede asiriya kactik?" ==='
fi
