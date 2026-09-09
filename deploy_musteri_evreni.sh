#!/usr/bin/env bash
# STAGE 1 · Brick 1b — /api/bi/musteri-evreni (musteri kadrani + nakit split) + kokpit-umbrella marj HAM-fix
# Onkosul: Brick 1a (KOKPIT_UMBRELLA_V1) zaten canli olmali.
# Kullanim (Mac):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 patch_musteri_evreni.py deploy_musteri_evreni.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_musteri_evreni.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_musteri_evreni.py ] || { echo "HATA: patch_musteri_evreni.py yok (scp ettin mi?)"; exit 1; }
grep -q "KOKPIT_UMBRELLA_V1" "$F" || { echo "HATA: once Brick 1a (kokpit-umbrella) deploy edilmeli"; exit 1; }

TS=$(date +%s)
cp -a "$F" "$F.bak.$TS"
echo "[yedek] $F.bak.$TS"

python3 patch_musteri_evreni.py "$F"

node --check "$F" && echo "[ok] node --check gecti" || { echo "HATA: node --check basarisiz — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }

docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment

echo ""
echo "[bitti] GET /api/bi/musteri-evreni canli + kokpit-umbrella toplam.marj HAM duzeltmesi."
echo "DOGRULAMA (kokpit tarayici konsolu, oturum acik):"
echo "  fetch('/api/bi/kokpit-umbrella?ay=12').then(r=>r.json()).then(d=>console.log('umbrella toplam.marj =',d.toplam.marj,'(beklenen 10.5)'))"
echo "  fetch('/api/bi/musteri-evreni?ay=12').then(r=>r.json()).then(d=>{console.log('bar',d.bar);console.table(d.nakit);console.log('musteri#',d.musteriler.length,'kim.tic#',d.kim_tasiyor.ticari.length)})"
echo "  BEKLENEN: umbrella marj 10.5 · bar{tuk:8.4,tic:11.7} · nakit{tuketici:6.7,ticari:43.3,sinifsiz:5.0,toplam:54.9}"
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
