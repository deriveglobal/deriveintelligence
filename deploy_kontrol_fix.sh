#!/usr/bin/env bash
# KONTROL_FIX_V1 — (1) KONTROL bekleyen müşteriler ana listede tekrar etmesin (yalnız panelde).
#                  (2) kontrol öneri: kardeş şube görünür + <0.4 benzerlik çöp öneri gizlenir.
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_kontrol_fix.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
python3 patch_kontrol_fix.py "$F"
node --check "$F" && echo "[ok] node --check" || { echo "HATA: node --check — geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/kfix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/kfix_build.log; cp -a "$F.bak.$TS" "$F"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] /app marker: "; docker exec $(docker compose ps -q krb-assessment) grep -c KONTROL_FIX_V1 /app/server_container.mjs 2>/dev/null || docker exec $(docker compose ps -q krb-assessment) grep -c KONTROL_FIX_V1 /app/server.mjs
echo "[bitti] Kontrol paneli: kardeş şube önerisi + çöp öneri yok; liste tekrarı bitti."
echo "GERI ALMA: cp -a $F.bak.$TS $F && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
