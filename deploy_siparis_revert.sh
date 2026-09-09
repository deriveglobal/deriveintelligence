#!/usr/bin/env bash
# FINANS_SIPARIS_REVERT_V1 deploy. SUNUCUDA. scp: bu .sh + patch_siparis_revert.py + siparis_revert_fp.sql AYNI klasore.
#   ./deploy_siparis_revert.sh        -> FAZ1: patch + JS syntax + grep
#   ./deploy_siparis_revert.sh build  -> FAZ2: docker build + up + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment; PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: patch finans.html ==='
  python3 "$HERE/patch_siparis_revert.py" "$APPDIR/shells/finans.html"
  echo "gSiparis id kalan (0 beklenir): $(grep -c 'id=\"gSiparis\"' "$APPDIR/shells/finans.html")"
  python3 - "$APPDIR/shells/finans.html" <<'PY'
import re,sys
h=open(sys.argv[1],encoding="utf-8").read();m=re.findall(r"<script>(.*?)</script>",h,re.S)
open("/tmp/_sr.js","w",encoding="utf-8").write("\n;\n".join(m))
PY
  node --check /tmp/_sr.js && echo "JS OK"
  echo '=== FAZ1 bitti. id=0, JS OK ise: ./deploy_siparis_revert.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER marker (1 beklenir): $(docker exec "$APP" grep -c FINANS_SIPARIS_REVERT_V1 /app/shells/finans.html)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/siparis_revert_fp.sql"
  echo '=== FAZ2 bitti. Siparis bekleyen karti "—" (dogrulaniyor). Diger 3 metrik canli. ==='
fi
