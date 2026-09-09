#!/usr/bin/env bash
# KAPSAM_MOB — Kapsam & Beyaz Alan mobil sekmesi (rep-scoped: kendi kapsamı + beyaz alanı;
#   ✔️Gittim/📅Planla/🔇Sustur). Server + matris zaten canlı (artım 1). Yalniz mobil. Tek build.
# KULLANIM: cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_kapsam_mobile.sh patch_kapsam_mobile.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_kapsam_mobile.sh'
set -euo pipefail
cd /opt/krb-assessment
MOB=shells/saha.js
[ -f "$MOB" ] || { echo "HATA: $MOB yok"; exit 1; }
[ -f patch_kapsam_mobile.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q SABAH_ROTAM_V1 "$MOB" || { echo "HATA: mobil SABAH_ROTAM_V1 yok"; exit 1; }
grep -q KAPSAM_V1 server_container.mjs || { echo "HATA: server KAPSAM_V1 yok — once artim 1"; exit 1; }
if grep -q KAPSAM_MOB_V1 "$MOB"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$MOB" "$MOB.bak.$TS"; echo "[yedek] $MOB.bak.$TS"
  python3 patch_kapsam_mobile.py "$MOB" || { echo "PATCH HATASI; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  node --check "$MOB" || { echo "HATA node; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
  cp "$MOB" /tmp/_c.mjs; node --check /tmp/_c.mjs || { echo "HATA esm; geri al"; cp -a "$MOB.bak.$TS" "$MOB"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/kapsammob_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/kapsammob_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] KAPSAM_MOB: "; docker exec "$CID" grep -c KAPSAM_MOB_V1 /app/shells/saha.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Mobil Rapor'da '📍 Kapsam' sekmesi (yöneticide görünür; sahaya İzinler'den verilebilir). Uygulamayı yeniden aç."
