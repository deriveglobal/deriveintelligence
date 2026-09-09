#!/usr/bin/env bash
# BUGUN_ADRES_FIX_V1 — /api/saha/bugun ziyaretler sorgusundan olmayan m.adres kolonunu cikar.
#   Bu, "Bugun ekrani 0 gosteriyor" sorununun KOK NEDENI (sorgu sessizce hata veriyordu).
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_bugun_adres_fix.sh patch_bugun_adres_fix.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_bugun_adres_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_bugun_adres_fix.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
if grep -q 'BUGUN_ADRES_FIX_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_bugun_adres_fix.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/bugunadres_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/bugunadres_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker BUGUN_ADRES_FIX_V1: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c BUGUN_ADRES_FIX_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Bugun ekrani -> Bugunku Ziyaret artik bugun yapilan ziyaret sayisini (31/32) gostermeli."
