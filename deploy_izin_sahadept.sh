#!/usr/bin/env bash
# IZIN_SAHADEPT — Saha alt-sekme SUNUCU yetkilendirmesi: Ciro/Risk/Rotam endpoint'leri
#   artik departments[] denetler (yetkisiz = 403). requireBiDept muadili; grandfather/rol
#   mantigi client ile ayni. Yalniz server. Tek build.
# KULLANIM (deriveapp klasoru):
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY deploy_izin_sahadept.sh patch_izin_sahadept_server.py $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_izin_sahadept.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] || { echo "HATA: $SRV yok"; exit 1; }
[ -f patch_izin_sahadept_server.py ] || { echo "HATA: patch yok"; exit 1; }
grep -q "async function requireSahaAccess" "$SRV" || { echo "HATA: requireSahaAccess yok"; exit 1; }
grep -q "requireBiDept"                    "$SRV" || { echo "HATA: requireBiDept yok (taban beklenmedik)"; exit 1; }

if grep -q IZIN_SAHADEPT_V1 "$SRV"; then echo "[bilgi] zaten yamali"; else
  TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
  python3 patch_izin_sahadept_server.py "$SRV" || { echo "PATCH HATASI; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
  node --check "$SRV" && echo "[ok] node" || { echo "HATA node; geri al"; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
fi

docker build -t krb-assessment:secure . >/tmp/sahadept_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/sahadept_build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] requireSahaDept: "; docker exec "$CID" grep -c "async function requireSahaDept" /app/server.mjs || true
echo -n "[dogrula] endpoint denetimi: "; docker exec "$CID" grep -c 'requireSahaDept(request, "' /app/server.mjs || true
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] Ciro/Risk/Rotam artik sunucuda da kapali: yetkisiz rep dogrudan API'de 403 alir."
