#!/usr/bin/env bash
# RAKIP_OCR_BACKFILL_V1 — mevcut ziyaret fotoğraflarını yeniden tara (on-demand).
#   Sunucu: POST /api/saha/ziyaretler/:id/foto-oku (yönetici) → o ziyaretin fotolarını
#     _rakipFotoCoz'dan geçirir, eski FOTO satırlarını silip yeniden yazar, sayıyı döner.
#   Masaüstü: ziyaret detayında foto altında "🔍 Fotoğraftan rakip fiyat oku" butonu (yönetici).
#   Bağımlılık: RAKIP_OCR_V1 (vision fonksiyonu) sunucuda olmalı.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_rakip_backfill.sh patch_rakip_backfill_server.py patch_rakip_backfill_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rakip_backfill.sh'
set -euo pipefail
cd /opt/krb-assessment
[ -f server_container.mjs ] && [ -f shells/saha_desktop.js ] || { echo "HATA: hedef dosyalar yok"; exit 1; }
[ -f patch_rakip_backfill_server.py ] && [ -f patch_rakip_backfill_desktop.py ] || { echo "HATA: patch(ler) yok (scp?)"; exit 1; }
grep -q 'RAKIP_OCR_V1' server_container.mjs || { echo "HATA: RAKIP_OCR_V1 yok — önce vision patch'i deploy et."; exit 1; }

patchla () {  # $1=patch $2=dosya $3=marker
  if grep -q "$3" "$2"; then echo "[bilgi] $2 zaten yamali"; return; fi
  TS=$(date +%s); cp -a "$2" "$2.bak.$TS"; echo "[yedek] $2.bak.$TS"
  python3 "$1" "$2"
  node --check "$2" && echo "[ok] node --check $2" || { echo "HATA node $2; geri al"; cp -a "$2.bak.$TS" "$2"; exit 1; }
}
patchla patch_rakip_backfill_server.py  server_container.mjs    RAKIP_OCR_BACKFILL_V1
patchla patch_rakip_backfill_desktop.py shells/saha_desktop.js  RAKIP_OCR_BACKFILL_V1

docker build -t krb-assessment:secure . >/tmp/backfill_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/backfill_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] server marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c RAKIP_OCR_BACKFILL_V1 /app/server.mjs || true
echo -n "[dogrula] masaustu marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c RAKIP_OCR_BACKFILL_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Masaüstü → KAVANLAR ziyaretini aç → foto altındaki '🔍 Fotoğraftan rakip fiyat oku' butonuna bas."
