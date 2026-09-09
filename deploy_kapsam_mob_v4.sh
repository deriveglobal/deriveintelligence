#!/usr/bin/env bash
# KAPSAM_MOB_V4 — dürüst dil (vaat yok; rakam = son 12 ay cirosu) + kompakt aksiyon butonları
#   (dev tam-genişlik bar yok; 🔇 -> "Sustur"). Yalniz mobil. Tek build.
# KULLANIM: cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_kapsam_mob_v4.sh patch_kapsam_mob_v4.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_kapsam_mob_v4.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_kapsam_mob_v4.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q KAPSAM_MOB_V3 "$MOB" || { echo "HATA: once KAPSAM_MOB_V3 olmali"; exit 1; }
if grep -q KAPSAM_MOB_V4 "$MOB"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_kapsam_mob_v4.py "$MOB" || { echo "PATCH HATASI; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  node --check "$MOB" || { echo "HATA node; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  cp "$MOB" /tmp/_c.mjs; node --check /tmp/_c.mjs || { echo "HATA esm; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/kapsammobv4_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/kapsammobv4_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] KAPSAM_MOB_V4: "; docker exec "$CID" grep -c KAPSAM_MOB_V4 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Dürüst dil + kompakt butonlar. Uygulamayı yeniden aç."
