#!/usr/bin/env bash
# SABAH_ROTAM step 2 — yönetici ekip panosu + rep rotasını mobile'a taşı.
#   Server: sabah-rotam'a yönetici dalı (SABAH_ROTAM_MGR_V1).
#   Masaüstü: Rotam → "Bugün Sahada" ekip panosu (SABAH_ROTAM_DK_V2).
#   Mobil: 🌅 Rotam sekmesi = rep kişisel rota (SABAH_ROTAM_V1). Tek build.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_sabah_rotam2.sh patch_sabah_rotam_mgr_server.py patch_sabah_rotam_desktop2.py patch_sabah_rotam_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_sabah_rotam2.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DSK=shells/saha_desktop.js; MOB=shells/saha.js
for f in "$SRV" "$DSK" "$MOB" patch_sabah_rotam_mgr_server.py patch_sabah_rotam_desktop2.py patch_sabah_rotam_mobile.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
grep -q SABAH_ROTAM_V1 "$SRV" || { echo "HATA: server SABAH_ROTAM_V1 yok (önce step 1)"; exit 1; }
grep -q SABAH_ROTAM_DK_V1 "$DSK" || { echo "HATA: masaüstü SABAH_ROTAM_DK_V1 yok (önce step 1)"; exit 1; }
grep -q RISK_SAHA_V1 "$MOB" || { echo "HATA: mobil RISK_SAHA_V1 yok"; exit 1; }
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DSK.bak.$TS" "$DSK"; cp -a "$MOB.bak.$TS" "$MOB"; }
python3 patch_sabah_rotam_mgr_server.py "$SRV"  || { rollback; exit 1; }
python3 patch_sabah_rotam_desktop2.py "$DSK"    || { rollback; exit 1; }
python3 patch_sabah_rotam_mobile.py "$MOB"      || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaüstü node"; rollback; exit 1; }
node --check "$MOB" || { echo "HATA mobil node"; rollback; exit 1; }
cp "$MOB" /tmp/_m.mjs; node --check /tmp/_m.mjs || { echo "HATA esm mobil"; rollback; exit 1; }
cp "$DSK" /tmp/_d.mjs; node --check /tmp/_d.mjs || { echo "HATA esm masaüstü"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/rotam2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rotam2_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server MGR: "; docker exec "$CID" grep -rc SABAH_ROTAM_MGR_V1 /app/server.mjs 2>/dev/null || true
echo -n "[dogrula] masaüstü board: "; docker exec "$CID" grep -c SABAH_ROTAM_DK_V2 /app/shells/saha_desktop.js || true
echo -n "[dogrula] mobil rota: "; docker exec "$CID" grep -c SABAH_ROTAM_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Yönetici: Rapor › 🌅 Rotam = 'Bugün Sahada' ekip panosu. Rep: mobil uygulamada 🌅 Rotam = kişisel rota. Hard-refresh / uygulamayı yeniden aç."
