#!/usr/bin/env bash
# CIRO — saha kırılımı + ₺/ziyaret karşılaştırması + REP-ALANI SEÇİCİSİ (Tümü/Ticari/Tüketici) + 30 gün varsayılan.
#   Server: yönetici payload'una saha_tip + ziyaret kırılımı (CIRO_SEG_SRV_V1, idempotent).
#   Masaüstü: rpCiro (CIRO_UI6_DK_V1) — UI5'in yerine geçer; kırılım + karşılaştırma + rep-alanı seçici + kapsam düzeltmesi.
#   + Rapor tarih varsayılanı son 30 gün (RAPOR_DEF30_DK_V1, idempotent).
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ciro_seg_ui6_desktop.sh patch_ciro_seg_server.py patch_ciro_ui6_desktop.py patch_rapor_default30_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ciro_seg_ui6_desktop.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
DSK=shells/saha_desktop.js
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
for p in patch_ciro_seg_server.py patch_ciro_ui6_desktop.py patch_rapor_default30_desktop.py; do [ -f "$p" ] || { echo "HATA: $p yok"; exit 1; }; done
grep -q ZIYARET_CIRO_V1 "$SRV" || { echo "HATA: server ZIYARET_CIRO_V1 yok"; exit 1; }
grep -q CIRO_UI2_DK_V1 "$DSK" || { echo "HATA: masaüstü Ciro sekmesi (CIRO_UI2_DK) yok"; exit 1; }
TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $SRV.bak.$TS + $DSK.bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$DSK.bak.$TS" "$DSK"; }
python3 patch_ciro_seg_server.py "$SRV"         || { rollback; exit 1; }
python3 patch_ciro_ui6_desktop.py "$DSK"        || { rollback; exit 1; }
python3 patch_rapor_default30_desktop.py "$DSK" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA server node"; rollback; exit 1; }
node --check "$DSK" || { echo "HATA masaüstü node"; rollback; exit 1; }
cp "$DSK" /tmp/_chk.mjs; node --check /tmp/_chk.mjs || { echo "HATA esm"; rollback; exit 1; }
echo "[ok] tüm syntax kontrolleri"
docker build -t krb-assessment:secure . >/tmp/segui6_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/segui6_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] SEG(server): "; docker exec "$CID" grep -rc CIRO_SEG_SRV_V1 /app/server.mjs 2>/dev/null || true
echo -n "[dogrula] UI6(masaüstü): "; docker exec "$CID" grep -c CIRO_UI6_DK_V1 /app/shells/saha_desktop.js || true
echo -n "[dogrula] DEF30: "; docker exec "$CID" grep -c RAPOR_DEF30_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Kırılım + karşılaştırma + rep-alanı seçicisi + 30 gün varsayılan CANLI. Hard-refresh → Rapor › Ciro."
