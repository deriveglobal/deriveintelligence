#!/usr/bin/env bash
# INVITE_FLOW + KRB_LABEL — davet uçları (list/cancel) + /invite kabul akışı + "KRB Saha"→"Saha".
#   server_container.mjs: INVITE_LIST_V1 + INVITE_ACCEPT_V1. app.js: KRB_LABEL_V1. Tek build.
# KULLANIM:
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_invite_flow.sh patch_invite_list_server.py patch_invite_accept_server.py patch_krb_label_app.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_invite_flow.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
APP=app.js
for f in "$SRV" "$APP" patch_invite_list_server.py patch_invite_accept_server.py patch_krb_label_app.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
TS=$(date +%s)

if grep -q "INVITE_LIST_V1" "$SRV" && grep -q "INVITE_ACCEPT_V1" "$SRV"; then
  echo "[bilgi] $SRV zaten yamali"
else
  cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_invite_list_server.py "$SRV"
  python3 patch_invite_accept_server.py "$SRV"
  node --check "$SRV" && echo "[ok] node $SRV" || { echo "HATA node $SRV; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi

if grep -q "KRB_LABEL_V1" "$APP"; then
  echo "[bilgi] $APP zaten yamali"
else
  cp -a "$APP" "$APP.bak.$TS"; echo "[yedek] $APP.bak.$TS"
  python3 patch_krb_label_app.py "$APP"
  node --check "$APP" && echo "[ok] node $APP" || { echo "HATA node $APP; geri al"; cp -a "$APP.bak.$TS" "$APP"; exit 1; }
fi

docker build -t krb-assessment:secure . >/tmp/inviteflow_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -30 /tmp/inviteflow_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] invite-list: ";   docker exec "$CID" grep -c INVITE_LIST_V1 /app/server.mjs || true
echo -n "[dogrula] invite-accept: "; docker exec "$CID" grep -c INVITE_ACCEPT_V1 /app/server.mjs || true
echo -n "[dogrula] krb-label (app.js): "; docker exec "$CID" sh -c 'grep -rc KRB_LABEL_V1 /app/app.js /app/www/app.js 2>/dev/null | grep -v ":0" || echo "(app.js yolu farkli olabilir; imaja dahil)"'
docker image prune -f >/dev/null 2>&1 && echo "[temizlik] eski imajlar silindi" || true
echo "[BITTI] Davet listesi+iptal CANLI · /invite kabul akışı CANLI · KRB Saha etiketi temizlendi."
