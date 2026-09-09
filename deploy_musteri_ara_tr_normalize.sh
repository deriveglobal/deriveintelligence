#!/usr/bin/env bash
# MUSTERI_ARA_TR_NORMALIZE_V1 (server-only) — Musteri arama (aktivite/ziyaret/teklif icin
#   "Musteri Sec") artik TR harf + buyuk/kucuk duyarsiz. Kucuk harfle yazilmis cariler de bulunur.
#   GET /api/saha/musteri-ara: firma/musteri_adi eslesmesi lower(translate(...,'İIıŞşÇçÖöÜüĞğ',
#   'iiissccoouugg')). Ali Kemal 04.08.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_musteri_ara_tr_normalize_server.py deploy_musteri_ara_tr_normalize.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_ara_tr_normalize.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_musteri_ara_tr_normalize_server.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"

python3 patch_musteri_ara_tr_normalize_server.py "$S"

node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$S.bak.$TS" "$S"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/marnrm_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/marnrm_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "MUSTERI_ARA_TR_NORMALIZE_V1" /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c "MUSTERI_ARA_TR_NORMALIZE_V1" /app/server.mjs

echo "[bitti] CANLI. iOS relaunch / hard refresh. Aktivite → Müşteri Sec → küçük harfle yazilmis bir cariyi ara → cikmali."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
