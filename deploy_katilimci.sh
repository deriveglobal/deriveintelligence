#!/usr/bin/env bash
# KATILIMCI_V1 — ziyaret formuna "Katılımcılar (ekip)" cok-secimli alan:
#   saha kullanicilarindan sec + "+ diger" ile elle isim ekle (birden fazla). detay.katilimcilar'a yazilir.
#   Tum ziyaretlerde. Duzenle/plan-tamamla'da korunur. Server: GET /api/saha/saha-kullanicilar (rep erisir).
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs; J=shells/saha.js
for f in "$S" "$J" patch_katilimci_server.py patch_katilimci_saha.py; do [ -f "$f" ] || { echo "HATA: $f yok (scp?)"; exit 1; }; done
TS=$(date +%s); cp -a "$S" "$S.bak.$TS"; cp -a "$J" "$J.bak.$TS"; echo "[yedek] .$TS"
geri_al(){ echo "[GERI ALINIYOR]"; cp -a "$S.bak.$TS" "$S"; cp -a "$J.bak.$TS" "$J"; }
trap 'geri_al' ERR
python3 patch_katilimci_server.py "$S"
python3 patch_katilimci_saha.py "$J"
node --check "$S"; node --check "$J"; echo "[ok] node --check (2 dosya)"
docker build -t krb-assessment:secure . >/tmp/katil_build.log 2>&1 || { echo "BUILD HATASI:"; tail -20 /tmp/katil_build.log; false; }
echo "build ok"; trap - ERR
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server: "; docker exec "$CID" grep -c KATILIMCI_V1 /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c KATILIMCI_V1 /app/server.mjs
echo -n "[dogrula] saha.js: "; docker exec "$CID" grep -c KATILIMCI_V1 /app/shells/saha.js
echo "[bitti] Katılımcı ekleme CANLI. iOS relaunch / hard refresh."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $J.bak.$TS $J && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
