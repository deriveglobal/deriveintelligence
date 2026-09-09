#!/usr/bin/env bash
# FINANS_TESVIK (WIN_V1 server + CHIP_V1 client) deploy. SUNUCUDA.
# scp: bu .sh + patch_tesvik_server.py + patch_tesvik_client.py + tesvik_fp.sql AYNI klasore (/opt/krb-assessment).
#   ./deploy_tesvik.sh        -> FAZ1: iki patch + JS syntax (server+client) + grep
#   ./deploy_tesvik.sh build  -> FAZ2: docker build + up + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment; PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: server_container.mjs + shells/finans.html patch ==='
  python3 "$HERE/patch_tesvik_server.py" "$APPDIR/server_container.mjs"
  node --check "$APPDIR/server_container.mjs" && echo "SERVER JS OK"
  python3 "$HERE/patch_tesvik_client.py" "$APPDIR/shells/finans.html"
  echo "g2Tesvik kart (>=1 beklenir): $(grep -c 'id=\"g2Tesvik\"' "$APPDIR/shells/finans.html")"
  python3 - "$APPDIR/shells/finans.html" <<'PY'
import re,sys
h=open(sys.argv[1],encoding="utf-8").read();m=re.findall(r"<script>(.*?)</script>",h,re.S)
open("/tmp/_tv.js","w",encoding="utf-8").write("\n;\n".join(m))
PY
  node --check /tmp/_tv.js && echo "CLIENT JS OK"
  echo "server marker (1): $(grep -c FINANS_TESVIK_WIN_V1 "$APPDIR/server_container.mjs")  client marker (2): $(grep -c FINANS_TESVIK_CHIP_V1 "$APPDIR/shells/finans.html")"
  echo '=== FAZ1 bitti. Hepsi OK ise: ./deploy_tesvik.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER server marker (1 beklenir): $(docker exec "$APP" grep -c FINANS_TESVIK_WIN_V1 /app/server.mjs)"
  echo "KONTEYNER client g2Tesvik (>=1 beklenir): $(docker exec "$APP" grep -c 'id=\"g2Tesvik\"' /app/shells/finans.html)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/tesvik_fp.sql"
  echo '=== FAZ2 bitti. Karlilik gorunumunde "Kazanilan Tesvik · markalardan" karti, secili donemi izler. ==='
fi
