#!/usr/bin/env bash
# YORUM_BACKFILL — gecmis yorumlar icin sahiplere tek seferlik bildirim ucu + DRY onizleme.
# KULLANIM (deriveapp klasoründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_yorum_backfill.sh patch_yorum_backfill.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yorum_backfill.sh'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_yorum_backfill.py ] || { echo "HATA: patch yok"; exit 1; }
if grep -q YORUM_BACKFILL_V1 "$SRV"; then
  echo "[bilgi] $SRV zaten yamali"
else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_yorum_backfill.py "$SRV"
  node --check "$SRV" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
  cp "$SRV" /tmp/_chk.mjs; node --check /tmp/_chk.mjs && echo "[ok] esm" || { echo "HATA esm; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/bf_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/bf_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c YORUM_BACKFILL_V1 /app/server.mjs || true
SECRET=$(docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -Atc "SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'" 2>/dev/null || true)
sleep 4
echo "===== DRY PLAN (who=fbilen — GÖNDERMEZ) ====="
docker exec "$CID" node -e "fetch('http://localhost:3000/api/saha/yorum-backfill?key=$SECRET&who=fbilen').then(r=>r.json()).then(j=>console.log(JSON.stringify(j,null,2))).catch(e=>console.log('ERR',e.message))" || echo "(dry cagrisi calismadi)"
echo ""
echo ">>> Plan doğruysa GÖNDERMEK için:  bash send_yorum_backfill.sh"
