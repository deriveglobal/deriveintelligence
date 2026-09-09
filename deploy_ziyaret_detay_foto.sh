#!/usr/bin/env bash
# ZIYARET_DETAY_FOTO_V1 — tekil ziyaret ucuna foto_sayisi eklendi; ziyaret detayinda fotolar
#   artik yukleniyor (mobil dahil). Hata: yuklenen fotolar mobilde gorunmuyordu.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_ziyaret_detay_foto_server.py deploy_ziyaret_detay_foto.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_detay_foto.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_ziyaret_detay_foto_server.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"

python3 patch_ziyaret_detay_foto_server.py "$S"

node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$S.bak.$TS" "$S"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/zdfoto_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/zdfoto_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "ZIYARET_DETAY_FOTO_V1" /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c "ZIYARET_DETAY_FOTO_V1" /app/server.mjs
echo -n "[dogrula] tekil ziyaret foto_sayisi donuyor mu (bir ziyaret id ile test edilebilir): "; echo "(app icinde ziyaret detay ac)"

echo "[bitti] CANLI. iOS relaunch / hard refresh. Fotolu bir ziyaretin detayini ac → fotograflar gorunmeli."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
