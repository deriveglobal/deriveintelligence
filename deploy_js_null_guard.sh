#!/usr/bin/env bash
# JS_NULL_GUARD_V1 — "Cannot read properties of null (reading 'addEventListener')" crash sinifini kapatir.
# Kok neden: view innerHTML render + await(veri) sonrasi listener baglaniyor; rep await sirasinda baska
# ekrana gecerse element null -> crash. Fix: querySelector/getElementById(...).addEventListener -> ?. (72 yer).
# Sadece shells/saha.js; native/rebuild YOK (web). KULLANIM:
#   scp -i $KEY patch_js_null_guard.py deploy_js_null_guard.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_js_null_guard.sh'
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_js_null_guard.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'initSahaSurface' "$F" || { echo "HATA: $F saha mobil kabugu degil"; exit 1; }
grep -q 'REP_AKTIVITE_HB' "$F" || { echo "HATA: $F canli servis edilen dosya degil (HB yok) — DUR."; exit 1; }
if grep -q 'JS_NULL_GUARD_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_js_null_guard.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node; geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/jsguard_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/jsguard_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/shells/saha.js (1 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c JS_NULL_GUARD_V1 /app/shells/saha.js
echo -n "[dogrula] kalan unguarded querySelector(...).addEventListener (0 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" sh -c "grep -cE 'querySelector\([^)]*\)\.addEventListener' /app/shells/saha.js || true"
echo "[BITTI] rep-brain / ziyaretler addEventListener-null crash'i biter. Cmd+Shift+R / uygulamayi yeniden ac."
