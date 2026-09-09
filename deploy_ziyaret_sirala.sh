#!/usr/bin/env bash
# ZIYARET_SIRALA_V1 — mobil ziyaret listesi: varsayilan en yeni ustte + Tarih ▼/▲ yon oku.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ziyaret_sirala.sh patch_ziyaret_sirala.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_sirala.sh'
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_ziyaret_sirala.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'function renderListe(repFiltre)' "$F" || { echo "HATA: vZiyaretler renderListe yok — DUR."; exit 1; }
if grep -q 'ZIYARET_SIRALA_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_ziyaret_sirala.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/ziysirala_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ziysirala_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker ZIYARET_SIRALA_V1: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c ZIYARET_SIRALA_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Mobil -> Ziyaretler: en yeni ustte; sag ustteki 'Tarih ▼' ile yonu cevir."
