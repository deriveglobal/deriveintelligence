#!/usr/bin/env bash
# TEKLIF_KAYDET_GONDER_V1 — teklif formunda redundant 2. adim ("Onaya Gonder") kaldirildi.
#   Ana buton "Kaydet & Onaya Gonder" (tek akista create + gonder); ikincil "Taslak kaydet" korunur.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_teklif_kaydet_gonder_client.py deploy_teklif_kaydet_gonder.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_kaydet_gonder.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_teklif_kaydet_gonder_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_teklif_kaydet_gonder_client.py "$C"

node --check "$C" && echo "[ok] node --check client" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/tkg_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/tkg_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "TEKLIF_KAYDET_GONDER_V1" /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Yeni teklifte ana buton 'Kaydet & Onaya Gönder'; yaninda 'Taslak kaydet'."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
