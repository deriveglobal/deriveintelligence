#!/usr/bin/env bash
# YENI_ZIYARET_DESKTOP_V1 — masaustu saha modulune "+ Yeni Ziyaret" olustur akisi ekler.
#   Musteri sec (musteriSec) -> tarih/katilimci/not formu -> POST /api/saha/ziyaretler (tamamla).
#   In-place patch: canli shells/saha_desktop.js'i yamalar; yeni eklenen ekranlar (rep-aktivite,
#   sistem) korunur. node --check auto-rollback + .bak yedek.
# KULLANIM (Mac Terminal):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_yeni_ziyaret_desktop.sh patch_yeni_ziyaret_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yeni_ziyaret_desktop.sh'
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha_desktop.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_yeni_ziyaret_desktop.py ] || { echo "HATA: patch_yeni_ziyaret_desktop.py yok (scp?)"; exit 1; }
grep -q 'VIEWS.ziyaretler' "$F" || { echo "HATA: $F desktop saha kabugu degil — DUR."; exit 1; }
grep -q 'function musteriSec' "$F" || { echo "HATA: $F musteriSec yok — DUR."; exit 1; }
if grep -q 'YENI_ZIYARET_DESKTOP_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_yeni_ziyaret_desktop.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/yzd_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/yzd_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/shells/saha_desktop.js (2 satir bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c YENI_ZIYARET_DESKTOP_V1 /app/shells/saha_desktop.js || true
echo "[BITTI] Masaustu -> Saha -> Ziyaretler -> '+ Yeni Ziyaret'. Cmd+Shift+R sart."
