#!/usr/bin/env bash
# deploy_musteri_kart_dk2.sh — Slice 1: masaustu musteri karti GENIS + 2-KOLON (client-only, layout).
# KULLANIM (Fatih):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_musteri_kart_dk2.sh patch_musteri_kart_dk2.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_kart_dk2.sh'
set -uo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
TS=$(date +%s)
for f in "$DSK" patch_musteri_kart_dk2.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
cp -a "$DSK" "$DSK.bak_mk2_$TS"; echo "[yedek] $DSK.bak_mk2_$TS"
python3 patch_musteri_kart_dk2.py "$DSK" || { echo "HATA yama"; cp -a "$DSK.bak_mk2_$TS" "$DSK"; exit 1; }
cp -a "$DSK" /tmp/chk_$TS.mjs; node --check /tmp/chk_$TS.mjs && echo "[ok] node --check" || { echo "HATA node; geri al"; cp -a "$DSK.bak_mk2_$TS" "$DSK"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/mk2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/mk2_build.log; cp -a "$DSK.bak_mk2_$TS" "$DSK"; docker build -t krb-assessment:secure . >/dev/null 2>&1; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"; sleep 3
UP=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo false)
echo -n "[dogrula] MUSTERI_KART_DK2_V1: "; docker exec "$CID" grep -c MUSTERI_KART_DK2_V1 /app/shells/saha_desktop.js || true
echo "[dogrula] container_running=$UP"
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Masaustu musteri karti GENIS + 2-kolon. Bak: dar-modal gitti mi? Slice 2 = Hareketler timeline + edit alanlari + Not/Teklif/Ziyaret aksiyonlari (guncel mobil paritesi). Fingerprint: fingerprint_musteri_kart_dk2.sql"
