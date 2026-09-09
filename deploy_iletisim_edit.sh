#!/usr/bin/env bash
# ILETISIM_EDIT_V1 — musteri detayinda Yetkili + Telefon artik DUZENLENEBILIR (mobil saha).
#   Salt-okunur satirlar -> input + Kaydet -> PUT /api/saha/musteriler/:id {yetkili,telefon}.
#   Sunucu ucu (PUT) zaten yetkili+telefon kabul ediyor; sadece UI ekliyoruz. In-place patch.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_iletisim_edit.sh patch_iletisim_edit_saha.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_iletisim_edit.sh'
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_iletisim_edit_saha.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'initSahaSurface' "$F" || { echo "HATA: $F mobil saha kabugu degil — DUR."; exit 1; }
grep -q 'md-vkn-kaydet' "$F" || { echo "HATA: $F musteri detay VKN blogu yok — DUR."; exit 1; }
if grep -q 'ILETISIM_EDIT_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_iletisim_edit_saha.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/ilet_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ilet_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/shells/saha.js (2 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c ILETISIM_EDIT_V1 /app/shells/saha.js || true
echo "[BITTI] Mobil -> Musteri -> (bir musteri) -> Yetkili/Telefon duzenle + Kaydet. Cmd+Shift+R."
