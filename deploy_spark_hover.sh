#!/usr/bin/env bash
# RAPOR_SPARK_HOVER — Özet sparkline hover (tarih·ziyaret) mobil + masaüstü. Tek build.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_spark_hover.sh patch_spark_hover_mobile.py patch_spark_hover_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_spark_hover.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js; DSK=shells/saha_desktop.js
for f in "$MOB" "$DSK" patch_spark_hover_mobile.py patch_spark_hover_desktop.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
pat () { # $1 dosya $2 patch $3 marker
  if grep -q "$3" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi
  TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"
  python3 "$2" "$1"
  node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }
  cp "$1" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm $1" || { echo "HATA esm $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }
}
pat "$MOB" patch_spark_hover_mobile.py  RAPOR_SPARK_HOVER_V1
pat "$DSK" patch_spark_hover_desktop.py RAPOR_SPARK_HOVER_DK_V1
docker build -t krb-assessment:secure . >/tmp/sh_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/sh_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] mobil: ";    docker exec "$CID" grep -c RAPOR_SPARK_HOVER_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaüstü: "; docker exec "$CID" grep -c RAPOR_SPARK_HOVER_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Sparkline hover canlı — üzerine gel/dokun: gün + ziyaret sayısı."
