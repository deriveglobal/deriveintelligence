#!/usr/bin/env bash
# BUGUN_AKTIVITE_V1 — /api/saha/bugun bugun YAPILAN (TAMAMLANDI) ziyaretleri de gostersin;
#   today Istanbul saatinde; rep adi users'tan tamamlanir. Yonetici ekraninda 0 sorunu biter.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_bugun_aktivite.sh patch_bugun_aktivite.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_bugun_aktivite.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_bugun_aktivite.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q '/api/saha/bugun' "$F" || { echo "HATA: bugun endpoint yok — DUR."; exit 1; }
if grep -q 'BUGUN_AKTIVITE_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_bugun_aktivite.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/bugunakt_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/bugunakt_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker BUGUN_AKTIVITE_V1: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c BUGUN_AKTIVITE_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Masaustu/mobil Bugun ekrani -> bugun yapilan ziyaretler (29) gorunmeli."
