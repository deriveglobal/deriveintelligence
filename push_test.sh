#!/usr/bin/env bash
# push_test.sh — yonetim@krb.com.tr'ye GERCEK bildirim testi:
#   1) Ugur Yildiz -> yonetici gercek mesaj ekler (Mesajlar'da "1 yeni" gorunur)
#   2) zil bildirimi (bi_bildirim) ekler (uygulama ici 🔔)
#   3) yoneticinin 7 cihazina GERCEK APNS/FCM push gonderir (telefon bildirimi)
# KULLANIM (Mac Terminal):
#   cd ~/Desktop/krb-session-outputs/deriveapp
#   KEY=~/.ssh/roomsium_hetzner_ed25519; H=root@5.161.234.59
#   scp -i $KEY push_test.sh push_test.mjs $H:/opt/krb-assessment/
#   ssh -i $KEY $H 'cd /opt/krb-assessment && bash push_test.sh'
set -euo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
MGR=d28b7879-b34f-4de5-bd44-25e64e2ca734
KON=019881db-27ff-4000-a575-49066e851806
UGUR=44ec101f-9797-407c-8a29-1d0bb1317339
TEN=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
[ -f push_test.mjs ] || { echo "HATA: push_test.mjs yok (scp?)"; exit 1; }

echo "[1] Ugur -> yonetici gercek mesaj ekleniyor..."
$PSQL -c "INSERT INTO saha_konusma_mesaj (id,tenant_id,konusma_id,gonderen_id,gonderen_adi,gonderen_rol,icerik) VALUES (gen_random_uuid(),'$TEN','$KON','$UGUR','Uğur Yıldız','rep','Test — yeni mesaj bildirimi calisiyor mu?');" >/dev/null && echo "  ok"

echo "[2] Zil bildirimi (bi_bildirim) ekleniyor..."
$PSQL -c "INSERT INTO bi_bildirim (tenant_id,user_id,baslik,govde,tip,data) VALUES ('$TEN','$MGR','💬 Yeni mesaj','Uğur Yıldız: Test — yeni mesaj bildirimi','mesaj','{\"room\":\"saha\",\"type\":\"mesaj\",\"konusma_id\":\"$KON\"}'::jsonb);" >/dev/null && echo "  ok"

echo "[3] Push token'lari cekiliyor..."
$PSQL -t -A -c "SELECT COALESCE(json_agg(json_build_object('token',token,'platform',platform)),'[]') FROM bi_push_token WHERE user_id='$MGR';" > _toks.json
echo -n "  token json (ilk 80): "; head -c 80 _toks.json; echo

CID="$(docker compose ps -q krb-assessment)"
echo "[4] Script + token'lar container'a kopyalaniyor..."
docker cp push_test.mjs "$CID":/tmp/push_test.mjs
docker cp _toks.json "$CID":/tmp/_toks.json
echo "[5] GERCEK push gonderiliyor (telefonlara)..."
docker exec "$CID" node /tmp/push_test.mjs /tmp/_toks.json "💬 Yeni mesaj" "Uğur Yıldız: Test bildirimi 🚀"
rm -f _toks.json
echo "[BITTI] Telefonda bildirim gormelisin. Uygulamada Mesajlar -> Ugur 'yeni'; zil 🔔 dolu."
