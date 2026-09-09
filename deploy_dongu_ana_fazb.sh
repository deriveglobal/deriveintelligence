#!/usr/bin/env bash
# DONGU_KANON_ANA_V1 — Dongu Faz B / Deploy 1. SUNUCUDA calistir.
# scp ile bu .sh + patch_dongu_ana_fazb.py + dongu_ana_fazb_verify.sql + dongu_ana_fazb_fingerprint.sql AYNI klasore.
# Kullanim:
#   ./deploy_dongu_ana_fazb.sh         -> FAZ1: patch + node --check + HOST grep + DB dogrulama (READ-ONLY, build YOK)
#   ./deploy_dongu_ana_fazb.sh build   -> FAZ2: build + force-recreate + konteyner grep + fingerprint
# Otomatik bulamazsa elle: export PG=... DBU=... DBN=... SVC=... APP=... sonra tekrar calistir.
set -euo pipefail
APPDIR=/opt/krb-assessment
HERE="$(cd "$(dirname "$0")" && pwd)"

PG="${PG:-$(docker ps --format '{{.Names}}' | grep -iE 'postgres|-db|_db|pg' | head -1)}"
DBU="${DBU:-$(docker exec "$PG" printenv POSTGRES_USER 2>/dev/null || echo postgres)}"
DBN="${DBN:-$(docker exec "$PG" printenv POSTGRES_DB   2>/dev/null || echo postgres)}"
SVC="${SVC:-$(cd "$APPDIR" && docker compose config --services 2>/dev/null | grep -iE 'app|krb|assess|web' | head -1)}"
APP="${APP:-$(docker ps --format '{{.Names}}' | grep -iE 'krb|assess|app' | grep -viE 'postgres|-db|_db|pg' | head -1)}"

echo "PG=$PG  DBU=$DBU  DBN=$DBN  SVC=$SVC  APP=$APP"
echo

if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: HOST patch + dogrulama (build YOK) ==='
  python3 "$HERE/patch_dongu_ana_fazb.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "node --check OK"
  m=$(grep -c DONGU_KANON_ANA_V1 "$APPDIR/server_container.mjs" || true)
  echo "HOST marker (2 beklenir): $m"
  echo '--- DB dogrulama (dso_gun 100 / stok_gun 146 beklenir) ---'
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/dongu_ana_fazb_verify.sql"
  echo
  echo '=== FAZ1 bitti. marker=2 VE 100/146 dogruysa:  ./deploy_dongu_ana_fazb.sh build ==='
else
  echo '=== FAZ2: build + force-recreate + fingerprint ==='
  cd "$APPDIR"
  if [ -n "$SVC" ]; then docker compose build "$SVC"; docker compose up -d --force-recreate "$SVC";
  else docker compose build; docker compose up -d --force-recreate; fi
  sleep 3
  m=$(docker exec "$APP" grep -c DONGU_KANON_ANA_V1 /app/server.mjs || true)
  echo "KONTEYNER marker (2 beklenir): $m"
  echo '--- fingerprint ---'
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/dongu_ana_fazb_fingerprint.sql"
  echo
  echo '=== FAZ2 bitti. Bugun odasini yenile: dso_gun 100 / stok_gun 146 (Finans ile birebir) ==='
fi
