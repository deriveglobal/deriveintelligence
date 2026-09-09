#!/usr/bin/env bash
# MSG_TIK — Batch 2b: okundu tiki (server karsi_okundu_at + mobil/masaustu "✓✓ Görüldü").
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_msg_tik.sh patch_msg_tik_server.py patch_msg_tik_mobile.py patch_msg_tik_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_msg_tik.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; MOB=shells/saha.js; DSK=shells/saha_desktop.js
for f in "$SRV" "$MOB" "$DSK" patch_msg_tik_server.py patch_msg_tik_mobile.py patch_msg_tik_desktop.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done

pat () {  # $1=dosya $2=patch $3=marker
  if grep -q "$3" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi
  TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"
  python3 "$2" "$1"
  node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }
}
pat "$SRV" patch_msg_tik_server.py  MESAJ_TIK_V1
pat "$MOB" patch_msg_tik_mobile.py  MSG_TIK_V1
pat "$DSK" patch_msg_tik_desktop.py MSG_TIK_DK_V1

docker build -t krb-assessment:secure . >/tmp/msgtik_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/msgtik_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server MESAJ_TIK_V1: ";   docker exec "$CID" grep -c MESAJ_TIK_V1 /app/server.mjs || true
echo -n "[dogrula] mobil MSG_TIK_V1: ";       docker exec "$CID" grep -c MSG_TIK_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaustu MSG_TIK_DK_V1: "; docker exec "$CID" grep -c MSG_TIK_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Thread'de gonderdigin son mesajda ✓✓ Görüldü / ✓ Gönderildi gorunur."
