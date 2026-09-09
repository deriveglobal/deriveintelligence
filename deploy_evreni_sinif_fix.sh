#!/usr/bin/env bash
# FIX — musteri-evreni siniflama (nakit split) verify blok D ile birebir.
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 patch_evreni_sinif_fix.py deploy_evreni_sinif_fix.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_evreni_sinif_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f patch_evreni_sinif_fix.py ] || { echo "HATA: patch_evreni_sinif_fix.py yok (scp?)"; exit 1; }
grep -q "MUSTERI_EVRENI_V1" "$F" || { echo "HATA: once musteri-evreni (Brick 1b) canli olmali"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_evreni_sinif_fix.py "$F"
node --check "$F" && echo "[ok] node --check gecti" || { echo "HATA: node --check — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
echo ""
echo "[bitti] siniflama duzeltmesi canli."
echo "DOGRULAMA (kokpit konsolu): fetch('/api/bi/musteri-evreni?ay=12').then(r=>r.json()).then(d=>console.table(d.nakit))"
echo "BEKLENEN (verify blok D): tuketici 6.7 · ticari 43.3 · sinifsiz 5.0 · toplam 54.9"
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
