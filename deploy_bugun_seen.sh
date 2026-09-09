#!/usr/bin/env bash
# BUGUN_ZIYARET_SEEN — iki parca:
#   1) BUGUN_ZIYARET_GORDUM_V1 (server): /api/saha/bugun her ziyaret icin gordum boolean doner.
#   2) BUGUN_ZIYARET_SEEN_V1 (desktop): gorulmemis ziyarete "● Yeni" rozeti; acinca temizlenir.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_bugun_seen.sh patch_bugun_gordum_server.py patch_bugun_seen_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_bugun_seen.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
DSK=shells/saha_desktop.js
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f patch_bugun_gordum_server.py ] || { echo "HATA: server patch yok (scp?)"; exit 1; }
[ -f patch_bugun_seen_desktop.py ] || { echo "HATA: desktop patch yok (scp?)"; exit 1; }

if grep -q 'BUGUN_ZIYARET_GORDUM_V1' "$SRV"; then
  echo "[bilgi] $SRV zaten yamali"
else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_bugun_gordum_server.py "$SRV"
  node --check "$SRV" && echo "[ok] node --check $SRV" || { echo "HATA node $SRV; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi

if grep -q 'BUGUN_ZIYARET_SEEN_V1' "$DSK"; then
  echo "[bilgi] $DSK zaten yamali"
else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_bugun_seen_desktop.py "$DSK"
  node --check "$DSK" && echo "[ok] node --check $DSK" || { echo "HATA node $DSK; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi

docker build -t krb-assessment:secure . >/tmp/bugunseen_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/bugunseen_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c BUGUN_ZIYARET_GORDUM_V1 /app/server.mjs || true
echo -n "[dogrula] desktop marker: "; docker exec "$CID" grep -c BUGUN_ZIYARET_SEEN_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Hard-refresh -> Bugun'de gorulmemis ziyaretler '● Yeni' rozetli; acinca rozet gider, zil bildirimi de dusr."
