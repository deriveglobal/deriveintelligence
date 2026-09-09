#!/usr/bin/env bash
# AUTO_LOGOUT_V1 — rol-bazli oto cikis (idle + mutlak sure).
#   Yonetici/mudur web: 30dk bosta -> uyari -> cikis; mutlak 24s. Rep: mutlak 7g, bosta yok.
#   Native: bosta yok, yalniz mutlak. app.js'e eklenir + index.html app.js surum bump (cache).
set -euo pipefail
cd /opt/krb-assessment
A=app.js
H=index.html
[ -f "$A" ] || { echo "HATA: $A yok"; exit 1; }
[ -f "$H" ] || { echo "HATA: $H yok"; exit 1; }
[ -f patch_auto_logout.py ] || { echo "HATA: patch_auto_logout.py yok (scp?)"; exit 1; }
TS=$(date +%s)
cp -a "$A" "$A.bak.$TS"; cp -a "$H" "$H.bak.$TS"; echo "[yedek] $A.bak.$TS + $H.bak.$TS"
python3 patch_auto_logout.py "$A"
sed -i.tmp -E "s#/app\.js\?v=[^\"']*#/app.js?v=alo${TS}#g" "$H" && rm -f "$H.tmp"
geri_al(){ echo "[GERI ALINIYOR]"; cp -a "$A.bak.$TS" "$A"; cp -a "$H.bak.$TS" "$H"; }
node --check "$A" && echo "[ok] node --check $A" || { echo "HATA: node --check $A"; geri_al; exit 1; }
docker build -t krb-assessment:secure . >/tmp/alo_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/alo_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] app.js marker: "; docker exec "$CID" grep -c AUTO_LOGOUT_V1 /app/app.js 2>/dev/null || echo "?"
echo -n "[dogrula] index surum:   "; docker exec "$CID" grep -o "app.js?v=alo${TS}" /app/index.html 2>/dev/null | head -1 || echo "?"
echo "[bitti] Oto cikis CANLI. Web hard refresh (Cmd+Shift+R) / iOS relaunch."
echo "GERI ALMA: cp -a $A.bak.$TS $A && cp -a $H.bak.$TS $H && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
