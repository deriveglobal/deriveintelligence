#!/usr/bin/env bash
# SABAH_ROTAM_HOW_V1 (mobil) — rep rotasına katlanır "Rotam nasıl çalışıyor?" paneli (rep dili). Yalnız mobil.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_sabah_rotam_how.sh patch_sabah_rotam_how_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_sabah_rotam_how.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_sabah_rotam_how_mobile.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q "SABAH_ROTAM_V1" "$MOB" || { echo "HATA: once mobil SABAH_ROTAM_V1 olmali"; exit 1; }
if grep -q SABAH_ROTAM_HOW_V1 "$MOB"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_sabah_rotam_how_mobile.py "$MOB"
  node --check "$MOB" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  cp "$MOB" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/how_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/how_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] HOW: "; docker exec "$CID" grep -c SABAH_ROTAM_HOW_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Mobil rep rotasında 'Rotam nasıl çalışıyor?' paneli. Uygulamayı yeniden aç."
