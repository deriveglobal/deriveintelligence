#!/usr/bin/env bash
# REP_AKTIVITE_V1 — saha_rep_aktivite tablosu + /api/saha/aktivite-ping (rep) + /api/saha/rep-aktivite (yalniz yonetim).
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_rep_aktivite.py ] || { echo "HATA: patch yok"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_rep_aktivite.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA node — geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/ra_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/ra_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
C=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec $C grep -c REP_AKTIVITE_V1 /app/server.mjs 2>/dev/null || docker exec $C grep -c REP_AKTIVITE_V1 /app/server_container.mjs
echo "[bitti] Foundation canli (gorunur degisiklik YOK). Sonraki: saha.js heartbeat + UI, bi.js panel."
echo "GERI: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
