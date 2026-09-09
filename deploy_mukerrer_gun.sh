#!/usr/bin/env bash
# MUKERRER_GUN_V1 — ayni musteriye ayni gun ikinci "tamamlandi" kaydini yonet.
#   <3dk cift-tik: mevcut kaydin notunu gunceller (metin kaybi yok).
#   >3dk ayni gun: sessiz kopya acmaz -> istemci "duzenle / yeni kayit" diye sorar.
#   force_yeni ile gercek ikinci ziyaret hala mumkun. Sunucu + saha.js. Idempotent.
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
J=shells/saha.js
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f "$J" ] || { echo "HATA: $J yok"; exit 1; }
[ -f patch_mukerrer_gun.py ]   || { echo "HATA: patch_mukerrer_gun.py yok (scp?)"; exit 1; }
[ -f patch_kaydet_mukerrer.py ] || { echo "HATA: patch_kaydet_mukerrer.py yok (scp?)"; exit 1; }
TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; cp -a "$J" "$J.bak.$TS"; echo "[yedek] $S.bak.$TS + $J.bak.$TS"
python3 patch_mukerrer_gun.py "$S"
python3 patch_kaydet_mukerrer.py "$J"
geri_al(){ echo "[GERI ALINIYOR]"; cp -a "$S.bak.$TS" "$S"; cp -a "$J.bak.$TS" "$J"; }
node --check "$S" && echo "[ok] node --check $S" || { echo "HATA: $S node --check"; geri_al; exit 1; }
node --check "$J" && echo "[ok] node --check $J" || { echo "HATA: $J node --check"; geri_al; exit 1; }
docker build -t krb-assessment:secure . >/tmp/mukgun_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/mukgun_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c MUKERRER_GUN_V1 /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c MUKERRER_GUN_V1 /app/server.mjs
echo -n "[dogrula] saha.js marker: "; docker exec "$CID" grep -c MUKERRER_GUN_UI_V1 /app/shells/saha.js
echo "[bitti] Mukerrer-gun korumasi CANLI. Hard refresh (Cmd+Shift+R) / iOS relaunch."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $J.bak.$TS $J && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
