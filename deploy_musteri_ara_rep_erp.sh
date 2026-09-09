#!/usr/bin/env bash
# MUSTERI_ARA_REP_ERP_V1 (server-only) — Rep'ler artik Musteri Sec aramasinda ERP (SAP) carilerini
#   de gorur; yalniz ERP'de olan cariyi bulup 'sahaya ekle' ile koda bagli ekleyip aktivite girer.
#   Yildiray 04.08 (Sirayhan Hafriyat, SAP'ta var / saha'da yok).
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_musteri_ara_rep_erp_server.py deploy_musteri_ara_rep_erp.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_ara_rep_erp.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_musteri_ara_rep_erp_server.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"

python3 patch_musteri_ara_rep_erp_server.py "$S"

node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$S.bak.$TS" "$S"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/reperp_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/reperp_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "MUSTERI_ARA_REP_ERP_V1" /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c "MUSTERI_ARA_REP_ERP_V1" /app/server.mjs

echo "[bitti] CANLI. Rep relaunch/hard refresh. Aktivite → Müşteri Sec → 'sirayhan' ara → 'ERP Cari' rozetli çıkmali → sec → sahaya ekle → aktivite gir."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
