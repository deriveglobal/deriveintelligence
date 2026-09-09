#!/usr/bin/env bash
# MUSTERI_OLAYLAR_ZIYARET_FIX_V1 (server-only) — Musteri Karti "Hareketler"de ziyaretler artik
#   listeleniyor. /olaylar ziyaret sorgusu var olmayan kolonlar (lokasyon_adi, foto_sayisi) yerine
#   LEFT JOIN saha_musteri_lokasyon (l.ad) + saha_ziyaret_foto alt-sorgusu kullaniyor + z.id.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_olaylar_ziyaret_fix_server.py deploy_olaylar_ziyaret_fix.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_olaylar_ziyaret_fix.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_olaylar_ziyaret_fix_server.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"

python3 patch_olaylar_ziyaret_fix_server.py "$S"

node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$S.bak.$TS" "$S"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/zfix_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/zfix_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "MUSTERI_OLAYLAR_ZIYARET_FIX_V1" /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c "MUSTERI_OLAYLAR_ZIYARET_FIX_V1" /app/server.mjs

echo "[bitti] CANLI. iOS relaunch / hard refresh. Musteri karti → Hareketler → 'ziyaret' cipi → ziyaretler artik listelenmeli."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
