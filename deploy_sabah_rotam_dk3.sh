#!/usr/bin/env bash
# SABAH_ROTAM_DK_V3 — yönetici panosuna katlanır "Nasıl çalışıyor + öğrenme/tahmin" paneli + sekme etiketi "🌅 Bugün Sahada". Yalnız masaüstü.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_sabah_rotam_dk3.sh patch_sabah_rotam_dk3.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_sabah_rotam_dk3.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f patch_sabah_rotam_dk3.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q SABAH_ROTAM_DK_V2 "$DSK" || { echo "HATA: once SABAH_ROTAM_DK_V2 (pano) olmali"; exit 1; }
if grep -q SABAH_ROTAM_DK_V3 "$DSK"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_sabah_rotam_dk3.py "$DSK"
  node --check "$DSK" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
  cp "$DSK" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/dk3_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/dk3_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] DK_V3: "; docker exec "$CID" grep -c SABAH_ROTAM_DK_V3 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Yönetici panosu: sekme '🌅 Bugün Sahada' + katlanır 'Nasıl çalışıyor?' paneli. Hard-refresh."
