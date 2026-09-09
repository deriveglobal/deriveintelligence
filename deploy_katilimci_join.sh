#!/usr/bin/env bash
# KATILIMCI_JOIN_V1 — ortak ziyaret gorunurlugu: katilimci (saha kullanicisi) reptler ziyareti KENDI listelerinde gorur.
#   Yeni tablo saha_ziyaret_katilimci (boot'ta olusur). Kaydet/duzenle/tamamla'da isim->user_id cozulup senkronlanir.
#   Liste sorgusu: rep kendi VEYA katilimci oldugu ziyaretleri gorur. Ekip/rapor toplamlari birincil rep_id'de kalir (cift-sayim yok).
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_katilimci_join_server.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
TS=$(date +%s); cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"
python3 patch_katilimci_join_server.py "$S"
node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/kjoin_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -20 /tmp/kjoin_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c KATILIMCI_JOIN_V1 /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c KATILIMCI_JOIN_V1 /app/server.mjs
echo -n "[dogrula] tablo: "; docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "SELECT to_regclass('saha_ziyaret_katilimci')" 2>/dev/null || echo "(psql env yoksa elle bak)"
echo "[bitti] Ortak ziyaret gorunurlugu CANLI. iOS relaunch / hard refresh."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
