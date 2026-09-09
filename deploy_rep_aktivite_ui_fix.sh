#!/usr/bin/env bash
# REP_AKTIVITE_UI_V1 DUZELTME — onceki deploy pick() ile KOKTEKI stale ./saha.js'i yamaladi
# (servis edilmiyor). Bu script DOGRU dosyayi (shells/saha.js) yamalar. Server + desktop zaten canli.
# patch_rep_aktivite_ui.py zaten hostta (onceki scp). KULLANIM:
#   scp -i $KEY deploy_rep_aktivite_ui_fix.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rep_aktivite_ui_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_rep_aktivite_ui.py ] || { echo "HATA: patch_rep_aktivite_ui.py yok (scp?)"; exit 1; }
grep -q 'initSahaSurface' "$F" || { echo "HATA: $F saha mobil kabugu degil"; exit 1; }
grep -q 'REP_AKTIVITE_HB' "$F" || { echo "HATA: $F canli servis edilen dosya degil (HB markeri yok) — DUR."; exit 1; }
if grep -q 'REP_AKTIVITE_UI_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_rep_aktivite_ui.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node; geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/aktui_fix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/aktui_fix_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] mobil marker /app/shells/saha.js (1 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c REP_AKTIVITE_UI_V1 /app/shells/saha.js
echo "[opsiyonel] Kokteki stale orphan ./saha.js kafa karistiriyor; istersen kaldir: mv ./saha.js ./saha.js.orphan"
echo "[BITTI] yonetim@krb.com.tr ile gir + Cmd+Shift+R → Mobil 'Daha (...) > Aktivite'."
