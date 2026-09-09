#!/usr/bin/env bash
# HATA_YONETIM_V1 — Uygulama ici HATA EKRANI'ni yonetim@krb.com.tr'ye acar (kod/terminal gerekmez).
#   server: /api/saha/hata-raporu gate -> platform_owner VEYA yonetim@krb.com.tr
#   mobil (saha.js): "Sistem" (🔧) sekmesi + vSistem yonetim'e acildi -> hata ozeti/endpoint/kullanici/son hatalar
#   masaustu (saha_desktop.js): "Yönetim > Sistem" nav + VIEWS.sistem hata raporu
# KULLANIM:
#   scp -i $KEY patch_hata_yonetim_server.py patch_hata_yonetim_saha.py patch_hata_yonetim_desktop.py deploy_hata_yonetim.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_hata_yonetim.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
SAHA=shells/saha.js
DESK=shells/saha_desktop.js
for f in "$SRV" "$SAHA" "$DESK" patch_hata_yonetim_server.py patch_hata_yonetim_saha.py patch_hata_yonetim_desktop.py; do
  [ -f "$f" ] || { echo "HATA: $f yok (scp?)"; exit 1; }
done
grep -q '/api/saha/hata-raporu' "$SRV" || { echo "HATA: $SRV hata-raporu icermiyor"; exit 1; }
grep -q 'REP_AKTIVITE_HB' "$SAHA" || { echo "HATA: $SAHA canli servis edilen dosya degil (HB yok)"; exit 1; }
grep -q 'isYonetim' "$SAHA" || { echo "HATA: $SAHA isYonetim yok — once REP_AKTIVITE_UI deploy edilmeli"; exit 1; }
grep -q 'isYonetim' "$DESK" || { echo "HATA: $DESK isYonetim yok — once REP_AKTIVITE_UI deploy edilmeli"; exit 1; }

TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$SAHA" "$SAHA.bak.$TS"; cp -a "$DESK" "$DESK.bak.$TS"; echo "[yedek] .bak.$TS x3"
rollback(){ echo ">>> GERI AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$SAHA.bak.$TS" "$SAHA"; cp -a "$DESK.bak.$TS" "$DESK"; }
python3 patch_hata_yonetim_server.py  "$SRV"  || { rollback; exit 1; }
python3 patch_hata_yonetim_saha.py    "$SAHA" || { rollback; exit 1; }
python3 patch_hata_yonetim_desktop.py "$DESK" || { rollback; exit 1; }
node --check "$SRV" && node --check "$SAHA" && node --check "$DESK" && echo "[ok] node --check x3" || { rollback; exit 1; }
docker build -t krb-assessment:secure . >/tmp/hatayon_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/hatayon_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c HATA_YONETIM_V1 /app/server.mjs
echo -n "[dogrula] mobil marker:  "; docker exec "$CID" grep -c HATA_YONETIM_V1 /app/shells/saha.js
echo -n "[dogrula] masaustu marker:"; docker exec "$CID" grep -c HATA_YONETIM_V1 /app/shells/saha_desktop.js
echo "[BITTI] yonetim@krb.com.tr ile gir + Cmd+Shift+R. Mobil: 'Daha > Sistem'. Masaustu: 'Yönetim > Sistem'. Hatalar orada."
