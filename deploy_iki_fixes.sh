#!/usr/bin/env bash
# İki-İş FIX paketi: (1) shell (nakit sabitlik + mekko merge + eksen cap) yeni kokpit_iki.html
#                    (2) WINDOW_MAXAY_FIX (server) — "Bu ay" ve tum donem pencereleri max(ay)'e demirli.
# Kullanim (Mac, deriveapp/):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 shells/kokpit_iki.html root@5.161.234.59:/opt/krb-assessment/shells/
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 patch_window_fix.py deploy_iki_fixes.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_iki_fixes.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f shells/kokpit_iki.html ] || { echo "HATA: shells/kokpit_iki.html yok (scp?)"; exit 1; }
[ -f patch_window_fix.py ] || { echo "HATA: patch_window_fix.py yok (scp?)"; exit 1; }
grep -q "KOKPIT_UMBRELLA_V1" "$F" || { echo "HATA: once Stage 1 uclari canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_window_fix.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
echo ""
echo "[bitti] Shell + WINDOW_MAXAY_FIX canli. Test:"
echo "  fetch('/api/bi/kokpit-umbrella?ay=1').then(r=>r.json()).then(d=>console.log('Bu ay:',d.toplam))  # artik BOŞ degil"
echo "  Onizleme: https://<domain>/api/bi/kokpit-iki — Bu ay/3/6/12/YB hepsi veri döner, nakit split sabit."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
