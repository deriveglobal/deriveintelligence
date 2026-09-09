#!/usr/bin/env bash
# MUSTERI_HATIRLATMA_DUZENLE_V1 — Musteri Karti "Hareketler"deki hatirlatmalar (not/takip)
#   artik tiklanabilir: acilan modalde metin + takip tarihi guncellenebilir ve "✓ Tamamlandi"
#   ile kapatilabilir. Server (id + PUT /api/saha/sinyal/:id) + client (tiklanabilir satir + modal).
#   Ozellik: Eftal Yildiz 03.08.
# KULLANIM (Mac terminalinden):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY patch_mk_hatirlatma_duzenle_server.py patch_mk_hatirlatma_duzenle_client.py deploy_mk_hatirlatma_duzenle.sh $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_mk_hatirlatma_duzenle.sh'
set -euo pipefail
cd /opt/krb-assessment
S=server_container.mjs
C=shells/saha.js
[ -f "$S" ] || { echo "HATA: $S yok"; exit 1; }
[ -f "$C" ] || { echo "HATA: $C yok"; exit 1; }
[ -f patch_mk_hatirlatma_duzenle_server.py ] || { echo "HATA: server patch yok (scp?)"; exit 1; }
[ -f patch_mk_hatirlatma_duzenle_client.py ] || { echo "HATA: client patch yok (scp?)"; exit 1; }

TS=$(date +%s)
cp -a "$S" "$S.bak.$TS"; echo "[yedek] $S.bak.$TS"
cp -a "$C" "$C.bak.$TS"; echo "[yedek] $C.bak.$TS"

python3 patch_mk_hatirlatma_duzenle_server.py "$S"
python3 patch_mk_hatirlatma_duzenle_client.py "$C"

geri_al() { cp -a "$S.bak.$TS" "$S"; cp -a "$C.bak.$TS" "$C"; }

node --check "$S" && echo "[ok] node --check server" || { echo "HATA: node --check server"; geri_al; exit 1; }
node --check "$C" && echo "[ok] node --check client" || { echo "HATA: node --check client"; geri_al; exit 1; }

docker build -t krb-assessment:secure . >/tmp/mkhat_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/mkhat_build.log; geri_al; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"

CID=$(docker compose ps -q krb-assessment)
echo -n "[dogrula] server marker: "; docker exec "$CID" grep -c "MUSTERI_HATIRLATMA_DUZENLE_V1" /app/server_container.mjs 2>/dev/null || docker exec "$CID" grep -c "MUSTERI_HATIRLATMA_DUZENLE_V1" /app/server.mjs
echo -n "[dogrula] client marker: "; docker exec "$CID" grep -c "MUSTERI_HATIRLATMA_DUZENLE_V1" /app/shells/saha.js

echo "[bitti] CANLI. iOS relaunch / hard refresh. Bir musteri kartini ac → Hareketler'de bir not/takip satirina (✎) tikla → metin/tarih guncelle ya da ✓ Tamamlandi."
echo "GERI ALMA: cp -a $S.bak.$TS $S && cp -a $C.bak.$TS $C && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
