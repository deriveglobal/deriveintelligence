#!/usr/bin/env bash
# IKTISATCI_BAKIS_V1 deploy — CEO Asistani sistem haritasina ekonomist bolumu. SUNUCUDA.
# scp: bu .sh + patch_iktisatci_beyin.py + iktisatci_fp.sql AYNI klasore (/opt/krb-assessment).
#   ./deploy_iktisatci.sh        -> FAZ1: patch + JS check + grep
#   ./deploy_iktisatci.sh build  -> FAZ2: docker build + up + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment; PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: server_container.mjs patch ==='
  python3 "$HERE/patch_iktisatci_beyin.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "SERVER JS OK"
  echo "IKTISATCI_BAKIS marker (1 beklenir): $(grep -c IKTISATCI_BAKIS "$APPDIR/server_container.mjs")"
  echo '=== FAZ1 bitti. marker 1 + JS OK ise: ./deploy_iktisatci.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER marker (1 beklenir): $(docker exec "$APP" grep -c IKTISATCI_BAKIS /app/server.mjs)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/iktisatci_fp.sql"
  echo '=== FAZ2 bitti. CEO Asistanina sor: "kis on-siparisinde nerede asiriya kactik?" / "hangi markada marj sikisiyor?" ==='
fi
