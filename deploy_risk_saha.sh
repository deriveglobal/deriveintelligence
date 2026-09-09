#!/usr/bin/env bash
# WAVE 2 — Risk Radarı (🚨 Risk sekmesi) + Ciro açıklama kartı.
#   Server: GET /api/saha/rapor/risk-saha (RISK_SAHA_V1) — gecikmiş × ziyaret güncelliği.
#   Masaüstü + Mobil: 🚨 Risk sekmesi (RISK_SAHA_DK_V1 / RISK_SAHA_V1) + Ciro üstü açıklama (CIRO_INTRO_*).
#   Tek build. Hepsi idempotent + hata olursa geri alır.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_risk_saha.sh patch_risk_saha_server.py patch_risk_saha_desktop.py patch_risk_saha_mobile.py patch_ciro_intro_desktop.py patch_ciro_intro_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_risk_saha.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DSK=shells/saha_desktop.js; MOB=shells/saha.js
for f in "$SRV" "$DSK" "$MOB"; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
for p in patch_risk_saha_server.py patch_risk_saha_desktop.py patch_risk_saha_mobile.py patch_ciro_intro_desktop.py patch_ciro_intro_mobile.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
grep -q ZIYARET_CIRO_V1 "$SRV" || { echo "HATA: server ZIYARET_CIRO_V1 yok"; exit 1; }
grep -q CIRO_UI6_DK_V1 "$DSK" || { echo "HATA: masaüstü CIRO_UI6_DK yok"; exit 1; }
grep -q CIRO_UI6_V1 "$MOB" || { echo "HATA: mobil CIRO_UI6 yok"; exit 1; }
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DSK.bak.$TS" "$DSK"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_risk_saha_server.py "$SRV"      || { rollback; exit 1; }
python3 patch_risk_saha_desktop.py "$DSK"     || { rollback; exit 1; }
python3 patch_ciro_intro_desktop.py "$DSK"    || { rollback; exit 1; }
python3 patch_risk_saha_mobile.py "$MOB"      || { rollback; exit 1; }
python3 patch_ciro_intro_mobile.py "$MOB"     || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaüstü node"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA mobil node"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm mobil"; rollback; exit 1; }
cp "$DSK" /tmp/_d.mjs; node --check /tmp/_d.mjs || { echo "HATA esm masaüstü"; rollback; exit 1; }
echo "[ok] syntax (server + masaüstü + mobil)"
docker build -t krb-assessment:secure . >/tmp/risk_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/risk_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] RISK server: "; docker exec "$CID" grep -rc RISK_SAHA_V1 /app/server.mjs 2>/dev/null || true
echo -n "[dogrula] RISK masaüstü: "; docker exec "$CID" grep -c RISK_SAHA_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] RISK mobil: "; docker exec "$CID" grep -c RISK_SAHA_V1 /app/shells/saha.js || true
echo -n "[dogrula] Ciro açıklama (dk/mob): "; docker exec "$CID" grep -c CIRO_INTRO_DK_V1 /app/shells/saha_desktop.js || true; docker exec "$CID" grep -c CIRO_INTRO_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] 🚨 Risk Radarı CANLI (masaüstü+mobil) + Ciro açıklaması. Hard-refresh / uygulamayı yeniden aç → Rapor › Risk."
