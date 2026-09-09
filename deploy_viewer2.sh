#!/usr/bin/env bash
# SABAH_ROTAM_VIEWER_V2 — viewer'ı (moduleRole) da ekip panosuna yönlendir. Yalnız server.
# KULLANIM (deriveapp klasöründe):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_viewer2.sh patch_sabah_rotam_viewer2_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_viewer2.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_sabah_rotam_viewer2_server.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q SABAH_ROTAM_VIEWER_V1 "$SRV" || { echo "HATA: once SABAH_ROTAM_VIEWER_V1 olmali"; exit 1; }
if grep -q SABAH_ROTAM_VIEWER_V2 "$SRV"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_sabah_rotam_viewer2_server.py "$SRV"
  node --check "$SRV" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi
docker build -t krb-assessment:secure . >/tmp/v2_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/v2_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] VIEWER_V2: "; docker exec "$CID" grep -rc SABAH_ROTAM_VIEWER_V2 /app/server.mjs 2>/dev/null || true
echo -n "[dogrula] koşul: "; docker exec "$CID" grep -o 'sahaRole !== "rep" || session.moduleRole === "viewer"' /app/server.mjs | head -1 || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Viewer artık ekip panosunu görür. Ali Kemal'i hard-refresh et → Bugün Sahada."
