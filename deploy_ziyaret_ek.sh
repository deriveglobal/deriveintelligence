#!/usr/bin/env bash
# ZIYARET_EK_V1 (server + client) — Ziyarete DOSYA eki (her tip, 8MB). Foto ile ayni 3 yer + detayda indirilebilir liste.
#   Yeni tablo saha_ziyaret_ek + 4 uc (POST/GET ekler/GET indir/DELETE). DUYURU_EK desenini yansitir.
# KULLANIM (Mac'ten):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_ziyaret_ek_server.py patch_ziyaret_ek_client.py deploy_ziyaret_ek.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_ziyaret_ek.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs; C=shells/saha.js
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_ziyaret_ek_server.py ] || { echo "HATA: server patch yok (scp?)"; exit 1; }
[ -f patch_ziyaret_ek_client.py ] || { echo "HATA: client patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; cp -a "$C" "$C.bak.$TS"; echo "[yedek] .bak.$TS"

python3 patch_ziyaret_ek_server.py "$S"
python3 patch_ziyaret_ek_client.py "$C"

geri_al() { cp -a "$S.bak.$TS" "$S"; cp -a "$C.bak.$TS" "$C"; }
node --check "$S" && echo "[ok] node --check server" || { echo "HATA server syntax"; geri_al; exit 1; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA client syntax"; geri_al; exit 1; }

echo -n "[dogrula] server marker: "; grep -c 'ZIYARET_EK_V1' "$S" || true
echo -n "[dogrula] client marker: "; grep -c 'ZIYARET_EK_V1' "$C" || true

docker build -t krb-assessment:secure . >/tmp/ziyaretek_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/ziyaretek_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] container server marker: "; docker exec "$CID" grep -c "ZIYARET_EK_V1" /app/server.mjs 2>/dev/null || docker exec "$CID" grep -c "ZIYARET_EK_V1" /app/server_container.mjs
echo -n "[dogrula] container client marker: "; docker exec "$CID" grep -c "ZIYARET_EK_V1" /app/shells/saha.js
echo -n "[dogrula] tablo saha_ziyaret_ek: "; docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform -tAc "SELECT to_regclass('"'"'public.saha_ziyaret_ek'"'"') IS NOT NULL"' 2>/dev/null || echo "(tablo boot/ilk-istekte olusur — lazy ensure)"

echo "[temizlik] docker image prune -f:"; docker image prune -f
echo -n "[disk] "; df -h / | tail -1

echo "[bitti] CANLI. iOS/Android relaunch / hard refresh."
echo "  Yeni ziyaret + ziyaret düzenleme + ziyaret tamamlama: 📎 Dosya ekle. Ziyaret detayında dosyalar indirilebilir liste."
echo "  Her tip dosya, 8MB. Rep kendi ziyareti; manager/admin hepsi."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
