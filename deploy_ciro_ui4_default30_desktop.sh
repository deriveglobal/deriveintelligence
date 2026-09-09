#!/usr/bin/env bash
# CIRO_UI4 + RAPOR_DEF30 (masaüstü):
#   1) "ERP kapsamı" barı DOĞRU metriğe: eslesen/benzersiz (0-100, %100'ü aşmaz).
#   2) Rapor tarih varsayılanı = son 30 gün ("30 gün" preset açılışta seçili).
#   Önce CIRO_UI3_DK deploy edilmiş olmalı.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ciro_ui4_default30_desktop.sh patch_ciro_ui4_desktop.py patch_rapor_default30_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ciro_ui4_default30_desktop.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
for p in patch_ciro_ui4_desktop.py patch_rapor_default30_desktop.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
grep -q CIRO_UI3_DK_V1 "$DSK" || { echo "HATA: once CIRO_UI3_DK deploy edilmeli"; exit 1; }
TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
python3 patch_ciro_ui4_desktop.py "$DSK"
python3 patch_rapor_default30_desktop.py "$DSK"
node --check "$DSK" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
cp "$DSK" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/c4_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/c4_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] CIRO_UI4: "; docker exec "$CID" grep -c CIRO_UI4_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] DEF30: ";    docker exec "$CID" grep -c RAPOR_DEF30_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Kapsam metriği düzeltildi + varsayılan son 30 gün. Hard-refresh → Rapor › Ciro."
