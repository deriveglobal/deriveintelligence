#!/usr/bin/env bash
# RAPOR_KONTROL_V2 — CANLI dosyalara hedefli yükseltme:
#   Server: sabah-rotam yönetici dalı manager/admin YERİNE rep-dışı herkes (viewer dahil) → pano (SABAH_ROTAM_VIEWER_V1).
#   Masaüstü: segment seçici yalnız yönetici/admin; Rotam etiketi rep-dışı → "Bugün Sahada" (RAPOR_KONTROL_DK_V2).
#   Anchors canlı dosyalardan alındı → temiz uygulanır. Tek build.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_rapor_kontrol_v2.sh patch_rapor_kontrol_v2_desktop.py patch_sabah_rotam_viewer_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_kontrol_v2.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs; DSK=shells/saha_desktop.js
for f in "$SRV" "$DSK" patch_rapor_kontrol_v2_desktop.py patch_sabah_rotam_viewer_server.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
grep -q RAPOR_KONTROL_DK_V1 "$DSK" || { echo "HATA: masaüstü RAPOR_KONTROL_DK_V1 yok"; exit 1; }
grep -q SABAH_ROTAM_MGR_V1 "$SRV" || { echo "HATA: server SABAH_ROTAM_MGR_V1 yok"; exit 1; }
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] .bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DSK.bak.$TS" "$DSK"; }
python3 patch_sabah_rotam_viewer_server.py "$SRV" || { rollback; exit 1; }
python3 patch_rapor_kontrol_v2_desktop.py "$DSK"   || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaüstü node"; rollback; exit 1; }
cp "$DSK" /tmp/_d.mjs; node --check /tmp/_d.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/kontrol2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/kontrol2_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] VIEWER(server): "; docker exec "$CID" grep -rc SABAH_ROTAM_VIEWER_V1 /app/server.mjs 2>/dev/null || true
echo -n "[dogrula] KONTROL_V2(dk): "; docker exec "$CID" grep -c RAPOR_KONTROL_DK_V2 /app/shells/saha_desktop.js || true
echo -n "[dogrula] sabah-rotam koşulu: "; docker exec "$CID" grep -o 'session.sahaRole !== "rep") {  /\* SABAH_ROTAM_MGR_V1' /app/server.mjs | head -1 || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Hard-refresh. Segment seçici Saha kullanıcısında gizli; viewer/yönetici → Bugün Sahada panosu."
