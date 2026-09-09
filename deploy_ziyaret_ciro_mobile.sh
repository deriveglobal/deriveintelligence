#!/usr/bin/env bash
# ZIYARET_CIRO_UI (mobil) — Rapor'a 💰 Ciro sekmesi.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_ziyaret_ciro_mobile.sh patch_ziyaret_ciro_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_ciro_mobile.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_ziyaret_ciro_mobile.py ] || { echo "HATA: patch yok"; exit 1; }
if grep -q ZIYARET_CIRO_UI_V1 "$MOB"; then
  echo "[bilgi] $MOB zaten yamali"
else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_ziyaret_ciro_mobile.py "$MOB"
  node --check "$MOB" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  cp "$MOB" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/zcu_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/zcu_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c ZIYARET_CIRO_UI_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] 💰 Ciro sekmesi canlı (mobil). Uygulamayı yeniden aç → Rapor › Ciro."
