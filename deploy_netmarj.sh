#!/usr/bin/env bash
# FINANS_TESVIK_NETMARJ_V1 deploy (CLIENT-only). SUNUCUDA.
# scp: bu .sh + patch_tesvik_netmarj.py + netmarj_fp.sql AYNI klasore (/opt/krb-assessment).
#   ./deploy_netmarj.sh        -> FAZ1: patch finans.html + JS syntax + grep
#   ./deploy_netmarj.sh build  -> FAZ2: docker build + up + fingerprint
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment; PG=krb-assessment-postgres; DBU=assessment_app; DBN=assessment_platform
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  echo '=== FAZ1: patch shells/finans.html ==='
  python3 "$HERE/patch_tesvik_netmarj.py" "$APPDIR/shells/finans.html"
  echo "g2NetMarj kart (>=1): $(grep -c 'id=\"g2NetMarj\"' "$APPDIR/shells/finans.html")  | GÖMÜLMEDİ kalan (0): $(grep -c 'GÖMÜLMEDİ' "$APPDIR/shells/finans.html")"
  python3 - "$APPDIR/shells/finans.html" <<'PY'
import re,sys
h=open(sys.argv[1],encoding="utf-8").read();m=re.findall(r"<script>(.*?)</script>",h,re.S)
open("/tmp/_nm.js","w",encoding="utf-8").write("\n;\n".join(m))
PY
  node --check /tmp/_nm.js && echo "CLIENT JS OK"
  echo '=== FAZ1 bitti. g2NetMarj>=1, GÖMÜLMEDİ=0, JS OK ise: ./deploy_netmarj.sh build ==='
else
  echo '=== FAZ2: docker build + up + fingerprint ==='
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER g2NetMarj (>=1 beklenir): $(docker exec "$APP" grep -c 'id=\"g2NetMarj\"' /app/shells/finans.html)"
  echo "KONTEYNER GÖMÜLMEDİ (0 beklenir):   $(docker exec "$APP" grep -c 'GÖMÜLMEDİ' /app/shells/finans.html)"
  docker exec -i "$PG" psql -U "$DBU" -d "$DBN" < "$HERE/netmarj_fp.sql"
  echo '=== FAZ2 bitti. "Net Marj (teşvik sonrası)" canli: ~%15,6 (12ay), secili donemi izler. ==='
fi
