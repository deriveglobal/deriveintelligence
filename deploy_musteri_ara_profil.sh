#!/usr/bin/env bash
# MUSTERI_ARA_PROFIL_V1 (server-only) — musteri-ara SAHA sorgusu profil kolonlarini (raf_markalar,
#   rakip_toptancilar, bayilikler, kis/yaz_stok, sektorler, tedarikci/kullanilan_markalar,
#   arac_parki, yillik_potansiyel) doner → ziyaret formu "Musteri Sec"ten acilinca profil PREFILL
#   olur (her seferinde bos gelmez). Profil zaten DB'de dolu; yalniz forma tasinmiyordu.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_musteri_ara_profil_server.py deploy_musteri_ara_profil.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_musteri_ara_profil.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f patch_musteri_ara_profil_server.py ] || { echo "HATA: patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"

python3 patch_musteri_ara_profil_server.py "$S"

node --check "$S" && echo "[ok] node --check" || { echo "HATA: node --check"; cp -a "$S.bak.$TS" "$S"; exit 1; }

docker build -t krb-assessment:secure . >/tmp/maprofil_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/maprofil_build.log; cp -a "$S.bak.$TS" "$S"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] marker: "; docker exec "$CID" grep -c "MUSTERI_ARA_PROFIL_V1" /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c "MUSTERI_ARA_PROFIL_V1" /app/server.mjs

# DISK HIJYENI (standart)
echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. Rep relaunch/hard refresh. Aktivite → Müşteri Sec → daha once profili girilmis bir müşteri → ziyaret formunda raf/rakip/bayi PREFILL dolu gelmeli."
echo "GERI ALMA: cp -a $S.bak.$TS $S && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
