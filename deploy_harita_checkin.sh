#!/usr/bin/env bash
# HARITA_CHECKIN_V1 (server + client) — Haritada her ziyaret check-in noktasi ayri yesil pin (~100m dedup).
#   Cok-lokasyonlu firmalar (or NUH BETON) artik her sahasi ayri gorunur. Rep kendi, manager/admin hepsi.
# KULLANIM (Mac'ten):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_harita_checkin_server.py patch_harita_checkin_client.py deploy_harita_checkin.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_harita_checkin.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs; C=shells/saha.js
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_harita_checkin_server.py ] || { echo "HATA: server patch yok (scp?)"; exit 1; }
[ -f patch_harita_checkin_client.py ] || { echo "HATA: client patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; cp -a "$C" "$C.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_harita_checkin_server.py "$S"
python3 patch_harita_checkin_client.py "$C"

geri_al() { cp -a "$S.bak.$TS" "$S"; cp -a "$C.bak.$TS" "$C"; }
node --check "$S" && echo "[ok] node --check server" || { echo "HATA server"; geri_al; exit 1; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA client"; geri_al; exit 1; }

docker build -t krb-assessment:secure . >/tmp/hcheckin_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/hcheckin_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c "HARITA_CHECKIN_V1" /app/server.mjs 2>/dev/null || docker exec "$CID" grep -c "HARITA_CHECKIN_V1" /app/server_container.mjs
echo -n "[dogrula] client marker: "; docker exec "$CID" grep -c "HARITA_CHECKIN_V1" /app/shells/saha.js
echo -n "[smoke] uc yanit: "; docker exec "$CID" node -e 'fetch("http://localhost:3000/api/saha/harita-checkinler").then(r=>console.log("HTTP",r.status)).catch(e=>console.log("ERR",e.message))' 2>/dev/null || echo "(smoke atlandi)"

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. iOS relaunch / hard refresh. Harita sekmesinde her check-in noktasi ayri yesil pin; NUH BETON gibi cok-sahali firmalar artik ayri ayri gorunur."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
