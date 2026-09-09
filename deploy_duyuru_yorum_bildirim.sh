#!/usr/bin/env bash
# DUYURU_YORUM_BILDIRIM — duyuru yorumu bildirimi (yazan + önceki yorumcular, yazan hariç).
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_duyuru_yorum_bildirim.sh patch_duyuru_yorum_bildirim.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_duyuru_yorum_bildirim.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_duyuru_yorum_bildirim.py ] || { echo "HATA: patch yok"; exit 1; }
if grep -q DUYURU_YORUM_BILDIRIM_V1 "$SRV"; then
  echo "[bilgi] $SRV zaten yamali"
else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_duyuru_yorum_bildirim.py "$SRV"
  node --check "$SRV" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
  cp "$SRV" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/dy_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/dy_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c DUYURU_YORUM_BILDIRIM_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Duyuru yorumu artık bildirim gönderiyor (push + 🔔 inbox, duyuruya deep-link)."
