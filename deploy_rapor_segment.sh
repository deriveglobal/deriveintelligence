#!/usr/bin/env bash
# RAPOR_SEGMENT — B2: Temsilci Performansi'na Segment rozeti (Tüketici/Ticari/Karma).
#   Kaynak: yonetici atadiysa permissions_json.saha_tip (dolu rozet);
#           yoksa donem ziyaretlerinin m.tip cogunlugundan turetilir (~ isaretli).
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_rapor_segment.sh patch_rapor_segment_server.py patch_rapor_segment_mobile.py patch_rapor_segment_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_segment.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; MOB=shells/saha.js; DSK=shells/saha_desktop.js
for f in "$SRV" "$MOB" "$DSK" patch_rapor_segment_server.py patch_rapor_segment_mobile.py patch_rapor_segment_desktop.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
pat () { # $1=dosya $2=patch $3=marker
  if grep -q "$3" "$1"; then echo "[bilgi] $1 zaten yamali ($3)"; return; fi
  TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"
  python3 "$2" "$1"
  node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }
  case "$1" in *.js) cp "$1" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm $1" || { echo "HATA esm $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; };; esac
}
pat "$SRV" patch_rapor_segment_server.py  RAPOR_SEGMENT_V1
pat "$MOB" patch_rapor_segment_mobile.py  RAPOR_SEGMENT_V1
pat "$DSK" patch_rapor_segment_desktop.py RAPOR_SEGMENT_DK_V1
docker build -t krb-assessment:secure . >/tmp/rseg_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rseg_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server: ";   docker exec "$CID" grep -c RAPOR_SEGMENT_V1 /app/server.mjs || true
echo -n "[dogrula] mobil: ";    docker exec "$CID" grep -c RAPOR_SEGMENT_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaustu: "; docker exec "$CID" grep -c RAPOR_SEGMENT_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Rapor > Temsilciler'de Segment rozeti (yonetici atamasi > ziyaret cogunlugu)."
