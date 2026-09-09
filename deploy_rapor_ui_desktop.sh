#!/usr/bin/env bash
# RAPOR_UI (masaüstü) — Rapor › Özet Phase C, mobil ile birebir.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_rapor_ui_desktop.sh patch_rapor_ui_desktop.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_ui_desktop.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f patch_rapor_ui_desktop.py ] || { echo "HATA: patch yok"; exit 1; }
if grep -q RAPOR_UI_DK_V1 "$DSK"; then
  echo "[bilgi] $DSK zaten yamali"
else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_rapor_ui_desktop.py "$DSK"
  node --check "$DSK" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
  cp "$DSK" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/rud_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rud_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c RAPOR_UI_DK_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Masaüstü Rapor › Özet yeni tasarım canlı. Sayfayı hard-refresh et."
