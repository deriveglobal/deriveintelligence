#!/usr/bin/env bash
# "Bu ay = gerçek takvim ayı" paketi (Option A):
#   (1) server  : UMBRELLA_SONAY — /api/bi/kokpit-umbrella yanıtına son_ay + canli (bu ay MTD) eklenir.
#   (2) shell   : kokpit_iki.html — TF=1 "Bu ay" → başlık Ciro/Adet CANLI (Temmuz, ay içi),
#                 marj & Kâr Haritası "ay kapanınca · son kapalı ay Haziran" olarak etiketlenir.
#                 Ayrıca iş-kolu barı küçük segment etiket taşması düzeltildi (+ altına tam liste).
# Kullanım (Mac, deriveapp/):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 shells/kokpit_iki.html root@5.161.234.59:/opt/krb-assessment/shells/
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 patch_umbrella_sonay.py deploy_buay.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_buay.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f shells/kokpit_iki.html ] || { echo "HATA: shells/kokpit_iki.html yok (scp?)"; exit 1; }
[ -f patch_umbrella_sonay.py ] || { echo "HATA: patch_umbrella_sonay.py yok (scp?)"; exit 1; }
grep -q "KOKPIT_UMBRELLA_V1" "$F" || { echo "HATA: once kokpit-umbrella (Stage 1) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_umbrella_sonay.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
echo ""
echo "[bitti] Bu-ay canli. Test (tarayici konsolu):"
echo "  fetch('/api/bi/kokpit-umbrella?ay=1').then(r=>r.json()).then(d=>console.log('son_ay:',d.son_ay,'canli:',d.canli))"
echo "  -> son_ay='2026-06' (son kapali ay), canli={ay:'2026-07',ciro:..,adet:..} (Temmuz MTD)"
echo "  Onizleme: /api/bi/kokpit-iki -> 'Bu ay' sekmesi: Ciro/Adet CANLI Temmuz, marj 'ay kapaninca · Haziran'."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
