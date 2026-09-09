#!/usr/bin/env bash
# MSG_POLISH — Batch 2a: mesaj listesi cilasi (avatar, saatli tarih, soluk bos, arama) mobil+masaustu.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_msg_polish.sh patch_msg_polish_mobile.py patch_msg_polish_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_msg_polish.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
DSK=shells/saha_desktop.js
[ -f "$MOB" ] && [ -f "$DSK" ] || { echo "HATA: shell yok"; exit 1; }
[ -f patch_msg_polish_mobile.py ] || { echo "HATA: mobil patch yok (scp?)"; exit 1; }
[ -f patch_msg_polish_desktop.py ] || { echo "HATA: masaustu patch yok (scp?)"; exit 1; }

if grep -q 'MSG_POLISH_V1' "$MOB"; then echo "[bilgi] $MOB zaten yamali"; else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_msg_polish_mobile.py "$MOB"
  node --check "$MOB" && echo "[ok] node $MOB" || { echo "HATA node $MOB; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
if grep -q 'MSG_POLISH_DK_V1' "$DSK"; then echo "[bilgi] $DSK zaten yamali"; else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_msg_polish_desktop.py "$DSK"
  node --check "$DSK" && echo "[ok] node $DSK" || { echo "HATA node $DSK; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi

docker build -t krb-assessment:secure . >/tmp/msgpolish_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/msgpolish_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] mobil MSG_POLISH_V1: ";    docker exec "$CID" grep -c MSG_POLISH_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaustu MSG_POLISH_DK_V1: "; docker exec "$CID" grep -c MSG_POLISH_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Hard-refresh -> mesaj listesinde avatar + saat + arama; bos konusmalar soluk."
