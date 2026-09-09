#!/usr/bin/env bash
# YORUM_BACKFILL — GERÇEK gönderim (force). Rep başına tek push.
#   KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash send_yorum_backfill.sh [who=fbilen]'
set -euo pipefail
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
WHO="${1:-fbilen}"
SECRET=$(docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -Atc "SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'")
CID="$(docker compose ps -q krb-assessment)"
echo "GÖNDERİLİYOR (who=$WHO) ..."
docker exec "$CID" node -e "fetch('http://localhost:3000/api/saha/yorum-backfill?key=$SECRET&who=$WHO&force=1').then(r=>r.json()).then(j=>console.log(JSON.stringify(j,null,2))).catch(e=>console.log('ERR',e.message))"
echo "[BİTTİ] Gönderildi."
