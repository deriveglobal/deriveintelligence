#!/usr/bin/env bash
# FOTO_DECODE_SAGLAM_V1 (client-only) — Galeri fotografi ziyarette gorunmuyor (Eftal Yildiz, 24 Agu).
#   kucult() artik asilmaz (onerror+timeout+cikti dogrulama); 3 foto handler'i okunamayani atlar + gorunur uyarir.
#   SADECE shells/saha.js degisir. Server DOKUNULMAZ (foto ucu zaten sIkI ve dogru).
# KULLANIM (Mac'ten):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_foto_heic_client.py deploy_foto_heic.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_foto_heic.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_foto_heic_client.py ] || { echo "HATA: client patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_foto_heic_client.py "$C"

geri_al() { cp -a "$C.bak.$TS" "$C"; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA client syntax"; geri_al; exit 1; }

echo -n "[dogrula] marker sayisi (beklenen 4): "; grep -c 'FOTO_DECODE_SAGLAM_V1' "$C" || true
echo -n "[dogrula] img.onerror: "; grep -c 'img.onerror' "$C" || true

docker build -t krb-assessment:secure . >/tmp/fotoheic_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/fotoheic_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] container marker: "; docker exec "$CID" grep -c "FOTO_DECODE_SAGLAM_V1" /app/shells/saha.js

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. iOS/Android relaunch / hard refresh."
echo "  Beklenen: galeriden secilen decode-edilebilir foto artik forma girer + kaydolur + ziyarette gorunur."
echo "  Decode edilemeyen (or HEIC/Android) foto: SESSIZCE dusmez — kullaniciya 'okunamadi' uyarisi cikar."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
