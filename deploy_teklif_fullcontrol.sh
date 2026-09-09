#!/usr/bin/env bash
# FULL_CONTROL_V1 — teklif "Gönder" akışı (SADELEŞTİRİLDİ):
#   • Kademe + oto-onay KALDIRILDI — eşik yok, müdür/GM ayrımı yok, otomatik onay yok.
#   • HER teklif "Gönder"de ONAY_BEKLIYOR olur ve TÜM yöneticilere düşer.
#   • Herhangi bir yönetici (müdür/admin) onaylayabilir.
#   • Gönderilince onay bekleyen teklif tüm yöneticilere ANLIK push + inbox
#     ({type:"teklif_onay", id} → bildirime tıkla, teklife git).
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_teklif_fullcontrol.sh patch_teklif_fullcontrol.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_teklif_fullcontrol.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_teklif_fullcontrol.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'action === "gonder"' "$F" || { echo "HATA: $F teklif gönder akışı yok — DUR."; exit 1; }
grep -q 'sahaManagerIds' "$F" || { echo "HATA: $F push motoru (PUSH_INBOX_V1) yok — önce onu deploy et."; exit 1; }
if grep -q 'FULL_CONTROL_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_teklif_fullcontrol.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/fc_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/fc_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/server.mjs (FULL_CONTROL_V1, 2 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c FULL_CONTROL_V1 /app/server.mjs || true
echo "[BITTI] Artık her 'Gönder' teklifi onaya düşer; GM'ler push alır. Onay Bekleyen kuyruğu dolacak."
