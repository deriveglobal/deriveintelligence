#!/usr/bin/env bash
# TEKLIF_ONERI_V1 — Teklif formu karar yardimcisi SUNUCU UCU (Faz 1, server-only).
#   Yeni: GET /api/bi/teklif-oneri?musteri_id=&kalem=  (rol'e gore payload).
#   Paylasilan helper _smartSkorRaw/_smartKalemFiyat = musteri-fiyat-liste ile AYNI matematik.
#   Mevcut endpoint'ler DEGISMEZ. UI YOK — bu faz sadece ucu ekler + calib icin.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_teklif_oneri.sh patch_teklif_oneri.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_oneri.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_teklif_oneri.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'musteri-fiyat-liste' "$F" || { echo "HATA: $F pricing akisi yok — DUR."; exit 1; }
grep -q 'SMARTKIYAS_V1 — Musteri vs KRB kiyas' "$F" || { echo "HATA: $F SMARTKIYAS capasi yok — DUR."; exit 1; }
if grep -q 'TEKLIF_ONERI_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_teklif_oneri.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/teklifoneri_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/teklifoneri_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/server.mjs (TEKLIF_ONERI_V1, >=4 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c TEKLIF_ONERI_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Uc canli. Simdi: bash calib_teklif_oneri.sh (amber-esigi kalibrasyonu)."
