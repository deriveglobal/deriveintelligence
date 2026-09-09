#!/usr/bin/env bash
# BAGLAM_MSG — #3c: teklif & ziyaret detayinda "💬 Mesaj" (masaustu) + genel endpoint.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_baglam_msg.sh patch_baglam_msg_server.py patch_baglam_msg_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_baglam_msg.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DSK=shells/saha_desktop.js
for f in "$SRV" "$DSK" patch_baglam_msg_server.py patch_baglam_msg_desktop.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
pat () { if grep -q "$3" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi; TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"; python3 "$2" "$1"; node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }; }
pat "$SRV" patch_baglam_msg_server.py  BAGLAM_MSG_V1
pat "$DSK" patch_baglam_msg_desktop.py BAGLAM_MSG_DK_V1
docker build -t krb-assessment:secure . >/tmp/baglam_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/baglam_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server BAGLAM_MSG_V1: "; docker exec "$CID" grep -c BAGLAM_MSG_V1 /app/server.mjs || true
echo -n "[dogrula] masaustu BAGLAM_MSG_DK_V1: "; docker exec "$CID" grep -c BAGLAM_MSG_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Masaustu teklif & ziyaret detayinda '💬 Mesaj' -> o kaydin rep'ine, 🔗 etiketli."
