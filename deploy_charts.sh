#!/usr/bin/env bash
# Grafik okunurluk paketi (SHELL-ONLY, endpoint dokunulmaz):
#   Kâr Haritası mekko -> Kâr katkısı ₺ + Marj profili % (sıralı yatay çubuk).
#   Nakit (03) "dönemden bağımsız · bugün" etiketi netleşti. Müşteri Evreni/Marka İzi AYNI.
# Kullanım (Mac, deriveapp/):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 shells/kokpit_iki.html root@5.161.234.59:/opt/krb-assessment/shells/
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 deploy_charts.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_charts.sh'
set -euo pipefail
cd /opt/krb-assessment
[ -f shells/kokpit_iki.html ] || { echo "HATA: shells/kokpit_iki.html yok (scp?)"; exit 1; }
grep -q "karBars" shells/kokpit_iki.html || { echo "HATA: yeni shell degil (karBars yok)"; exit 1; }
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
echo ""
echo "[bitti] Kâr Haritası artik Kâr katkısı ₺ + Marj profili %. Onizleme: /api/bi/kokpit-iki -> 04 Kâr Haritası."
echo "  (Endpoint degismedi; yalnizca shell. Geri alma: onceki shells/kokpit_iki.html'i koyup rebuild.)"
