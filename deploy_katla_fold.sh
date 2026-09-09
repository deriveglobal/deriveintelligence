#!/usr/bin/env bash
# BUGUN_KATLA_FOLD_V1 — mobil Bugun bolumleri varsayilan kapali baslasin.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_katla_fold.sh patch_bugun_katla_fold.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_katla_fold.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_bugun_katla_fold.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
if grep -q 'BUGUN_KATLA_FOLD_V1' "$MOB"; then
  echo "[bilgi] $MOB zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_bugun_katla_fold.py "$MOB"
  node --check "$MOB" && echo "[ok] node --check" || { echo "HATA node; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/katlafold_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/katlafold_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c BUGUN_KATLA_FOLD_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Mobil hard-refresh -> tum Bugun bolumleri kapali baslar; basliga dokununca acilir."
