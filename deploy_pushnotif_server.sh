#!/usr/bin/env bash
# PUSH_INBOX_V1 + PUSH_HOOKS_V3 — sunucu tarafı:
#   • Ziyaret girişi → yöneticilere ANLIK push (giren hariç)   {type:"ziyaret", id}
#   • Teklif girişi  → yöneticilere ANLIK push (giren hariç)   {type:"teklif_yeni", id}
#   • Bildirim kutusu (inbox): her push bi_bildirim'e yazılır (duyuru/mesaj/teklif/hatırlatma dahil)
#   • GET /api/saha/bildirimler (liste + okunmamış sayısı) · POST /api/saha/bildirimler/okundu
#   Not: duyuru + mesaj rep'lere ZATEN anlık gidiyor (pushToTenant / pushToUsers) — dokunulmadı.
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_pushnotif_server.sh patch_pushnotif_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_pushnotif_server.sh'
set -euo pipefail
cd /opt/krb-assessment
F=server_container.mjs
[ -f "$F" ] || { echo "HATA: $F yok"; exit 1; }
[ -f patch_pushnotif_server.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }
grep -q 'async function pushToTenant' "$F" || { echo "HATA: $F push motoru değil — DUR."; exit 1; }
grep -q '/api/saha/teklifler' "$F" || { echo "HATA: $F saha server değil — DUR."; exit 1; }
if grep -q 'PUSH_INBOX_V1' "$F"; then
  echo "[bilgi] $F zaten yamali — sadece rebuild."
else
  TS=$(date +%s); cp -a "$F" "$F.bak.$TS"; echo "[yedek] $F.bak.$TS"
  python3 patch_pushnotif_server.py "$F"
  node --check "$F" && echo "[ok] node --check" || { echo "HATA node --check; geri aliniyor"; cp -a "$F.bak.$TS" "$F"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/pushnotif_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/pushnotif_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo -n "[dogrula] marker /app/server.mjs (PUSH_INBOX_V1, 2 bekleniyor): "
docker exec "$(docker compose ps -q krb-assessment)" grep -c PUSH_INBOX_V1 /app/server.mjs || true
echo "[BITTI] Bir rep ziyaret/teklif girince yönetici cihazı öter. Inbox API canlı."
