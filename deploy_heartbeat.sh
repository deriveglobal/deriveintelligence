#!/usr/bin/env bash
# REP_AKTIVITE_HB — saha.js heartbeat (tum repler /api/saha/aktivite-ping'e 60sn'de bir).
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] && [ -f patch_heartbeat.py ] || { echo "HATA: dosya yok"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_heartbeat.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA node — geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/hb_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/hb_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker: "; docker exec $(docker compose ps -q krb-assessment) grep -c REP_AKTIVITE_HB /app/shells/saha.js
echo "[bitti] Cmd+Shift+R. Reptler uygulamayi actikca aktivite akmaya baslar."
