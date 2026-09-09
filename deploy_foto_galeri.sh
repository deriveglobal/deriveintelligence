#!/usr/bin/env bash
# FOTO_GALERI_V1 — ziyaret/aktivite foto input'larindan capture="environment" kaldirildi
#   → iOS'ta galeriden secim acilir (kamera hala mevcut). Hata: Ali Kemal Picakci 29.07.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_foto_galeri_client.py deploy_foto_galeri.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_foto_galeri.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_foto_galeri_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_foto_galeri_client.py "$C"

node --check "$C" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

# Dogrulama: hedef foto input'larinda capture kalmamali (zf/zd/pt). dy-file zaten yok.
KALAN=$(grep -c 'id="zf-foto" accept="image/\*" capture="environment"\|id="zd-foto" accept="image/\*" capture="environment"\|id="pt-foto" accept="image/\*" capture="environment"' "$C" || true)
if [ "$KALAN" != "0" ]; then echo "HATA: hedef input'larda hala capture var ($KALAN) — geri aliniyor"; cp -a "$C.bak.$TS" "$C"; exit 1; fi
echo "[ok] hedef input'larda capture=0"

docker build -t krb-assessment:secure . >/tmp/fgaleri_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/fgaleri_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] zf-foto capture'siz mi: "; docker exec "$CID" grep -o 'id="zf-foto"[^>]*' /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Foto Ekle → Fotograf Kitapligi / Cek / Gozat secenekleri."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
