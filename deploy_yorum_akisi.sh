#!/usr/bin/env bash
# YORUM_AKISI_V1 — Bugun ekranina "🗨️ Yorumlar" karti (rol-bazli akis + okunmamis rozeti).
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_yorum_akisi_server.py patch_yorum_akisi_client.py deploy_yorum_akisi.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yorum_akisi.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs; C=shells/saha.js
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_yorum_akisi_server.py ] || { echo "HATA: server patch yok (scp?)"; exit 1; }
[ -f patch_yorum_akisi_client.py ] || { echo "HATA: client patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; cp -a "$C" "$C.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_yorum_akisi_server.py "$S"
python3 patch_yorum_akisi_client.py "$C"

geri_al() { cp -a "$S.bak.$TS" "$S"; cp -a "$C.bak.$TS" "$C"; }
node --check "$S" && echo "[ok] node --check server" || { echo "HATA server"; geri_al; exit 1; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA client"; geri_al; exit 1; }

docker build -t krb-assessment:secure . >/tmp/yakis_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/yakis_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c "YORUM_AKISI_V1" /app/server.mjs 2>/dev/null || docker exec "$CID" grep -c "YORUM_AKISI_V1" /app/server_container.mjs
echo -n "[dogrula] client marker: "; docker exec "$CID" grep -c "YORUM_AKISI_V1" /app/shells/saha.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. iOS relaunch / hard refresh. Bugün ekranında Mesajlar altında '🗨️ Yorumlar' kartı; dokun → yorum akışı; satıra dokun → ziyaret açılır."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
