#!/usr/bin/env bash
# REP_AKTIVITE_UI_V1 — "Temsilci Aktivite" gorunumu (yalniz yonetim@krb.com.tr).
# Stage 3: viewer. Stage 1 (endpoint /api/saha/rep-aktivite) + Stage 2 (heartbeat) zaten canli.
#   1) server_container.mjs : /api/platform/me yanitina "email" (UI nav gate icin)
#   2) saha.js (mobil)      : "Daha > Aktivite" sekmesi + vRepAktivite()
#   3) saha_desktop.js      : "Yonetim > Aktivite" nav + VIEWS["rep-aktivite"]
# KULLANIM (kendi Mac terminalinde):
#   KEY=~/.ssh/roomsium_hetzner_ed25519 ; H=root@5.161.234.59
#   scp -i $KEY patch_me_email.py patch_rep_aktivite_ui.py patch_rep_aktivite_desktop.py deploy_rep_aktivite_ui.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rep_aktivite_ui.sh'
set -euo pipefail
cd /opt/krb-assessment
pick(){ for p in "./$1" "shells/$1"; do [ -f "$p" ] && { echo "$p"; return 0; }; done; return 1; }

SRV=$(pick server_container.mjs) || { echo "HATA: server_container.mjs yok"; exit 1; }
SAHA=$(pick saha.js)            || { echo "HATA: saha.js yok"; exit 1; }
DESK=$(pick saha_desktop.js)    || { echo "HATA: saha_desktop.js yok"; exit 1; }
for f in patch_me_email.py patch_rep_aktivite_ui.py patch_rep_aktivite_desktop.py; do
  [ -f "$f" ] || { echo "HATA: $f yok (scp unutuldu?)"; exit 1; }
done
echo "[dosyalar] SRV=$SRV  SAHA=$SAHA  DESK=$DESK"

# --- on-kontrol: dogru + guncel host dosyalari mi? ---
grep -q '/api/platform/me' "$SRV" || { echo "HATA: $SRV icinde /api/platform/me yok — yanlis dosya?"; exit 1; }
grep -q 'initSahaSurface' "$SAHA" || { echo "HATA: $SAHA saha mobil kabugu degil?"; exit 1; }
grep -q 'initSahaDesktop' "$DESK" || { echo "HATA: $DESK saha masaustu kabugu degil?"; exit 1; }
grep -q 'REP_AKTIVITE_V1' "$SRV" || echo "[UYARI] $SRV icinde endpoint markeri (REP_AKTIVITE_V1) yok — Stage 1 deploy edilmemis olabilir; UI kurulur ama /api/saha/rep-aktivite 404 donebilir."
grep -q 'REP_AKTIVITE_HB' "$SAHA" || echo "[UYARI] $SAHA icinde heartbeat markeri (REP_AKTIVITE_HB) yok — Stage 2 deploy edilmemis olabilir."

TS=$(date +%s)
cp -a "$SRV" "$SRV.bak.$TS"; cp -a "$SAHA" "$SAHA.bak.$TS"; cp -a "$DESK" "$DESK.bak.$TS"
echo "[yedek] .bak.$TS -> uc dosya"
rollback(){ echo ">>> GERI ALINIYOR"; cp -a "$SRV.bak.$TS" "$SRV"; cp -a "$SAHA.bak.$TS" "$SAHA"; cp -a "$DESK.bak.$TS" "$DESK"; }

python3 patch_me_email.py "$SRV"            || { rollback; exit 1; }
python3 patch_rep_aktivite_ui.py "$SAHA"    || { rollback; exit 1; }
python3 patch_rep_aktivite_desktop.py "$DESK" || { rollback; exit 1; }

if node --check "$SRV" && node --check "$SAHA" && node --check "$DESK"; then
  echo "[ok] node --check x3"
else
  echo "HATA: node --check basarisiz"; rollback; exit 1
fi

if docker build -t krb-assessment:secure . >/tmp/aktui_build.log 2>&1; then
  echo "[ok] docker build"
else
  echo "BUILD HATASI (son 25 satir):"; tail -25 /tmp/aktui_build.log; rollback; exit 1
fi
docker compose up -d --force-recreate krb-assessment && echo "[ok] recreate"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server email alani (3 bekleniyor): "; docker exec "$CID" grep -c 'email: session.email' /app/server.mjs 2>/dev/null || echo '?'
echo -n "[dogrula] mobil saha marker (1 bekleniyor):   "; docker exec "$CID" grep -c REP_AKTIVITE_UI_V1 /app/shells/saha.js 2>/dev/null || echo '?'
echo -n "[dogrula] masaustu marker (1 bekleniyor):     "; docker exec "$CID" sh -c '(grep -c REP_AKTIVITE_UI_V1 /app/shells/saha_desktop.js 2>/dev/null) || (grep -c REP_AKTIVITE_UI_V1 /app/saha_desktop.js 2>/dev/null) || echo 0'
echo "[BITTI] yonetim@krb.com.tr ile gir + Cmd+Shift+R. Mobil: 'Daha (...) > Aktivite'. Masaustu: sol menu 'Yonetim > Aktivite'."
echo "GERI ALMA: cp -a $SRV.bak.$TS $SRV; cp -a $SAHA.bak.$TS $SAHA; cp -a $DESK.bak.$TS $DESK; docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
