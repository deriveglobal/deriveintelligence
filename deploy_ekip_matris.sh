#!/usr/bin/env bash
# EKIP_MATRIS — P1b Slice 1 (OKUMA): masaustu Ekip erisim matrisi (VIEWS.temsilciler).
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ekip_matris.sh patch_ekip_matris_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ekip_matris.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
for f in "$DSK" patch_ekip_matris_desktop.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done

if grep -q "EKIP_MATRIS_V1" "$DSK"; then
  echo "[bilgi] $DSK zaten yamali"
else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_ekip_matris_desktop.py "$DSK"
  node --check "$DSK" && echo "[ok] node $DSK" || { echo "HATA node $DSK; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi

docker build -t krb-assessment:secure . >/tmp/ekipmx_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ekipmx_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] masaustu marker: "; docker exec "$CID" grep -c EKIP_MATRIS_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Ekip erisim matrisi (okuma) canli — Yonetim > Ekip."
