#!/usr/bin/env bash
# YAYIM_CLICK — Hızlı Duyuru satirlarini tiklanabilir yap (tam metin modal) + sizan yorumu temizle.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_yayim_click.sh patch_yayim_click_mobile.py patch_yayim_click_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yayim_click.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js; DSK=shells/saha_desktop.js
for f in "$MOB" "$DSK" patch_yayim_click_mobile.py patch_yayim_click_desktop.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
pat () { if grep -q "$3" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi; TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"; python3 "$2" "$1"; node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }; }
pat "$MOB" patch_yayim_click_mobile.py  YAYIM_CLICK_V1
pat "$DSK" patch_yayim_click_desktop.py YAYIM_CLICK_DK_V1
docker build -t krb-assessment:secure . >/tmp/yclick_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/yclick_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] mobil YAYIM_CLICK_V1: "; docker exec "$CID" grep -c YAYIM_CLICK_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaustu YAYIM_CLICK_DK_V1: "; docker exec "$CID" grep -c YAYIM_CLICK_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] sizan yorum kalan (0 olmali): "; docker exec "$CID" sh -c "grep -c 'join(\"\")}  /\* YAYIM_OKUNDU_V1' /app/shells/saha.js || true"
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Hızlı Duyuru satirina tikla -> tam metin; sizan yorum temizlendi."
