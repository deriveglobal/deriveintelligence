#!/usr/bin/env bash
# YAYIM_COMMENT_FIX — SON HIZLI DUYURULAR kutusunda gorunen "/* YAYIM_OKUNDU_V1 */" metnini kaldir.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_yayim_comment_fix.sh patch_yayim_comment_fix.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yayim_comment_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_yayim_comment_fix.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
python3 patch_yayim_comment_fix.py "$MOB"
node --check "$MOB" && echo "[ok] node --check" || { echo "HATA node; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/yayimcf_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/yayimcf_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] sizinti kalan (0 olmali): "; docker exec "$(docker compose ps -q krb-assessment)" sh -c "grep -c 'join(\"\")}  /\* YAYIM_OKUNDU_V1' /app/shells/saha.js || true"
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Hard-refresh -> SON HIZLI DUYURULAR kutusunda artik yorum metni gorunmez."
