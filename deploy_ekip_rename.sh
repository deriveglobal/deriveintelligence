#!/usr/bin/env bash
# EKIP_RENAME — P1a: Yönetim navigasyonu "Temsilciler" -> "Ekip" (mobil+masaustu).
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ekip_rename.sh patch_ekip_rename.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ekip_rename.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js; DSK=shells/saha_desktop.js
for f in "$MOB" "$DSK" patch_ekip_rename.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
pat () { if grep -q "EKIP_RENAME_V1" "$1"; then echo "[bilgi] $1 zaten yamali"; return; fi; TS=$(date +%s); cp -a "$1" "$1.bak.$TS"; echo "[yedek] $1.bak.$TS"; python3 patch_ekip_rename.py "$1"; node --check "$1" && echo "[ok] node $1" || { echo "HATA node $1; geri al"; cp -a "$1.bak.$TS" "$1"; exit 1; }; }
pat "$MOB"
pat "$DSK"
docker build -t krb-assessment:secure . >/tmp/ekiprn_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ekiprn_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] mobil: "; docker exec "$CID" grep -c EKIP_RENAME_V1 /app/shells/saha.js || true
echo -n "[dogrula] masaustu: "; docker exec "$CID" grep -c EKIP_RENAME_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Yönetim navigasyonu artik 'Ekip' (Rapor sekmesi degismedi)."
