#!/usr/bin/env bash
# INTL_CHIP_V1 deploy (CLIENT-only). SUNUCUDA. scp: bu .sh + patch_intl_chip.py.
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  python3 "$HERE/patch_intl_chip.py" "$APPDIR/shells/finans.html"
  python3 - "$APPDIR/shells/finans.html" <<'PY'
import re,sys
h=open(sys.argv[1],encoding="utf-8").read();m=re.findall(r"<script>(.*?)</script>",h,re.S)
open("/tmp/_it.js","w",encoding="utf-8").write("\n;\n".join(m))
PY
  node --check /tmp/_it.js && echo "CLIENT JS OK"
  echo "INTLMAP: $(grep -c INTLMAP "$APPDIR/shells/finans.html")"
  echo '=== FAZ1 bitti. JS OK ise: ./deploy_intlchip.sh build ==='
else
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER INTL_CHIP: $(docker exec "$APP" grep -c INTL_CHIP_V1 /app/shells/finans.html)"
  echo '=== FAZ2 bitti. Her kartta "Terim" satiri: uluslararasi finans adi + anlami. ==='
fi
