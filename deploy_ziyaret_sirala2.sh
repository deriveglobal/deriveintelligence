#!/usr/bin/env bash
# ZIYARET_SIRALA_V2 — siralama karsilastiricisini saglamlastir (coalesce + iOS-guvenli parse).
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ziyaret_sirala2.sh patch_ziyaret_sirala2.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_sirala2.sh'
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_ziyaret_sirala2.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'ZIYARET_SIRALA_V1' "$F" || { echo "HATA: V1 yok — once onu deploy et."; exit 1; }
if grep -q 'ZIYARET_SIRALA_V2' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_ziyaret_sirala2.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/ziysirala2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ziysirala2_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker ZIYARET_SIRALA_V2: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c ZIYARET_SIRALA_V2 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Mobil -> Ziyaretler: en yeni gercekten ustte olmali; 'Tarih ▼/▲' yon cevirir."
