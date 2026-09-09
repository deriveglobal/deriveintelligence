#!/usr/bin/env bash
# Ali Kemal ziyaret girisi — 3 fix (yalniz client, shells/saha.js):
#   ZIYARET_FOTO_KAMERA_V1  — foto: 📷 Çek (kamera) + 🖼 Galeri (multiple) iki ayri buton.
#   TASLAK_ANA_EKRAN_V1     — Bugun ekraninda "💾 Taslak aktivite" bolumu; dokun→otomatik geri-yukleyerek forma gir.
#   TEXTAREA_SCROLL_V2      — textarea odak/yazimda scrollIntoView nearest→center + 300ms (klavye altini kurtar).
# KULLANIM (Mac'ten):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_foto_scroll_client.py patch_taslak_ana_ekran_client.py deploy_ziyaret_girisi.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_girisi.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_foto_scroll_client.py ] || { echo "HATA: foto/scroll patch yok (scp?)"; exit 1; }
[ -f patch_taslak_ana_ekran_client.py ] || { echo "HATA: taslak patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_foto_scroll_client.py "$C"
python3 patch_taslak_ana_ekran_client.py "$C"

geri_al() { cp -a "$C.bak.$TS" "$C"; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA client"; geri_al; exit 1; }

docker build -t krb-assessment:secure . >/tmp/zgiris_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/zgiris_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] foto marker: ";   docker exec "$CID" grep -c "ZIYARET_FOTO_KAMERA_V1" /app/shells/saha.js
echo -n "[dogrula] taslak marker: "; docker exec "$CID" grep -c "TASLAK_ANA_EKRAN_V1" /app/shells/saha.js
echo -n "[dogrula] scroll marker: "; docker exec "$CID" grep -c "TEXTAREA_SCROLL_V2" /app/shells/saha.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. iOS relaunch / hard refresh. Ziyaret formunda foto: 📷 Çek + 🖼 Galeri; Bugün'de '💾 Taslak aktivite' (dokun→devam); textarea odakta ortalanir."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
