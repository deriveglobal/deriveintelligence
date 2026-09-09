#!/usr/bin/env bash
# ONERI_BADGE_KAPALI_V1 — Oneri nav rozeti artik kapali kayitlardaki (Tamamlandi/Reddedildi)
#   yeni mesajlari da sayar. Fatih istegi: tamamlanan kayda gelen cevabi in-app rozetle gor.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_oneri_badge_kapali_client.py deploy_oneri_badge_kapali.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_oneri_badge_kapali.sh'
set -euo pipefail
cd /opt/krb-assessment
C=shells/saha.js
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_oneri_badge_kapali_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_oneri_badge_kapali_client.py "$C"

node --check "$C" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$C.bak.$TS" "$C"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/onbadge_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/onbadge_build.log; cp -a "$C.bak.$TS" "$C"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker (2 bekleniyor): "; docker exec "$CID" grep -c "ONERI_BADGE_KAPALI_V1" /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Tamamlanmis bir kayda cevap gelince 'Daha' (💡 Öneriler) rozeti yanar; kayitta 🔴."
echo "GERI ALMA: cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
