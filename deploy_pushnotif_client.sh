#!/usr/bin/env bash
# PUSH_ROUTE_V2 — istemci tarafı (mobil shells/saha.js):
#   • Bildirime tıklayınca ilgili kayda gider (ziyaret/duyuru → tam kayıt; teklif/mesaj/hatırlatma → doğru ekran)
#   • Cold-start fix: tıklama dinleyicisi AÇILIŞTA bağlanır (öldürülmüş app'te ana sayfaya düşme biter)
#   • 🔔 Bildirim kutusu (inbox): reception başlığında zil + okunmamış rozeti + liste modalı
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_pushnotif_client.sh patch_pushnotif_client.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_pushnotif_client.sh'
# NOT: Sunucu tarafı (deploy_pushnotif_server.sh) ÖNCE gitmeli — inbox endpoint'leri oradan gelir.
set -euo pipefail
cd /opt/krb-assessment
F=shells/saha.js
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_pushnotif_client.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'PUSH_KAYIT_V1' "$F" || { echo "HATA: $F push istemcisi değil — DUR."; exit 1; }
grep -q 'function renderReception' "$F" || { echo "HATA: $F saha mobil kabuğu değil — DUR."; exit 1; }
if grep -q 'PUSH_ROUTE_V2' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_pushnotif_client.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/pushcli_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/pushcli_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/shells/saha.js (PUSH_ROUTE_V2, 5+ bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c PUSH_ROUTE_V2 /app/shells/saha.js || true
echo "[BITTI] Mobil: Cmd+Shift+R / uygulamayı yeniden aç. Bildirime bas → kayda gitmeli. Reception'da 🔔."
