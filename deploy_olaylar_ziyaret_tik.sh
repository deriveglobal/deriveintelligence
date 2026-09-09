#!/usr/bin/env bash
# MUSTERI_OLAYLAR_ZIYARET_TIK_V1 (client-only) — Musteri Karti "Hareketler"de ziyaret satiri
#   tiklanabilir: kartin ustunde katman acilir (tarih/temsilci/konum/katilimcilar + tam not +
#   FOTOGRAFLAR) + "Ziyaret detayini ac" (tam ziyaretDetayModal). Kart yerinde kalir.
#   Onkosul: server MUSTERI_OLAYLAR_ZIYARET_FIX_V1 (o.zid) CANLI + client V1/V2 CANLI.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_olaylar_ziyaret_tik_client.py deploy_olaylar_ziyaret_tik.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_olaylar_ziyaret_tik.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_olaylar_ziyaret_tik_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_olaylar_ziyaret_tik_client.py "$C"

node --check "$C" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/ztik_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ztik_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "MUSTERI_OLAYLAR_ZIYARET_TIK_V1" /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Musteri karti → Hareketler → bir ziyaret satirina (›) dokun → ustte onizleme+foto acilir; kart yerinde kalir."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
