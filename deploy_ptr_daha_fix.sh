#!/usr/bin/env bash
# PTR_DAHA_FIX_V1 — Mesajlar acikken pull-to-refresh Daha sheet'ini acmasin, gorunumu yenilesin.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ptr_daha_fix.sh patch_ptr_daha_fix.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ptr_daha_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_ptr_daha_fix.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
if grep -q 'PTR_DAHA_FIX_V1' "$MOB"; then
  echo "[bilgi] $MOB zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_ptr_daha_fix.py "$MOB"
  node --check "$MOB" && echo "[ok] node --check" || { echo "HATA node --check; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/ptrdaha_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ptrdaha_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c PTR_DAHA_FIX_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] iPhone: Mesajlar acikken yukari cek-birak -> Daha acilmaz, Mesajlar yenilenir."
