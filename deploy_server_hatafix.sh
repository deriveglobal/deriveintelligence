#!/usr/bin/env bash
# KONUSMA_YAYIM_FIX_V1 — /api/saha/konusmalar/yayim: user_modules->tenant_user_modules (module_id+active+tenant). 500 duzeldi.
# ZIYARET_FOTO_LIMIT_V1 — foto endpoint readJson 512KB->8MB. "Request body too large" 413 duzeldi (4MB goruntu).
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_server_hatafix.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
TS=$(date +%s); cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"
python3 patch_server_hatafix.py "$S"
node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/hatafix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/hatafix_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server: "; docker exec "$CID" grep -c -E "KONUSMA_YAYIM_FIX_V1|ZIYARET_FOTO_LIMIT_V1" /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c -E "KONUSMA_YAYIM_FIX_V1|ZIYARET_FOTO_LIMIT_V1" /app/server.mjs
echo "[bitti] Mesaj yayimi 500 + foto boyut 413 duzeldi."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
