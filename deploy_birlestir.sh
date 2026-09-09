#!/usr/bin/env bash
# KONTROL_ONERI_ID_V1 + KONTROL_BIRLESTIR_V1 — kontrol panelinde güçlü "Olası eş"e tek-tık "🔗 Bununla birleştir".
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; SAHA=shells/saha.js
[ -f "$SRV" ] && [ -f "$SAHA" ] || { echo "HATA: kaynak dosya yok"; exit 1; }
[ -f patch_kontrol_oneri.py ] && [ -f patch_kontrol_birlestir.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$SAHA" "$SAHA.bak.$TS"; echo "[yedek] .$TS"
python3 patch_kontrol_oneri.py "$SRV"
python3 patch_kontrol_birlestir.py "$SAHA"
if node --check "$SRV" && node --check "$SAHA"; then echo "[ok] node --check"; else echo "HATA node — geri al"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$SAHA.bak.$TS" "$SAHA"; exit 1; fi
docker build -t krb-assessment:secure . >/tmp/bl_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/bl_build.log; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$SAHA.bak.$TS" "$SAHA"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
C=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server oneri_id: "; docker exec $C grep -c KONTROL_ONERI_ID_V1 /app/server.mjs 2>/dev/null || docker exec $C grep -c KONTROL_ONERI_ID_V1 /app/server_container.mjs
echo -n "[dogrula] saha birlestir: "; docker exec $C grep -c KONTROL_BIRLESTIR_V1 /app/shells/saha.js
echo "[bitti] Cmd+Shift+R. Güçlü Olası eş'te tek-tık birleştir çıkacak."
echo "GERI: cp -a $SRV.bak.$TS $SRV; cp -a $SAHA.bak.$TS $SAHA; docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
