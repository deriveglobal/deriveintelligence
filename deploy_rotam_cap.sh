#!/usr/bin/env bash
# ROTAM_CAP — Sabah Rotam: başlangıç noktası yokken tüm portföyü "bugün" diye dökme sorununu
#   düzeltir. Güne en öncelikli 12 (+ bugün planlılar), kalanı "Bekleyen". Yalniz mobil. Tek build.
# KULLANIM (deriveapp klasoru):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_rotam_cap.sh patch_rotam_cap_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rotam_cap.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_rotam_cap_mobile.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q "SABAH_ROTAM_V1" "$MOB" || { echo "HATA: once mobil SABAH_ROTAM_V1 olmali"; exit 1; }
if grep -q ROTAM_CAP_V1 "$MOB"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_rotam_cap_mobile.py "$MOB" || { echo "PATCH HATASI; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  node --check "$MOB" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  cp "$MOB" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/rotamcap_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/rotamcap_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] ROTAM_CAP: "; docker exec "$CID" grep -c ROTAM_CAP_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Başlangıçsız günde artık en öncelikli 12 durak önerilir; kalanı 'Bekleyen'. Uygulamayı yeniden aç."
