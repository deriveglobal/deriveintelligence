#!/usr/bin/env bash
# SABAH_ROTAM step 1 — DDL (tablolar) + server (2 uç) + masaüstü 🌅 Rotam sekmesi. Tek build.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_sabah_rotam.sh ddl_sabah_rotam.sql patch_sabah_rotam_server.py patch_sabah_rotam_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_sabah_rotam.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DSK=shells/saha_desktop.js
for f in "$SRV" "$DSK" ddl_sabah_rotam.sql patch_sabah_rotam_server.py patch_sabah_rotam_desktop.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
grep -q RISK_SAHA_V1 "$SRV" || { echo "HATA: server RISK_SAHA_V1 yok"; exit 1; }
grep -q RISK_SAHA_DK_V1 "$DSK" || { echo "HATA: masaüstü RISK_SAHA_DK yok"; exit 1; }

# 1) DDL (idempotent) — postgres container
PG="$(docker compose ps -q krb-assessment-postgres 2>/dev/null || docker ps -qf name=krb-assessment-postgres)"
[ -n "$PG" ] || { echo "HATA: postgres container bulunamadı"; exit 1; }
echo "[ddl] tablolar…"
docker exec -i "$PG" psql -U assessment_app -d assessment_platform < ddl_sabah_rotam.sql && echo "[ddl] ok" || { echo "DDL HATASI"; exit 1; }

# 2) kod yamaları
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL (kod)"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DSK.bak.$TS" "$DSK"; }
python3 patch_sabah_rotam_server.py "$SRV"  || { rollback; exit 1; }
python3 patch_sabah_rotam_desktop.py "$DSK" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaüstü node"; rollback; exit 1; }
cp "$DSK" /tmp/_d.mjs; node --check /tmp/_d.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax"

# 3) build
docker build -t krb-assessment:secure . >/tmp/rotam_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rotam_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server: "; docker exec "$CID" grep -rc SABAH_ROTAM_V1 /app/server.mjs 2>/dev/null || true
echo -n "[dogrula] masaüstü: "; docker exec "$CID" grep -c SABAH_ROTAM_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] tablo: "; docker exec -i "$PG" psql -U assessment_app -d assessment_platform -tAc "SELECT to_regclass('public.saha_rep_baslangic') IS NOT NULL AND to_regclass('public.saha_rota_log') IS NOT NULL;" || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] 🌅 Sabah Rotam (masaüstü) canlı. Hard-refresh → Rapor › Rotam. Başlangıç belirle (öneri/check-in) → mesafe+kapasite gelir."
