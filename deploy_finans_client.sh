#!/usr/bin/env bash
# FINANS_WIN_CLIENT_V1 deploy. SUNUCUDA. scp: bu .sh + patch_finans_client.py + finans_client_fp.sql AYNI klasore.
#   ./deploy_finans_client.sh        -> FAZ1: patch shells/finans.html + JS syntax + grep (BUILD YOK)
#   ./deploy_finans_client.sh build  -> FAZ2: docker build + up + konteyner grep + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment
PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: HOST patch finans.html + dogrulama ==='
  python3 "$HERE/patch_finans_client.py" "$APPDIR/shells/finans.html"
  echo "HOST marker (1 beklenir): $(grep -c FINANS_WIN_CLIENT_V1 "$APPDIR/shells/finans.html")"
  echo "yeni kart id (4 beklenir): $(grep -c 'id=\"gSizinti\"\|id=\"gOlculen\"\|id=\"gOluStok\"\|id=\"gSiparis\"' "$APPDIR/shells/finans.html")"
  echo '--- JS syntax (script blogu -> node --check) ---'
  python3 - "$APPDIR/shells/finans.html" <<'PY'
import re,sys
h=open(sys.argv[1],encoding="utf-8").read()
m=re.findall(r"<script>(.*?)</script>", h, re.S)
open("/tmp/_finc.js","w",encoding="utf-8").write("\n;\n".join(m))
print("script blok:",len(m))
PY
  node --check /tmp/_finc.js && echo "JS SYNTAX OK"
  echo '=== FAZ1 bitti. marker=1, id=4, JS OK ise: ./deploy_finans_client.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER marker (1 beklenir): $(docker exec "$APP" grep -c FINANS_WIN_CLIENT_V1 /app/shells/finans.html)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/finans_client_fp.sql"
  echo '=== FAZ2 bitti. Finans odasini hard-refresh: seçici artık akış kartlarını pencereler, 4 yeni metrik dolu. ==='
fi
