#!/usr/bin/env bash
# YAYIM_OKUYAN — Hızlı Duyuru modalinde "kim gördü (saatiyle) / kim görmedi".
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_yayim_okuyan.sh patch_yayim_okuyan_server.py patch_yayim_okuyan_mobile.py patch_yayim_okuyan_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yayim_okuyan.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; MOB=shells/saha.js; DSK=shells/saha_desktop.js
for f in "$SRV" "$MOB" "$DSK" patch_yayim_okuyan_server.py patch_yayim_okuyan_mobile.py patch_yayim_okuyan_desktop.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
pat () { if grep -q "$3" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi; TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"; python3 "$2" "$1"; node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }; }
pat "$SRV" patch_yayim_okuyan_server.py  YAYIM_OKUYAN_V1
pat "$MOB" patch_yayim_okuyan_mobile.py  YAYIM_OKUYAN_V1
pat "$DSK" patch_yayim_okuyan_desktop.py YAYIM_OKUYAN_DK_V1
docker build -t krb-assessment:secure . >/tmp/yokuyan_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/yokuyan_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server: "; docker exec "$CID" grep -c YAYIM_OKUYAN_V1 /app/server.mjs || true
echo -n "[dogrula] mobil: ";  docker exec "$CID" grep -c YAYIM_OKUYAN_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaustu: "; docker exec "$CID" grep -c YAYIM_OKUYAN_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Hızlı Duyuru ac -> kim gördü (saatiyle) + kim görmedi listesi."
