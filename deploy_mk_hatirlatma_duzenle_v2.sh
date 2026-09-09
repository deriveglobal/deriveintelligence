#!/usr/bin/env bash
# MUSTERI_HATIRLATMA_DUZENLE_V2 — DUZELTME (client-only): hatirlatma duzenleme modali artik
#   Musteri Kartini EZMIYOR. V1'de modal() konteyneri eziyordu → kart kayboluyordu. V2 katmanli
#   overlay (kart altta kalir, kapaninca yalniz overlay gider). Onkosul: V1 client CANLI.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_mk_hatirlatma_duzenle_v2_client.py deploy_mk_hatirlatma_duzenle_v2.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_mk_hatirlatma_duzenle_v2.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_mk_hatirlatma_duzenle_v2_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_mk_hatirlatma_duzenle_v2_client.py "$C"

node --check "$C" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/mkhat2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/mkhat2_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] V2 marker: "; docker exec "$CID" grep -c "MUSTERI_HATIRLATMA_DUZENLE_V2" /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Musteri karti → Hareketler'de bir satira dokun → duzenleme USTTE acilir, Vazgec/Kaydet sonrasi KART yerinde kalir."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
