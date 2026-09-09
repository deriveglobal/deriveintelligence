#!/usr/bin/env bash
# CONTEXT_MSG_DK2 — #3 slice 3b: masaustu musteri kartinda "💬 Mesaj" butonu.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_context_msg_dk2.sh patch_context_msg_desktop2.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_context_msg_dk2.sh'
set -euo pipefail
cd /opt/krb-assessment
DSK=shells/saha_desktop.js
[ -f "$DSK" ] || { echo "HATA: $DSK yok"; exit 1; }
[ -f patch_context_msg_desktop2.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
if grep -q 'CONTEXT_MSG_DK2_V1' "$DSK"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$DSK" "$DSK.bak.$TS"; echo "[yedek] $DSK.bak.$TS"
  python3 patch_context_msg_desktop2.py "$DSK"
  node --check "$DSK" && echo "[ok] node --check" || { echo "HATA node; geri al"; cp -a "$DSK.bak.$TS" "$DSK"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/ctxdk2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ctxdk2_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker (3 bekleniyor): "; docker exec "$(docker compose ps -q krb-assessment)" grep -c CONTEXT_MSG_DK2_V1 /app/shells/saha_desktop.js || true
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Masaustu musteri karti -> 💬 Mesaj (sorumlu rep'e, 🔗 firma etiketli)."
