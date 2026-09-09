#!/usr/bin/env bash
# ZIYARET_PIN_MUSTERI_V1 (server) + ZIYARET_KONUM_GOSTER_V1 + ONERI_TEXTAREA_AUTOGROW_V1 (client)
#   Ali Kemal 2 hata (DÜZELTİLMİŞ teşhis, veriyle kanıtlı 305 checkin / 2 musteri-pin):
#   - "Bu konumu musteri adresine kaydet" artik ISLENIYOR (checkin action pin_musteri -> saha_musteri.lat/lng).
#   - Ziyaret detayinda "Pinlenen konum → Haritada ac" (pin gorunur).
#   - Oneri kutusu textarea yazdikca buyur (autogrow).
#   ⚠ ESKI deploy_konum_oneri.sh'i KULLANMA (yanlis oncullu INSERT yamasi).
# KULLANIM (Mac'ten):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_pin_musteri_server.py patch_konum_goster_oneri_client.py deploy_pin_musteri.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_pin_musteri.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs; C=shells/saha.js
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_pin_musteri_server.py ] || { echo "HATA: server patch yok (scp?)"; exit 1; }
[ -f patch_konum_goster_oneri_client.py ] || { echo "HATA: client patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; cp -a "$C" "$C.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_pin_musteri_server.py "$S"
python3 patch_konum_goster_oneri_client.py "$C"

geri_al() { cp -a "$S.bak.$TS" "$S"; cp -a "$C.bak.$TS" "$C"; }
node --check "$S" && echo "[ok] node --check server" || { echo "HATA server"; geri_al; exit 1; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA client"; geri_al; exit 1; }

docker build -t krb-assessment:secure . >/tmp/pinm_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/pinm_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c "ZIYARET_PIN_MUSTERI_V1" /app/server.mjs 2>/dev/null || docker exec "$CID" grep -c "ZIYARET_PIN_MUSTERI_V1" /app/server_container.mjs
echo -n "[dogrula] client goster: "; docker exec "$CID" grep -c "ZIYARET_KONUM_GOSTER_V1" /app/shells/saha.js
echo -n "[dogrula] client autogrow: "; docker exec "$CID" grep -c "ONERI_TEXTAREA_AUTOGROW_V1" /app/shells/saha.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. iOS relaunch / hard refresh. Check-in'de 'müşteri adresine kaydet' işaretliyse müşteri pini artık yazılıyor; ziyaret detayında 'Pinlenen konum → Haritada aç'; öneri kutusu yazdıkça büyüyor."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
