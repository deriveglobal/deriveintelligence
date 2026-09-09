#!/usr/bin/env bash
# RISK_SAHA_FIX1 — "operator does not exist: uuid = text" düzeltmesi (yalnız server).
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_risk_fix1.sh patch_risk_saha_fix1_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_risk_fix1.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_risk_saha_fix1_server.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q RISK_SAHA_V1 "$SRV" || { echo "HATA: RISK_SAHA_V1 yok"; exit 1; }
if grep -q RISK_SAHA_FIX1 "$SRV"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_risk_saha_fix1_server.py "$SRV"
  node --check "$SRV" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/riskfix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/riskfix_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] FIX1: "; docker exec "$CID" grep -rc RISK_SAHA_FIX1 /app/server.mjs 2>/dev/null || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Risk endpoint düzeltildi. Rapor › Risk yeniden aç."
