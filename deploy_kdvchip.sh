#!/usr/bin/env bash
# KDV_CHIP_V1 deploy (CLIENT-only). SUNUCUDA. scp: bu .sh + patch_kdv_chip.py.
set -uo pipefail
APPDIR=/opt/krb-assessment; HERE="$(cd "$(dirname "$0")" && pwd)"
IMG=krb-assessment:secure; APP=krb-assessment
cd "$APPDIR"
if [ "${1:-}" != "build" ]; then
  python3 "$HERE/patch_kdv_chip.py" "$APPDIR/shells/finans.html"
  python3 - "$APPDIR/shells/finans.html" <<'PY'
import re,sys
h=open(sys.argv[1],encoding="utf-8").read();m=re.findall(r"<script>(.*?)</script>",h,re.S)
open("/tmp/_kc.js","w",encoding="utf-8").write("\n;\n".join(m))
PY
  node --check /tmp/_kc.js && echo "CLIENT JS OK"
  echo "KDVMAP: $(grep -c KDVMAP "$APPDIR/shells/finans.html")"
  echo '=== FAZ1 bitti. JS OK ise: ./deploy_kdvchip.sh build ==='
else
  docker build -t "$IMG" .; docker compose up -d --force-recreate "$APP"; sleep 3
  echo "KONTEYNER KDV_CHIP: $(docker exec "$APP" grep -c KDV_CHIP_V1 /app/shells/finans.html)"
  echo '=== FAZ2 bitti. Nakit Yolculugu kartlarinda KDV bazi rozeti; Karlilik basliginda "tumu KDV haric". ==='
fi
