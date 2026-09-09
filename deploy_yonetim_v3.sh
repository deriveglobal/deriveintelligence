#!/usr/bin/env bash
# EKIP_YONETIM_V3 — Yönetim konsolu (premium redesign + layout fix) + saha shell'lerinden
#   Ekip tab kaldirma. Tek build. Tenant-admin FULL dosya degisimi; saha'lar in-place patch.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY shells/tenant-admin.js $H:/opt/krb-assessment/tenant-admin.new.js
#   scp -i $KEY deploy_yonetim_v3.sh patch_ekip_tab_kaldir_desktop.py patch_ekip_tab_kaldir_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yonetim_v3.sh'
set -euo pipefail
cd /opt/krb-assessment
NEW=tenant-admin.new.js
TA=shells/tenant-admin.js
DSK=shells/saha_desktop.js
MOB=shells/saha.js
for f in "$NEW" "$DSK" "$MOB" patch_ekip_tab_kaldir_desktop.py patch_ekip_tab_kaldir_mobile.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
TS=$(date +%s)

# 1) Yönetim konsolu — tam dosya degisimi
node --check "$NEW" || { echo "HATA: node --check (yeni tenant-admin)"; exit 1; }
grep -q "EKIP_YONETIM_V3" "$NEW" || { echo "HATA: yeni tenant-admin markersiz"; exit 1; }
cp -a "$TA" "$TA.bak.$TS"; echo "[yedek] $TA.bak.$TS"
cp -a "$NEW" "$TA"
node --check "$TA" || { echo "geri al"; cp -a "$TA.bak.$TS" "$TA"; exit 1; }
echo "[ok] $TA"

# 2) Saha shell'lerden Ekip tab kaldir (idempotent)
patch_one () {  # $1=dosya  $2=patch
  if grep -q "EKIP_TAB_KALDIR_V1" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi
  cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"
  python3 "$2" "$1"
  node --check "$1" || { echo "geri al $1"; cp -a "$1.bak.$TS" "$1"; exit 1; }
  echo "[ok] $1"
}
patch_one "$DSK" patch_ekip_tab_kaldir_desktop.py
patch_one "$MOB" patch_ekip_tab_kaldir_mobile.py

# 3) Tek build + recreate
docker build -t krb-assessment:secure . >/tmp/yonv3_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -30 /tmp/yonv3_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] yonetim v3: "; docker exec "$CID" grep -c EKIP_YONETIM_V3 /app/shells/tenant-admin.js || true
echo -n "[dogrula] masaustu ekip-tab kaldir: "; docker exec "$CID" grep -c EKIP_TAB_KALDIR_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil ekip-tab kaldir: "; docker exec "$CID" grep -c EKIP_TAB_KALDIR_V1 /app/shells/saha.js || true
rm -f "$NEW"
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Yönetim v3 canli · saha'larda Ekip tab kaldirildi. (Yönetim > İzinler tek erisim yeri)"
