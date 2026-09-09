#!/usr/bin/env bash
# FINANS_SIPARIS_REVERT_V2 deploy (UI temizlik). SUNUCUDA calistir.
# scp: bu .sh + patch_siparis_revert2.py + siparis_revert2_fp.sql AYNI klasore.
#   ./deploy_siparis_revert2.sh        -> FAZ1: patch + JS syntax + grep dogrulama
#   ./deploy_siparis_revert2.sh build  -> FAZ2: docker build + up + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment; PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: patch finans.html ==='
  python3 "$HERE/patch_siparis_revert2.py" "$APPDIR/shells/finans.html"
  echo "gorunur V1 comment kalan (0 beklenir): $(grep -c '/\* FINANS_SIPARIS_REVERT_V1 \*/' "$APPDIR/shells/finans.html")"
  echo "gSiparis kalan (0 beklenir):            $(grep -c 'gSiparis' "$APPDIR/shells/finans.html")"
  echo "V2 marker (1 beklenir):                 $(grep -c 'FINANS_SIPARIS_REVERT_V2' "$APPDIR/shells/finans.html")"
  python3 - "$APPDIR/shells/finans.html" <<'PY'
import re,sys
h=open(sys.argv[1],encoding="utf-8").read();m=re.findall(r"<script>(.*?)</script>",h,re.S)
open("/tmp/_sr2.js","w",encoding="utf-8").write("\n;\n".join(m))
PY
  node --check /tmp/_sr2.js && echo "JS OK"
  echo '=== FAZ1 bitti. Hepsi beklenen ise: ./deploy_siparis_revert2.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER V2 marker (1 beklenir):        $(docker exec "$APP" grep -c FINANS_SIPARIS_REVERT_V2 /app/shells/finans.html)"
  echo "KONTEYNER gorunur V1 comment (0 beklenir): $(docker exec "$APP" grep -c '/\* FINANS_SIPARIS_REVERT_V1 \*/' /app/shells/finans.html)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/siparis_revert2_fp.sql"
  echo '=== FAZ2 bitti. Kart temiz: "—" [dogrulaniyor], kod yorumu/jargon/vaat yok. ==='
fi
