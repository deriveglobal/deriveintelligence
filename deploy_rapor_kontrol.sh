#!/usr/bin/env bash
# RAPOR_KONTROL (self-healing) — dk3 paneli/etiketi (idempotent) + bağlamsal kontroller + segment bug
#   + rol-duyarlı etiket + viewer→ekip panosu (server). Tek build. dk3 eksikse önce onu uygular.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_rapor_kontrol.sh patch_sabah_rotam_dk3.py patch_rapor_kontrol_desktop.py patch_sabah_rotam_viewer_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_kontrol.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DSK=shells/saha_desktop.js
for f in "$SRV" "$DSK" patch_sabah_rotam_dk3.py patch_rapor_kontrol_desktop.py patch_sabah_rotam_viewer_server.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
grep -q SABAH_ROTAM_DK_V2 "$DSK" || { echo "HATA: once SABAH_ROTAM_DK_V2 (pano) olmali"; exit 1; }
grep -q SABAH_ROTAM_MGR_V1 "$SRV" || { echo "HATA: once SABAH_ROTAM_MGR_V1 olmali"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DSK.bak.$TS" "$DSK"; }
echo "[1/3] dk3 (idempotent)…"; python3 patch_sabah_rotam_dk3.py "$DSK"      || { rollback; exit 1; }
echo "[2/3] kontrol…";          python3 patch_rapor_kontrol_desktop.py "$DSK" || { rollback; exit 1; }
echo "[3/3] viewer (server)…";  python3 patch_sabah_rotam_viewer_server.py "$SRV" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaüstü node"; rollback; exit 1; }
cp "$DSK" /tmp/_d.mjs; node --check /tmp/_d.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/kontrol_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/kontrol_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] DK_V3: ";   docker exec "$CID" grep -c SABAH_ROTAM_DK_V3 /app/shells/saha_desktop.js || true
echo -n "[dogrula] KONTROL: "; docker exec "$CID" grep -c RAPOR_KONTROL_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] VIEWER: ";  docker exec "$CID" grep -rc SABAH_ROTAM_VIEWER_V1 /app/server.mjs 2>/dev/null || true
echo -n "[dogrula] rotam tab: "; docker exec "$CID" grep -o '\["rotam", [^]]*\]' /app/shells/saha_desktop.js | head -1 || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Hard-refresh. Viewer/yönetici → Bugün Sahada panosu; rep → kişisel rota."
