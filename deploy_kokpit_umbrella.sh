#!/usr/bin/env bash
# STAGE 1 · Brick 1a — /api/bi/kokpit-umbrella (additive, read-only, geri-alinabilir)
# Kullanim (Mac):
#   scp -i ~/.ssh/roomsium_hetzner_ed25519 patch_kokpit_umbrella.py deploy_kokpit_umbrella.sh root@5.161.234.59:/opt/krb-assessment/
#   ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59 'cd /opt/krb-assessment && bash deploy_kokpit_umbrella.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_kokpit_umbrella.py ] || { echo "HATA: patch_kokpit_umbrella.py yok (scp ettin mi?)"; exit 1; }

# Veri-degeri korumasi: alici='KRB' SQL sabitleri bu patch'te DEGISMEZ; yine de teyit.
if grep -q "alici='KRB'" "$F"; then echo "[ok] alici='KRB' korunuyor"; else echo "[uyari] alici='KRB' gorulmedi — kontrol et"; fi

TS=$(date +%s)
cp -a "$F" "$F.bak.$TS"
echo "[yedek] $F.bak.$TS"

python3 patch_kokpit_umbrella.py "$F"

node --check "$F" && echo "[ok] node --check gecti" || { echo "HATA: node --check basarisiz — geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }

docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment

echo ""
echo "[bitti] GET /api/bi/kokpit-umbrella canli."
echo "DOGRULAMA (kokpit tarayici konsolu, oturum acik):"
echo "  fetch('/api/bi/kokpit-umbrella?ay=12').then(r=>r.json()).then(d=>console.table([d.toplam,{u:'TUK',ciro:d.tuketici.ciro,marj:d.tuketici.marj},{u:'TIC',ciro:d.ticari.ciro,marj:d.ticari.marj}]))"
echo "  BEKLENEN: toplam.ciro~687.5 (marj 10.5) · TUK 262/8.4 · TIC 425.5/11.7"
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
