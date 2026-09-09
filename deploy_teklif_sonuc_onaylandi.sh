#!/usr/bin/env bash
# TEKLIF_SONUC_ONAYLANDI_V1 — "✕ Kaybettik / ✓ Kazandik" butonlari artik ONAYLANDI tekliflerde de
#   gorunur (yalniz SUNULDU degil). Verilen teklif "rakipte kaldi" olarak rakip fiyat/bilgi ile
#   isaretlenip kayip satis olarak saklanabilir. Ozellik: Ali Kemal Picakci 03.08.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_teklif_sonuc_onaylandi_client.py deploy_teklif_sonuc_onaylandi.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_sonuc_onaylandi.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_teklif_sonuc_onaylandi_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_teklif_sonuc_onaylandi_client.py "$C"

node --check "$C" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/tsonuc_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/tsonuc_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "TEKLIF_SONUC_ONAYLANDI_V1" /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Onaylanmis bir teklifi ac → '✕ Kaybettik' ile rakip fiyat/bilgi gir → kayip satis olarak saklanir + rakip raporuna gider."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
