#!/usr/bin/env bash
# KONTROL_ARA_V1 — "Kontrol Bekleyen Müşteri" panelini üstteki arama kutusuyla filtrele + ilk 60 göster.
# Kullanım (Mac): scp -i $KEY patch_kontrol_ara.py deploy_kontrol_ara.sh $H:/opt/krb-assessment/
#                 ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_kontrol_ara.sh'
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_kontrol_ara.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
head -c 20 "$F" | grep -q "{\\\\rtf" && { echo "HATA: $F RTF bozuk"; exit 1; } || true
python3 patch_kontrol_ara.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/kontrol_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/kontrol_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] /app'te marker: "; docker exec $(docker compose ps -q krb-assessment) grep -c KONTROL_ARA_V1 /app/shells/saha.js
echo "[bitti] Tarayıcıda Cmd+Shift+R (hard refresh) şart."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
