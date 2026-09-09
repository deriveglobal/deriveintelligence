#!/usr/bin/env bash
# deploy_finans_izin.sh — Finans Odasi'ni Izinler matrisine bagla + dept-gate (client+server).
#   3 idempotent Python yama: matris (tenant-admin.js) + BI shell gate (bi.js) + server gate (server_container.mjs).
#   node --check (.mjs kopya ile ESM) -> build -> up -> CANLI COKME TESTI + otomatik rollback -> marker dogrula.
# KULLANIM (Fatih):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_finans_izin.sh patch_finans_izin_matris.py patch_finans_gate_bi.py patch_finans_gate_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_finans_izin.sh'
set -uo pipefail
cd /opt/krb-assessment

SRV=server_container.mjs
BI=shells/bi.js
TA=shells/tenant-admin.js
TS=$(date +%s)

for f in "$SRV" "$BI" "$TA" patch_finans_izin_matris.py patch_finans_gate_bi.py patch_finans_gate_server.py; do
  [ -f "$f" ] || { echo "HATA: $f yok"; exit 1; }
done

# --- yedekler ---
cp -a "$SRV" "$SRV.bak_finizin_$TS"
cp -a "$BI"  "$BI.bak_finizin_$TS"
cp -a "$TA"  "$TA.bak_finizin_$TS"
echo "[yedek] .bak_finizin_$TS (3 dosya)"

restore_all () {
  echo ">>> ROLLBACK: yedekler geri yukleniyor"
  cp -a "$SRV.bak_finizin_$TS" "$SRV"
  cp -a "$BI.bak_finizin_$TS"  "$BI"
  cp -a "$TA.bak_finizin_$TS"  "$TA"
}

# --- yamalar ---
python3 patch_finans_izin_matris.py "$TA" || { echo "HATA: matris yama"; restore_all; exit 1; }
python3 patch_finans_gate_bi.py     "$BI" || { echo "HATA: bi gate yama"; restore_all; exit 1; }
python3 patch_finans_gate_server.py "$SRV" || { echo "HATA: server gate yama"; restore_all; exit 1; }

# --- node --check (ESM icin .mjs kopya) ---
check_js () {  # $1 dosya
  cp -a "$1" "/tmp/chk_$TS.mjs"
  if node --check "/tmp/chk_$TS.mjs"; then echo "[ok] node --check $1"; else echo "HATA: node --check $1"; return 1; fi
}
check_js "$TA"  || { restore_all; exit 1; }
check_js "$BI"  || { restore_all; exit 1; }
check_js "$SRV" || { restore_all; exit 1; }

# --- build + up ---
docker build -t krb-assessment:secure . >/tmp/finizin_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -30 /tmp/finizin_build.log; restore_all; docker build -t krb-assessment:secure . >/dev/null 2>&1; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
sleep 4

# --- CANLI COKME TESTI: finans uclarini vur, logda ERR_HTTP_HEADERS_SENT ara ---
echo "[test] canli cokme testi (oturumsuz uc vurusu)"
for i in 1 2 3; do
  docker exec "$CID" sh -c 'command -v curl >/dev/null 2>&1 && curl -s -o /dev/null "http://localhost:8080/api/bi/finans-odasi" && curl -s -o /dev/null "http://localhost:8080/api/bi/finans/ticari-sermaye"' 2>/dev/null || true
done
sleep 2
CRASH=$(docker logs --since 30s "$CID" 2>&1 | grep -c "ERR_HTTP_HEADERS_SENT" || true)
UP=$(docker inspect -f '{{.State.Running}}' "$CID" 2>/dev/null || echo false)
echo "[test] ERR_HTTP_HEADERS_SENT=$CRASH · container_running=$UP"
if [ "$CRASH" != "0" ] || [ "$UP" != "true" ]; then
  echo ">>> COKME/DUSME TESPIT — otomatik rollback + yeniden build"
  restore_all
  docker build -t krb-assessment:secure . >/tmp/finizin_rb.log 2>&1 && docker compose up -d --force-recreate krb-assessment && echo "rollback deploy ok"
  exit 1
fi

# --- marker dogrula (KONTEYNER: /app/server.mjs, /app/shells/*) ---
echo -n "[dogrula] matris FINANS_IZIN_V1: ";   docker exec "$CID" grep -c FINANS_IZIN_V1     /app/shells/tenant-admin.js || true
echo -n "[dogrula] bi FINANS_GATE_V1: ";        docker exec "$CID" grep -c FINANS_GATE_V1      /app/shells/bi.js || true
echo -n "[dogrula] server FINANS_GATE_SRV_V1: "; docker exec "$CID" grep -c FINANS_GATE_SRV_V1  /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Finans Odasi Izinler matrisine bagli + dept-gated (client+server). SIRADAKI: backfill_finans_dept.sql, sonra fingerprint_finans_izin.sql"
