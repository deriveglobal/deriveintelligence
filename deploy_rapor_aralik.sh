#!/usr/bin/env bash
# RAPOR_ARALIK_PRESET_V1 — Rapor tarih araligi hazir kisayollari (yalniz client).
#   Rolling: 7G/30G/3A/6A/9A/12A · Takvim: Bu ay / Geçen ay / Bu yıl (=YTD).
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_rapor_aralik_preset.py deploy_rapor_aralik.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_aralik.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_rapor_aralik_preset.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_rapor_aralik_preset.py "$C"

geri_al() { cp -a "$C.bak.$TS" "$C"; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA client"; geri_al; exit 1; }

docker build -t krb-assessment:secure . >/tmp/rapar_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rapar_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] client marker: "; docker exec "$CID" grep -c "RAPOR_ARALIK_PRESET_V1" /app/shells/saha.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. iOS relaunch / hard refresh. Raporlar ekranında tarih kutularının üstünde iki satır kısayol: 7G/30G/3A/6A/9A/12A ve Bu ay / Geçen ay / Bu yıl. Dokun → aralık otomatik dolar, aktif sekme yenilenir."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
