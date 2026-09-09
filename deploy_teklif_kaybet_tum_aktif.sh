#!/usr/bin/env bash
# TEKLIF_KAYBET_TUM_AKTIF_V1 (client-only) — Teklif detayinda "✕ Kaybettik / ✓ Kazandik" artik
#   TASLAK, ONAY_BEKLIYOR, ONAYLANDI, SUNULDU tekliflerin HEPSINDE gorunur (sunucu action:sonuc
#   zaten hepsine izin veriyordu). Ali Kemal 04.08: "rakipte kaldi secemiyorum".
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_teklif_kaybet_tum_aktif_client.py deploy_teklif_kaybet_tum_aktif.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_kaybet_tum_aktif.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_teklif_kaybet_tum_aktif_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_teklif_kaybet_tum_aktif_client.py "$C"

node --check "$C" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/tkaybet_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/tkaybet_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "TEKLIF_KAYBET_TUM_AKTIF_V1" /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Herhangi bir teklifi (TASLAK dahil) ac → '✕ Kaybettik' gorunmeli → rakip marka/fiyat gir."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
