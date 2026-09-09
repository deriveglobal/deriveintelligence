#!/usr/bin/env bash
# STAGE 2 · CANLI ÖNİZLEME — /api/bi/kokpit-iki (yeni İki-İş kabuğu, eski /api/bi/kokpit DOKUNULMAZ)
# Kullanim (Mac):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 kokpit_iki.html root@5.161.234.59:/opt/krb-assessment/shells/
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 patch_kokpit_iki_route.py deploy_kokpit_iki.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_kokpit_iki.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f shells/kokpit_iki.html ] || { echo "HATA: shells/kokpit_iki.html yok (once scp et)"; exit 1; }
[ -f patch_kokpit_iki_route.py ] || { echo "HATA: patch_kokpit_iki_route.py yok"; exit 1; }
grep -q "KOKPIT_UMBRELLA_V1" "$F" || { echo "HATA: once Stage 1 uclari (umbrella/evreni) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_kokpit_iki_route.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
echo ""
echo "[bitti] Yeni onizleme kokpiti CANLI: https://<domain>/api/bi/kokpit-iki (oturum acik)."
echo "Eski kokpit (/api/bi/kokpit) DEGISMEDI. Toggle Tümü/Tüketici/Ticari + dönem seçici çalışır."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
