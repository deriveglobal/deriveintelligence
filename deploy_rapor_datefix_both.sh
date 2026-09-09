#!/usr/bin/env bash
# RAPOR tarih seçici — masaüstü & mobil TUTARLI:
#   Masaüstü: off-by-one düzeltme + varsayılan bugün-29..bugün (RAPOR_DATEFIX_DK_V1).
#   Mobil: son 30 gün varsayılan + aktif preset vurgusu (RAPOR_DEF30_V1) + Ciro UI6 (idempotent, önce kaçırıldıysa).
#   Tek build. Hepsi idempotent + hata olursa geri alır.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_rapor_datefix_both.sh patch_rapor_datefix_desktop.py patch_rapor_def30_mobile.py patch_ciro_ui6_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_datefix_both.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
MOB=shells/saha.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
for p in patch_rapor_datefix_desktop.py patch_rapor_def30_mobile.py patch_ciro_ui6_mobile.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
grep -q RAPOR_DEF30_DK_V1 "$DSK" || { echo "HATA: masaüstü RAPOR_DEF30_DK yok"; exit 1; }
TS=$(date +%s)
cp -a "$DSK" "$DSK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$DSK.bak.$TS" "$DSK"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_rapor_datefix_desktop.py "$DSK" || { rollback; exit 1; }
python3 patch_ciro_ui6_mobile.py "$MOB"       || { rollback; exit 1; }
python3 patch_rapor_def30_mobile.py "$MOB"    || { rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaüstü node"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA mobil node"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/datefix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/datefix_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] DATEFIX(masaüstü): "; docker exec "$CID" grep -c RAPOR_DATEFIX_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] DEF30(mobil): ";       docker exec "$CID" grep -c RAPOR_DEF30_V1 /app/shells/saha.js || true
echo -n "[dogrula] CIRO_UI6(mobil): ";     docker exec "$CID" grep -c CIRO_UI6_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Tarih seçici masaüstü & mobil tutarlı (son 30 gün + vurgu). Hard-refresh / uygulamayı yeniden aç."
