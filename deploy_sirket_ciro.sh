#!/usr/bin/env bash
# "Ciro = TUM SIRKET + gelir kirilimi" paketi:
#   (1) server : UMBRELLA_SONAY (son_ay+canli) + SIRKET_CIRO (sirket.ciro/kirilim, genis canli). Idempotent — varsa atlar.
#   (2) shell  : kokpit_iki.html — 01 Sirket: Ciro=tum sirket, altinda Gelir kirilimi bari,
#                Adet=yalniz lastik, Bruk marj=lastik isi. Her metrik ne olctugunu acik yazar.
# Kullanim (Mac, deriveapp/):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 shells/kokpit_iki.html root@5.161.234.59:/opt/krb-assessment/shells/
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 patch_umbrella_sonay.py patch_sirket_ciro.py deploy_sirket_ciro.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_sirket_ciro.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f shells/kokpit_iki.html ] || { echo "HATA: shells/kokpit_iki.html yok (scp?)"; exit 1; }
[ -f patch_umbrella_sonay.py ] || { echo "HATA: patch_umbrella_sonay.py yok (scp?)"; exit 1; }
[ -f patch_sirket_ciro.py ] || { echo "HATA: patch_sirket_ciro.py yok (scp?)"; exit 1; }
grep -q "KOKPIT_UMBRELLA_V1" "$F" || { echo "HATA: once kokpit-umbrella (Stage 1) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_umbrella_sonay.py "$F"   # varsa atlar (idempotent)
python3 patch_sirket_ciro.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
echo ""
echo "[bitti] Ciro=tum sirket + gelir kirilimi canli. Test (tarayici konsolu):"
echo "  fetch('/api/bi/kokpit-umbrella?ay=1').then(r=>r.json()).then(d=>console.log('canli:',d.canli))"
echo "  -> canli.ciro ~= 72 (tum sirket, Temmuz), canli.adet ~= 6.2k (lastik), canli.kirilim = is-kolu dizisi."
echo "  fetch('/api/bi/kokpit-umbrella?ay=12').then(r=>r.json()).then(d=>console.log('sirket:',d.sirket))"
echo "  -> sirket.ciro = 12-ay tum sirket, sirket.kirilim = gelir kirilimi."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
