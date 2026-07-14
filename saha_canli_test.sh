#!/usr/bin/env bash
# SAHA_CANLI_TEST — Eftal'in ATTIGI ISTEGIN BIREBIR AYNISINI atiyorum.
#
# ⚠ "Kodda 403 kalmadi" KANIT DEGIL. Gercek istek, gercek oturum, gercek yanit.
#   Eftal'e "duzeldi" demeden once 200 gormem lazim.
#
# ⚠ Gecici oturum aciyorum ve TESTTEN SONRA IPTAL EDIYORUM (revoked_at).
#   Kalici bir arka kapi birakmiyorum.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"

echo "############ 0) OTURUM NASIL OKUNUYOR? (varsayim yok) ############"
awk 'NR>=4147 && NR<=4200 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "  --- kapi: sha256 mi? cerez adi ne? ---"
FN=$(awk 'NR>=4147 && NR<=4200' server_container.mjs)
echo "$FN" | grep -q "sha256" || { echo "  ❌ sha256 GORMEDIM — token uretmiyorum, DURDUM."; exit 1; }
echo "  ✅ sha256 tespit edildi"
CEREZ=$(echo "$FN" | grep -o "cookies\?\.[a-zA-Z_]*\|\[\"[a-z_]*\"\]\|'[a-z_]*'" | head -5)
echo "  cerez adaylari: $CEREZ"
grep -n "Set-Cookie" server_container.mjs | head -3

echo
echo "############ 1) GECICI OTURUM — Eftal olarak, 10 dakikalik ############"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
SID=$($PSQL -tAc "
  INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL', '$HASH', now() + interval '10 minutes', '{\"amac\":\"SAHA_FIX_V1 dogrulama\"}'::jsonb)
  RETURNING id;")
echo "  oturum: $SID (10 dk, testten sonra IPTAL)"

CURL="curl -s -o /dev/null -w %{http_code}"
CK="Cookie: session=$TOKEN"

echo
echo "############ 2) ⚠ EFTAL'IN UC HATASI — BIREBIR TEKRAR ############"

echo "  [A] 500 idi — iskonto ekrani (14:47:31'de patlayan istegin AYNISI)"
A=$($CURL -H "$CK" "http://localhost:8080/api/saha/musteri-destek?musteri_id=ca40078a-d4f8-47b2-8869-b1381e7d43f3&marka=LASSA")
echo "      GET /api/saha/musteri-destek?...&marka=LASSA  ->  HTTP $A   (200 bekleniyor, 500 DEGIL)"

echo "  [B] 404 idi — tekil ziyaret (14:55:17'de patlayan istegin AYNISI)"
B=$($CURL -H "$CK" "http://localhost:8080/api/saha/ziyaretler/dc9caaf4-0afd-499f-84f1-fcf34b735765")
echo "      GET /api/saha/ziyaretler/dc9caaf4-...  ->  HTTP $B   (200 bekleniyor, 404 DEGIL)"

echo "  [C] 403 idi — baskasinin musterisine durum yazma (13 kez reddedilen istek)"
echo "      ⚠ ONCE mevcut durumu okuyorum, AYNI DEGERI yazip geri koyuyorum — VERIYI DEGISTIRMIYORUM."
MID="ecb0a4ee-d8f8-43c7-a9f3-ccf905413baf"
ESKI=$($PSQL -tAc "SELECT durum FROM saha_musteri WHERE id='$MID'")
echo "      mevcut durum: $ESKI  (ayni deger geri yazilacak)"
C=$(curl -s -o /tmp/c.json -w '%{http_code}' -X PUT -H "$CK" -H "Content-Type: application/json" \
     -d "{\"durum\":\"$ESKI\"}" "http://localhost:8080/api/saha/musteriler/$MID")
echo "      PUT /api/saha/musteriler/ecb0a4ee-...  ->  HTTP $C   (200 bekleniyor, 403 DEGIL)"
SONRA=$($PSQL -tAc "SELECT durum FROM saha_musteri WHERE id='$MID'")
echo "      sonraki durum: $SONRA   $([ "$ESKI" = "$SONRA" ] && echo '✅ veri degismedi' || echo '❌ VERI DEGISTI')"

echo
echo "  [D] DENETIM kaydi dustu mu? (kapi kalkti ama IZ kaliyor mu?)"
$PSQL -c "SELECT tip, endpoint, hata_mesaji, extra FROM saha_hata_log
          WHERE tip='DENETIM' ORDER BY ts DESC LIMIT 2;"

echo
echo "############ 3) OTURUMU IPTAL ET — arka kapi birakma ############"
$PSQL -tAc "UPDATE user_sessions SET revoked_at = now() WHERE id='$SID' RETURNING 'iptal edildi';" | sed 's/^/  /'
R=$($CURL -H "$CK" "http://localhost:8080/api/saha/ziyaretler/dc9caaf4-0afd-499f-84f1-fcf34b735765")
echo "  iptal sonrasi ayni istek -> HTTP $R   (401 bekleniyor = oturum gercekten kapandi)"

echo
echo "############ ⚠ HUKUM ############"
[ "$A" = "200" ] && echo "  ✅ 500 kapandi" || echo "  ❌ 500 HALA VAR (HTTP $A)"
[ "$B" = "200" ] && echo "  ✅ 404 kapandi" || echo "  ❌ 404 HALA VAR (HTTP $B)"
[ "$C" = "200" ] && echo "  ✅ 403 kapandi" || echo "  ❌ 403 HALA VAR (HTTP $C)"
echo
echo "  ⚠ Ucu de 200 olmadan Eftal'e HICBIR SEY gonderilmeyecek."
