#!/usr/bin/env bash
# deploy_memnuniyet_izin.sh — Memnuniyet panelini Izinler matrisine bagla + server dept-gate.
#   2 idempotent Python yama: matris (tenant-admin.js) + SAHA_DEPT_MAP (server_container.mjs).
#   node --check (.mjs) -> build -> up -> CANLI COKME TESTI + otomatik rollback -> marker dogrula.
# KULLANIM (Fatih):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_memnuniyet_izin.sh patch_memnuniyet_izin_matris.py patch_memnuniyet_gate_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_memnuniyet_izin.sh'
set -uo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
TA=shells/tenant-admin.js
TS=$(date +%s)
for f in "$SRV" "$TA" patch_memnuniyet_izin_matris.py patch_memnuniyet_gate_server.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done
cp -a "$SRV" "$SRV.bak_memn_$TS"; cp -a "$TA" "$TA.bak_memn_$TS"; echo "[yedek] .bak_memn_$TS"
restore () { cp -a "$SRV.bak_memn_$TS" "$SRV"; cp -a "$TA.bak_memn_$TS" "$TA"; }

python3 patch_memnuniyet_izin_matris.py "$TA"  || { echo "HATA: matris yama"; restore; exit 1; }
python3 patch_memnuniyet_gate_server.py "$SRV" || { echo "HATA: server yama"; restore; exit 1; }

for x in "$TA" "$SRV"; do cp -a "$x" /tmp/chk_$TS.mjs; node --check /tmp/chk_$TS.mjs && echo "[ok] node $x" || { echo "HATA node $x"; restore; exit 1; }; done

docker build -t krb-assessment:secure . >/tmp/memn_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -30 /tmp/memn_build.log; restore; docker build -t krb-assessment:secure . >/dev/null 2>&1; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
sleep 4
for i in 1 2 3; do docker exec "$CID" sh -c 'command -v curl >/dev/null 2>&1 && curl -s -o /dev/null "http://localhost:8080/api/saha/nabiz-ozet"' 2>/dev/null || true; done
sleep 2
CRASH=$(docker logs --since 25s "$CID" 2>&1 | grep -c "ERR_HTTP_HEADERS_SENT" || true)
UP=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo false)
echo "[test] ERR_HTTP_HEADERS_SENT=$CRASH · container_running=$UP"
if [ "$CRASH" != "0" ] || [ "$UP" != "true" ]; then
  echo ">>> ROLLBACK"; restore
  docker build -t krb-assessment:secure . >/tmp/memn_rb.log 2>&1 && docker compose up -d --force-recreate krb-assessment && echo "rollback ok"
  exit 1
fi
echo -n "[dogrula] matris MEMNUNIYET_IZIN_V1: ";   docker exec "$CID" grep -c MEMNUNIYET_IZIN_V1     /app/shells/tenant-admin.js || true
echo -n "[dogrula] server MEMNUNIYET_GATE_SRV_V1: "; docker exec "$CID" grep -c MEMNUNIYET_GATE_SRV_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Memnuniyet matrise bagli + nabiz-ozet dept-gated. SIRADAKI: (deploy oncesi backfill'i calistirdiysan) fingerprint_memnuniyet_izin.sql"
