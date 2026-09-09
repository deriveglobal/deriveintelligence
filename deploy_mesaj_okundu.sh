#!/usr/bin/env bash
# MESAJ_OKUNDU_V1 — mesaj seen/unseen + bildirim (server-only).
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_mesaj_okundu.sh patch_mesaj_okundu.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_mesaj_okundu.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_mesaj_okundu.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
if grep -q 'MESAJ_OKUNDU_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_mesaj_okundu.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/mesajokundu_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/mesajokundu_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker (7 bekleniyor): "; docker exec "$(docker compose ps -q krb-assessment)" grep -c MESAJ_OKUNDU_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Hard-refresh -> Mesajlar'da okunmamis konusma mavi/rozetli; Bugun 'Mesaj' gercek sayi; yeni mesajda bildirim gelir; konusma acilinca okundu olur."
