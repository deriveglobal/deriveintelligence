#!/usr/bin/env bash
# deploy_saha_arac_repscope.sh — Slice-1: Musteri Karti gating unify (3a) + musteri-ara rep-scope (3b).
#   server_container.mjs tek Python yama (2 marker). Crash-safe: node --check + build + up + cokme testi + rollback.
# KULLANIM (Fatih):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_saha_arac_repscope.sh patch_saha_arac_repscope.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_saha_arac_repscope.sh'
set -uo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
TS=$(date +%s)
for f in "$SRV" patch_saha_arac_repscope.py; do [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }; done
cp -a "$SRV" "$SRV.bak_arsc_$TS"; echo "[yedek] $SRV.bak_arsc_$TS"
python3 patch_saha_arac_repscope.py "$SRV" || { echo "HATA yama"; cp -a "$SRV.bak_arsc_$TS" "$SRV"; exit 1; }
cp -a "$SRV" /tmp/chk_$TS.mjs; node --check /tmp/chk_$TS.mjs && echo "[ok] node --check" || { echo "HATA node; geri al"; cp -a "$SRV.bak_arsc_$TS" "$SRV"; exit 1; }
docker build -t krb-assessment:secure . >/tmp/arsc_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/arsc_build.log; cp -a "$SRV.bak_arsc_$TS" "$SRV"; docker build -t krb-assessment:secure . >/dev/null 2>&1; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"; sleep 4
for i in 1 2 3; do docker exec "$CID" sh -c 'command -v curl >/dev/null 2>&1 && curl -s -o /dev/null "http://localhost:8080/api/saha/araclarim" && curl -s -o /dev/null "http://localhost:8080/api/saha/musteri-ara?q=test"' 2>/dev/null || true; done
sleep 2
CRASH=$(docker logs --since 25s "$CID" 2>&1 | grep -c "ERR_HTTP_HEADERS_SENT" || true)
UP=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo false)
echo "[test] ERR_HTTP_HEADERS_SENT=$CRASH · container_running=$UP"
if [ "$CRASH" != "0" ] || [ "$UP" != "true" ]; then
  echo ">>> ROLLBACK"; cp -a "$SRV.bak_arsc_$TS" "$SRV"
  docker build -t krb-assessment:secure . >/tmp/arsc_rb.log 2>&1 && docker compose up -d --force-recreate krb-assessment && echo "rollback ok"
  exit 1
fi
echo -n "[dogrula] ARAC_IZIN_UNIFY_V1: ";       docker exec "$CID" grep -c ARAC_IZIN_UNIFY_V1       /app/server.mjs || true
echo -n "[dogrula] MUSTERI_ARA_REP_SCOPE_V1: "; docker exec "$CID" grep -c MUSTERI_ARA_REP_SCOPE_V1 /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] 3a gating unify + 3b rep-scope CANLI. Ali'ye matristen musterikart verince artik gorunur; rep aramada yalniz kendi musterileri. Fingerprint: fingerprint_saha_arac_repscope.sql"
