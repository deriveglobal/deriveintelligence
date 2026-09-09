#!/usr/bin/env bash
# ZIYARET_TASLAK_V1 — aktivite (ziyaret) formunda otomatik yerel taslak + geri yukle (foto dahil).
#   Ani cikis/oturum dusmesinde veri kaybini onler. Hata: Ali Kemal Picakci 30/31.07.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_ziyaret_taslak_client.py deploy_ziyaret_taslak.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_taslak.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_ziyaret_taslak_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_ziyaret_taslak_client.py "$C"

node --check "$C" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/ztaslak_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ztaslak_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "ZIYARET_TASLAK_V1" /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Aktivite doldururken alanlar cihaza yedeklenir; form yeniden acilinca 'Kaydedilmis taslak var → Geri yukle' cikar."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
