#!/usr/bin/env bash
# BUGUN_INBOX — Bugun ekrani "okunmamis gelen-kutusu" + mobil katlanabilir bolumler.
#   Desktop: BUGUN_INBOX_V1 (gorulen ziyaret Bugun'den dusr; Ziyaretler'de kalir).
#   Mobil:   BUGUN_KATLA_V1 (katlanabilir bolumler) + BUGUN_INBOX_V1 (yoneticide dusr).
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_bugun_inbox.sh patch_bugun_inbox_desktop.py patch_bugun_mobil_inbox_katla.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_bugun_inbox.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
MOB=shells/saha.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_bugun_inbox_desktop.py ] || { echo "HATA: desktop patch yok (scp?)"; exit 1; }
[ -f patch_bugun_mobil_inbox_katla.py ] || { echo "HATA: mobil patch yok (scp?)"; exit 1; }

if grep -q 'BUGUN_INBOX_V1' "$DSK"; then
  echo "[bilgi] $DSK zaten yamali"
else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_bugun_inbox_desktop.py "$DSK"
  node --check "$DSK" && echo "[ok] node --check $DSK" || { echo "HATA node $DSK; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi

if grep -q 'BUGUN_KATLA_V1' "$MOB"; then
  echo "[bilgi] $MOB zaten yamali"
else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_bugun_mobil_inbox_katla.py "$MOB"
  node --check "$MOB" && echo "[ok] node --check $MOB" || { echo "HATA node $MOB; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi

docker build -t krb-assessment:secure . >/tmp/buguninbox_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/buguninbox_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] desktop BUGUN_INBOX_V1: "; docker exec "$CID" grep -c BUGUN_INBOX_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil BUGUN_KATLA_V1: ";  docker exec "$CID" grep -c BUGUN_KATLA_V1 /app/shells/saha.js || true
echo -n "[dogrula] mobil BUGUN_INBOX_V1: ";  docker exec "$CID" grep -c BUGUN_INBOX_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Hard-refresh -> Bugun'de gorulen ziyaret listeden dusr (Ziyaretler'de kalir); mobilde bolumler katlanabilir."
