#!/usr/bin/env bash
# RAPOR_ARALIK_PRESET (mobil + masaustu) — Rapor tarih araligi hazir kisayollari.
#   Mobil:    shells/saha.js         (RAPOR_ARALIK_PRESET_V1)    — rep'ler (her cihaz)
#   Masaustu: shells/saha_desktop.js (RAPOR_ARALIK_PRESET_DK_V1) — yonetim, BI Saha sekmesi
#   Rolling: 7g/30g/3ay/6ay/9ay/12ay · Takvim: Bu ay / Geçen ay / Bu yıl (=YTD). Server degismez.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_rapor_aralik_preset.py patch_rapor_aralik_dk.py deploy_rapor_aralik_all.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_aralik_all.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js; D=shells/saha_desktop.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f "$D" ] || { echo "HATA: $D yok"; exit 1; }
[ -f patch_rapor_aralik_preset.py ] || { echo "HATA: mobil patch yok (scp?)"; exit 1; }
[ -f patch_rapor_aralik_dk.py ] || { echo "HATA: desktop patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; cp -a "$D" "$D.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_rapor_aralik_preset.py "$C"
python3 patch_rapor_aralik_dk.py "$D"

geri_al() { cp -a "$C.bak.$TS" "$C"; cp -a "$D.bak.$TS" "$D"; }

# saha.js duz kontrol; saha_desktop.js ES-modul (export) -> .mjs kopyada kontrol
node --check "$C" && echo "[ok] node --check mobil" || { echo "HATA mobil"; geri_al; exit 1; }
cp -a "$D" /tmp/_dkchk.mjs
node --check /tmp/_dkchk.mjs && echo "[ok] node --check masaustu (.mjs)" || { echo "HATA masaustu"; geri_al; exit 1; }

docker build -t krb-assessment:secure . >/tmp/rapar_all_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rapar_all_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] mobil marker: ";    docker exec "$CID" grep -c "RAPOR_ARALIK_PRESET_V1" /app/shells/saha.js
echo -n "[dogrula] masaustu marker: "; docker exec "$CID" grep -c "RAPOR_ARALIK_PRESET_DK_V1" /app/shells/saha_desktop.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. Hard refresh. Raporlar tarih kutularinin ustunde iki satir: 7g/30g/3ay/6ay/9ay/12ay + Bu ay / Geçen ay / Bu yıl. Hem mobil (rep) hem masaustu (yonetim Saha sekmesi)."
echo "GERI ALMA: cp -a $C.bak.$TS $C && cp -a $D.bak.$TS $D && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
