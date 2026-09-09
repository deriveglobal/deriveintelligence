#!/usr/bin/env bash
# CIRO_UI3 (masaüstü) — Ciro sekmesi: açık tema KESİN + yönetici LEADERBOARD (creative-agency).
#   CIRO_UI2_DK'nin yerine geçer (rpCiro sınır-değiştirme). Önce UI2 deploy edilmiş olmalı.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ciro_ui3_desktop.sh patch_ciro_ui3_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ciro_ui3_desktop.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f patch_ciro_ui3_desktop.py ] || { echo "HATA: patch yok"; exit 1; }
if grep -q CIRO_UI3_DK_V1 "$DSK"; then
  echo "[bilgi] $DSK zaten yamali"
else
  grep -q CIRO_UI2_DK_V1 "$DSK" || { echo "HATA: once CIRO_UI2_DK (Ciro sekmesi) deploy edilmeli"; exit 1; }
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_ciro_ui3_desktop.py "$DSK"
  node --check "$DSK" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
  cp "$DSK" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/c3d_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/c3d_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c CIRO_UI3_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] 💰 Ciro (masaüstü) — açık tema + ekip leaderboard canlı. Hard-refresh → Rapor › Ciro."
