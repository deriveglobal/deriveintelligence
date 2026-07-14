#!/usr/bin/env bash
# SILME_TESTI — iki sey test edilmedi: (a) gercek silme calisiyor mu
#                                       (b) bir gunden eski ziyaret REDDEDILIYOR mu
#
# ⚠ GERCEK VERIYI SILEREK TEST ETMEM. Kendi test verimi yaratip onu silecegim.
#   Test bittiginde ortada hicbir sey kalmayacak.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"

echo "############ 0) OTURUM ############"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL','$HASH', now() + interval '5 minutes', '{\"amac\":\"silme e2e\"}'::jsonb);"
A="Authorization: Bearer $TOKEN"
K=$(curl -s -o /dev/null -w '%{http_code}' -H "$A" http://localhost:8080/api/saha/ziyaretler)
echo "  oturum: HTTP $K"
[ "$K" = "200" ] || { echo "  ❌ oturum gecersiz"; exit 1; }

MUS=$($PSQL -tAc "SELECT id FROM saha_musteri WHERE tenant_id='$T' AND sorumlu_rep='$EFTAL' AND aktif LIMIT 1" | tr -d ' ')

echo
echo "############ 1) TEST ZIYARETI-1 — BUGUN (silinebilmeli) ############"
Z1=$($PSQL -tAc "
INSERT INTO saha_ziyaret (tenant_id, musteri_id, rep_id, tip, durum, ziyaret_tarihi, notlar, created_by)
VALUES ('$T','$MUS','$EFTAL','TUKETICI','TAMAMLANDI', CURRENT_DATE,
        'TEST KAYDI — silme testi icin olusturuldu, silinecek.', '$EFTAL')
RETURNING id;" | tr -d ' ')
echo "  olusturuldu: $Z1"

echo "  --- onizleme ---"
curl -s -H "$A" "http://localhost:8080/api/saha/ziyaretler/$Z1/silme-onizleme" | python3 -m json.tool | grep -E "silebilir|gun|not_uzunluk|neden"

echo "  --- SIL ---"
curl -s -o /dev/null -w "      DELETE -> HTTP %{http_code}\n" -X DELETE -H "$A" \
  "http://localhost:8080/api/saha/ziyaretler/$Z1"

echo "  --- ⚠ GERCEKTEN GITTI MI? ---"
$PSQL -c "SELECT count(*) AS ziyarette FROM saha_ziyaret WHERE id='$Z1';"
echo "  --- ⚠ ARSIVDE VAR MI? (sessiz kayip OLMAMALI) ---"
$PSQL -c "SELECT count(*) AS arsivde, max(silen_adi) AS silen FROM saha_ziyaret_silinen WHERE id='$Z1';"
echo "  --- ⚠ DENETIM IZI DUSTU MU? ---"
$PSQL -x -c "SELECT eylem, varlik, detay FROM saha_denetim WHERE varlik_id='$Z1';"

echo
echo "############ 2) TEST ZIYARETI-2 — 5 GUN ONCE (REDDEDILMELI) ############"
Z2=$($PSQL -tAc "
INSERT INTO saha_ziyaret (tenant_id, musteri_id, rep_id, tip, durum, ziyaret_tarihi, notlar, created_by)
VALUES ('$T','$MUS','$EFTAL','TUKETICI','TAMAMLANDI', CURRENT_DATE - 5,
        'TEST KAYDI — zaman siniri testi.', '$EFTAL')
RETURNING id;" | tr -d ' ')
echo "  olusturuldu (5 gun once): $Z2"

echo "  --- onizleme (silebilir: false bekleniyor) ---"
curl -s -H "$A" "http://localhost:8080/api/saha/ziyaretler/$Z2/silme-onizleme" | python3 -m json.tool | grep -E "silebilir|gun|neden"

echo "  --- SILMEYE CALIS (403 bekleniyor) ---"
curl -s -w "\n      HTTP %{http_code}\n" -X DELETE -H "$A" \
  "http://localhost:8080/api/saha/ziyaretler/$Z2" | sed 's/^/      /'

echo "  --- ⚠ HALA DURUYOR MU? ---"
$PSQL -c "SELECT count(*) AS hala_duruyor FROM saha_ziyaret WHERE id='$Z2';"
echo "  ⚠ 1 olmali. 0 ise zaman kapisi CALISMIYOR."

echo
echo "############ 3) TEMIZLIK — test verisini kaldir ############"
$PSQL -c "DELETE FROM saha_ziyaret WHERE id='$Z2';"
$PSQL -c "DELETE FROM saha_ziyaret_silinen WHERE notlar LIKE 'TEST KAYDI%';"
$PSQL -c "DELETE FROM saha_denetim WHERE varlik_id='$Z1';"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='silme e2e';"
echo "  ✅ test verisi temizlendi"

echo
echo "############ 4) SON DURUM ############"
$PSQL -c "SELECT count(*) AS ziyaret FROM saha_ziyaret;"
$PSQL -c "SELECT count(*) AS arsiv FROM saha_ziyaret_silinen;"
echo "  ⚠ ziyaret 2420 olmali (test oncesiyle ayni). Arsiv 0."
