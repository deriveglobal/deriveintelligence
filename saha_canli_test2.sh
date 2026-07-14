#!/usr/bin/env bash
# SAHA_CANLI_TEST_2 — kapi beni durdurdu, DOGRU calisti.
# ⚠ Ilk denemede iki sey yanlisti:
#   ✗ Cerez sandim — kimlik  Authorization: Bearer  ile tasiniyor (getBearerToken).
#   ✗ sha256'yi getSessionUser icinde aradim — o hashToken() icinde.
# Bu sefer HER IKISINI DE DOSYADAN okuyup dogruluyorum, sonra token uretiyorum.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"

echo "############ 0) hashToken + getBearerToken — VARSAYIM YOK ############"
grep -n "function hashToken\|function getBearerToken" server_container.mjs
for F in hashToken getBearerToken; do
  L=$(grep -n "function $F" server_container.mjs | head -1 | cut -d: -f1)
  awk -v s="$L" 'NR>=s && NR<=s+12 { printf "%5d| %s\n", NR, $0 }' server_container.mjs
  echo
done

HB=$(L=$(grep -n "function hashToken" server_container.mjs | head -1 | cut -d: -f1); awk -v s="$L" 'NR>=s && NR<=s+12' server_container.mjs)
echo "$HB" | grep -q "sha256" || { echo "❌ hashToken sha256 DEGIL — token uretmiyorum, DURDUM."; exit 1; }
echo "$HB" | grep -q "hex"    || { echo "❌ hashToken hex DEGIL (base64?) — DURDUM."; exit 1; }
echo "  ✅ hashToken = sha256 + hex  -> token uretebilirim"

echo
echo "############ 1) GECICI OTURUM — Eftal, 10 dk, sonunda IPTAL ############"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
SID=$($PSQL -tAc "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL','$HASH', now() + interval '10 minutes', '{\"amac\":\"SAHA_FIX_V1 dogrulama\"}'::jsonb)
  RETURNING id;")
echo "  oturum: $SID"
AUTH="Authorization: Bearer $TOKEN"

# ⚠ once oturumun GERCEKTEN gecerli oldugunu kanitla — yoksa 401'i "duzeldi" saniriz
K=$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" "http://localhost:8080/api/saha/ziyaretler")
echo "  oturum saglamasi: GET /api/saha/ziyaretler -> HTTP $K  (200 olmali)"
[ "$K" = "200" ] || { echo "  ❌ OTURUM GECERSIZ — test anlamsiz, DURDUM."; \
  $PSQL -tAc "UPDATE user_sessions SET revoked_at=now() WHERE id='$SID';" >/dev/null; exit 1; }

echo
echo "############ 2) ⚠ EFTAL'IN UC HATASI — BIREBIR TEKRAR ############"
CURL="curl -s -o /dev/null -w %{http_code}"

echo "  [A] 500 idi — iskonto (14:47:31'deki istegin AYNISI)"
A=$($CURL -H "$AUTH" "http://localhost:8080/api/saha/musteri-destek?musteri_id=ca40078a-d4f8-47b2-8869-b1381e7d43f3&marka=LASSA")
echo "      -> HTTP $A   (200 bekleniyor)"

echo "  [B] 404 idi — tekil ziyaret (14:55:17'deki istegin AYNISI)"
B=$($CURL -H "$AUTH" "http://localhost:8080/api/saha/ziyaretler/dc9caaf4-0afd-499f-84f1-fcf34b735765")
echo "      -> HTTP $B   (200 bekleniyor)"

echo "  [C] 403 idi — baskasinin musterisine yazma (13 kez reddedilen istek)"
MID="ecb0a4ee-d8f8-43c7-a9f3-ccf905413baf"
ESKI=$($PSQL -tAc "SELECT durum FROM saha_musteri WHERE id='$MID'")
echo "      ⚠ mevcut durum '$ESKI' okundu — AYNI deger geri yazilacak, veri DEGISMEYECEK"
C=$(curl -s -o /tmp/c.json -w '%{http_code}' -X PUT -H "$AUTH" -H "Content-Type: application/json" \
     -d "{\"durum\":\"$ESKI\"}" "http://localhost:8080/api/saha/musteriler/$MID")
echo "      -> HTTP $C   (200 bekleniyor)"
[ "$C" != "200" ] && { echo "      yanit:"; cat /tmp/c.json; echo; }
SONRA=$($PSQL -tAc "SELECT durum FROM saha_musteri WHERE id='$MID'")
[ "$ESKI" = "$SONRA" ] && echo "      ✅ veri degismedi ('$SONRA')" || echo "      ❌ VERI DEGISTI: $ESKI -> $SONRA"

echo
echo "  [D] Kapi kalkti — IZ kaliyor mu? (DENETIM kaydi)"
$PSQL -c "SELECT to_char(ts,'HH24:MI:SS') saat, tip, hata_mesaji, extra
          FROM saha_hata_log WHERE tip='DENETIM' ORDER BY ts DESC LIMIT 2;"

echo
echo "############ 3) OTURUMU IPTAL ET ############"
$PSQL -tAc "UPDATE user_sessions SET revoked_at=now() WHERE id='$SID' RETURNING 'iptal edildi';" | sed 's/^/  /'
R=$($CURL -H "$AUTH" "http://localhost:8080/api/saha/ziyaretler")
echo "  iptal sonrasi -> HTTP $R  (401 bekleniyor = arka kapi YOK)"

echo
echo "############ ⚠ HUKUM ############"
[ "$A" = "200" ] && echo "  ✅ 500 (iskonto)      kapandi" || echo "  ❌ 500 HALA VAR -> $A"
[ "$B" = "200" ] && echo "  ✅ 404 (tekil ziyaret) kapandi" || echo "  ❌ 404 HALA VAR -> $B"
[ "$C" = "200" ] && echo "  ✅ 403 (yazma kapisi)  kapandi" || echo "  ❌ 403 HALA VAR -> $C"
echo "  ⚠ Ucu de 200 olmadan Eftal'e hicbir sey gonderilmeyecek."
