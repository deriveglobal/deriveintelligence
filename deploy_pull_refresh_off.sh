#!/usr/bin/env bash
# PULL_REFRESH_OFF_V1 (client-only) — Uygulamanin pull/swipe-to-refresh ozelligi tamamen kapatildi
#   (yan-swipe kazara "Yenileniyor" tetikliyordu). Fatih 04.08.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_pull_refresh_off_client.py deploy_pull_refresh_off.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_pull_refresh_off.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_pull_refresh_off_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_pull_refresh_off_client.py "$C"

node --check "$C" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/proff_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/proff_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "PULL_REFRESH_OFF_V1" /app/shells/saha.js

# DISK HIJYENI (04 Ağu olayı sonrası standart) — biriken/dangling imajları temizle
echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. iOS relaunch / hard refresh. Ne aşağı çekişte ne yan swipe'ta 'Yenileniyor' çıkmamalı."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
