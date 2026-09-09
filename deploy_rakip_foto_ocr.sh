#!/usr/bin/env bash
# RAKIP_OCR_V1 — ziyaret fotoğrafındaki RAKİP FİYAT LİSTESİNİ vision ile oku.
#   Rep bir foto yükleyince (POST .../fotolar) arka planda Claude vision çalışır:
#   fiyat listesi ise her kalemi (marka/ebat/model/birim_fiyat) çıkarır →
#   saha_rakip_teklif'e yazar (kaynak='FOTO', dogrulanmis=false) → fiyat savunması/analiz besler
#   + owner'a 'rakip' sinyali (önem 3). Fiyat listesi değilse hiçbir şey yazmaz.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_rakip_foto_ocr.sh patch_rakip_foto_ocr.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rakip_foto_ocr.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_rakip_foto_ocr.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'saha_ziyaret_foto' "$F" || { echo "HATA: $F saha foto akışı yok — DUR."; exit 1; }
grep -q 'anthropic.messages.create' "$F" || { echo "HATA: $F anthropic yok — DUR."; exit 1; }
if grep -q 'RAKIP_OCR_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_rakip_foto_ocr.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/rakipocr_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rakipocr_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/server.mjs (RAKIP_OCR_V1, 2 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c RAKIP_OCR_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Bir rep rakip fiyat listesi fotosu yükleyince fiyatlar otomatik saha_rakip_teklif'e düşer."
