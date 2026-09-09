#!/usr/bin/env bash
# KAPSAM_DK_INTRO — masaüstü Kapsam'a Ciro/Risk gibi ÜST "ne işe yarar?" intro kartı;
#   alttaki katlanır panel kaldırıldı (tutarlılık). Masaüstü. Tek build.
# KULLANIM: cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_kapsam_dk_intro.sh patch_kapsam_dk_intro.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_kapsam_dk_intro.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f patch_kapsam_dk_intro.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q KAPSAM_DK_V1 "$DSK" || { echo "HATA: once KAPSAM_DK_V1 olmali"; exit 1; }
if grep -q KAPSAM_DK_INTRO_V1 "$DSK"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_kapsam_dk_intro.py "$DSK" || { echo "PATCH HATASI; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
  node --check "$DSK" || { echo "HATA node; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
  cp "$DSK" /tmp/_c.mjs; node --check /tmp/_c.mjs || { echo "HATA esm; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/kapsamintro_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/kapsamintro_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] KAPSAM_DK_INTRO_V1: "; docker exec "$CID" grep -c KAPSAM_DK_INTRO_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Masaüstü Kapsam artık üstte 'ne işe yarar?' intro'suyla açılıyor. Hard-refresh."
