#!/usr/bin/env bash
# TEKLIF_REVIZE_V1 — "Yeni surum / Rev." : verilen teklif revize edilemiyor (Huseyin Bilgi).
#   Orijinal teklif DEGISMEZ; kalemleriyle birlikte yeni TASLAK kopya acilir (kok_teklif_id + revizyon_no).
#   Revize edilebilir durumlar: ONAY_BEKLIYOR, ONAYLANDI, SUNULDU, KAYBEDILDI.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_teklif_revize_server.py patch_teklif_revize_client.py deploy_teklif_revize.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_revize.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
C=shells/saha.js
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_teklif_revize_server.py ] || { echo "HATA: server patch yok (scp?)"; exit 1; }
[ -f patch_teklif_revize_client.py ] || { echo "HATA: client patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_teklif_revize_server.py "$S"
python3 patch_teklif_revize_client.py "$C"

node --check "$S" && echo "[ok] node --check server" || { echo "HATA: server node --check"; cp -a "$S.bak.$TS" "$S"; cp -a "$C.bak.$TS" "$C"; exit 1; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA: client node --check"; cp -a "$S.bak.$TS" "$S"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/trevize_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/trevize_build.log; cp -a "$S.bak.$TS" "$S"; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c TEKLIF_REVIZE_V1 /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c TEKLIF_REVIZE_V1 /app/server.mjs
echo -n "[dogrula] client marker: "; docker exec "$CID" grep -c "td-revize" /app/shells/saha.js
echo -n "[dogrula] kolon: "; docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "SELECT count(*) FROM information_schema.columns WHERE table_name='saha_teklif' AND column_name IN ('kok_teklif_id','revizyon_no')" 2>/dev/null || echo "(psql env yoksa elle bak)"

echo "[bitti] Teklif Revize CANLI. iOS relaunch / hard refresh. Teklif detayinda '🔄 Revize et' butonu."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
