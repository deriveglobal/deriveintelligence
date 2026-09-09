#!/usr/bin/env bash
# Uğur ziyaret-listesi çökmesi FIX + MUKERRER_GUN (folded). Tek geçiş, hata olursa TAM geri alma.
#   server: MUKERRER_GUN_V1 (aynı gün mükerrer ziyaret) + ZIYARET_LISTE_HAFIF_V1 (liste notu kısalt)
#   saha.js: MUKERRER_GUN_UI_V1 + ZIYARET_ROBUST_V1 (yavaş/kesik yanıtta çökme yerine "yeniden dene")
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs; J=shells/saha.js
for f in "$S" "$J" patch_mukerrer_gun.py patch_ziyaret_hafif.py patch_kaydet_mukerrer.py patch_ziyaret_robust.py; do
  [ -f "$f" ] || { echo "HATA: $f yok (scp?)"; exit 1; }
done
TS=$(date +%s); cp -a "$S" "$S.bak.$TS"; cp -a "$J" "$J.bak.$TS"; echo "[yedek] .$TS"
geri_al(){ echo "[GERI ALINIYOR]"; cp -a "$S.bak.$TS" "$S"; cp -a "$J.bak.$TS" "$J"; }
trap 'geri_al' ERR
python3 patch_mukerrer_gun.py "$S"
python3 patch_ziyaret_hafif.py "$S"
python3 patch_kaydet_mukerrer.py "$J"
python3 patch_ziyaret_robust.py "$J"
node --check "$S"; node --check "$J"; echo "[ok] node --check (2 dosya)"
docker build -t krb-assessment:secure . >/tmp/zall_build.log 2>&1 || { echo "BUILD HATASI:"; tail -20 /tmp/zall_build.log; false; }
echo "build ok"
trap - ERR
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server: "; docker exec "$CID" grep -c -E "MUKERRER_GUN_V1|ZIYARET_LISTE_HAFIF_V1" /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c -E "MUKERRER_GUN_V1|ZIYARET_LISTE_HAFIF_V1" /app/server.mjs
echo -n "[dogrula] saha.js: "; docker exec "$CID" grep -c -E "MUKERRER_GUN_UI_V1|ZIYARET_ROBUST_V1" /app/shells/saha.js
echo "[bitti] Ziyaret listesi çökmesi + mükerrer koruması CANLI. Web hard refresh / iOS relaunch."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $J.bak.$TS $J && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
