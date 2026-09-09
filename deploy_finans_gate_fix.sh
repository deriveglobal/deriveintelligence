#!/usr/bin/env bash
# deploy_finans_gate_fix.sh — bi.js nav'inda sizan "/* FINANS_GATE_V1 */" metnini temizle.
#   Tek satir kozmetik fix (gate mantigi degismez). Crash-safe: node --check + build + up + cokme testi + rollback.
# KULLANIM (Fatih):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_finans_gate_fix.sh patch_finans_gate_fix.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_finans_gate_fix.sh'
set -uo pipefail
cd /opt/krb-assessment
BI=shells/bi.js
TS=$(date +%s)
for f in "$BI" patch_finans_gate_fix.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done

cp -a "$BI" "$BI.bak_gatefix_$TS"; echo "[yedek] $BI.bak_gatefix_$TS"

python3 patch_finans_gate_fix.py "$BI" || { echo "HATA: yama"; cp -a "$BI.bak_gatefix_$TS" "$BI"; exit 1; }

cp -a "$BI" /tmp/chk_$TS.mjs
node --check /tmp/chk_$TS.mjs && echo "[ok] node --check" || { echo "HATA node --check; geri al"; cp -a "$BI.bak_gatefix_$TS" "$BI"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/gatefix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -30 /tmp/gatefix_build.log; cp -a "$BI.bak_gatefix_$TS" "$BI"; docker build -t krb-assessment:secure . >/dev/null 2>&1; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
sleep 4
CRASH=$(docker logs --since 20s "$CID" 2>&1 | grep -c "ERR_HTTP_HEADERS_SENT" || true)
UP=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo false)
echo "[test] ERR_HTTP_HEADERS_SENT=$CRASH · container_running=$UP"
if [ "$CRASH" != "0" ] || [ "$UP" != "true" ]; then
  echo ">>> ROLLBACK"; cp -a "$BI.bak_gatefix_$TS" "$BI"
  docker build -t krb-assessment:secure . >/tmp/gatefix_rb.log 2>&1 && docker compose up -d --force-recreate krb-assessment && echo "rollback ok"
  exit 1
fi
echo -n "[dogrula] sizan yorum (0 olmali): "; docker exec "$CID" sh -c "grep -c \": ''}  /\* FINANS_GATE_V1\" /app/shells/bi.js" || true
echo -n "[dogrula] FINANS_GATE_V1 (651 kalir, 1 olmali): "; docker exec "$CID" grep -c "FINANS_GATE_V1" /app/shells/bi.js || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] nav sizan yorum temizlendi. Fingerprint: fingerprint_finans_gate_fix.sql"
