#!/usr/bin/env bash
# YAYIM_USERMODULES_FIX_V1 — Toplu Mesaj Gonder (yayim) 'user_modules' hatasini duzeltir.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_yayim_fix.sh patch_yayim_usermodules_fix.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yayim_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_yayim_usermodules_fix.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
if grep -q 'YAYIM_USERMODULES_FIX_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_yayim_usermodules_fix.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri al"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/yayimfix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/yayimfix_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker: "; docker exec "$(docker compose ps -q krb-assessment)" grep -c YAYIM_USERMODULES_FIX_V1 /app/server.mjs || true
echo "[dogrula] yayim alici sorgusu (rep sayisi):"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT count(DISTINCT u.id) AS alici FROM users u JOIN tenant_user_modules um ON um.user_id=u.id AND um.module_id='saha' AND um.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND um.active=true WHERE u.status != 'disabled';" || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Toplu Mesaj Gonder artik hatasiz calismali."
