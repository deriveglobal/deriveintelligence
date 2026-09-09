#!/usr/bin/env bash
# ZIYARET_LIMIT_V1 — ziyaret listesi LIMIT 200 -> 1000. Yuksek hacimli repler (Ali Kemal 763 vb.)
#   eski ziyaretlerini goremiyordu (yalniz en yeni 200). Veri kayipli DEGIL, sadece kesikti.
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_ziyaret_limit.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
TS=$(date +%s); cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"
python3 patch_ziyaret_limit.py "$S"
node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/zlim_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/zlim_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c ZIYARET_LIMIT_V1 /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c ZIYARET_LIMIT_V1 /app/server.mjs
echo "[bitti] Ziyaret listesi 1000 kayda cikti. Repler tum gecmisini gorur. iOS relaunch / hard refresh."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
