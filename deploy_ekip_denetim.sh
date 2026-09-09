#!/usr/bin/env bash
# EKIP_DENETIM_TASI — Aktivite + Sistem tab'lerini saha shell'lerinden kaldir
#   (Yönetim konsolunun Denetim bolumune tasindi). Iki shell, tek build.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ekip_denetim.sh patch_ekip_denetim_desktop.py patch_ekip_denetim_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ekip_denetim.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
MOB=shells/saha.js
for f in "$DSK" "$MOB" patch_ekip_denetim_desktop.py patch_ekip_denetim_mobile.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
TS=$(date +%s)
patch_one () {
  if grep -q "EKIP_DENETIM_TASI_V1" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi
  cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"
  python3 "$2" "$1"
  node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }
}
patch_one "$DSK" patch_ekip_denetim_desktop.py
patch_one "$MOB" patch_ekip_denetim_mobile.py

docker build -t krb-assessment:secure . >/tmp/denetim_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -30 /tmp/denetim_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] masaustu: "; docker exec "$CID" grep -c EKIP_DENETIM_TASI_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil: ";    docker exec "$CID" grep -c EKIP_DENETIM_TASI_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Aktivite + Sistem saha'dan kaldirildi -> Yönetim > Denetim."
