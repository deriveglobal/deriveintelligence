#!/usr/bin/env bash
# SILME_TESTI_2 — ayni tuzaga IKINCI KEZ dustum.
#
# ⚠ psql -tAc ile "INSERT ... RETURNING id" cagirinca ciktida IKI SATIR var:
#     f7e7dc3a-...
#     INSERT 0 1
#   tr -d ' ' bosluğu siler ama SATIR SONUNU SILMEZ -> uuid bozuk.
#   Bugun zincir_kanit.sh'de de ayni seye dusmustum. Bu sefer: | head -1 | tr -d '[:space:]'
#
# ⚠ VE IKI TEST ZIYARETI VERITABANINDA KALDI (2422 vs 2420). Once TEMIZLIK.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"

echo "############ 0) ⚠ ONCEKI TESTIN ARTIKLARINI TEMIZLE ############"
$PSQL -c "SELECT id, ziyaret_tarihi, left(notlar,40) FROM saha_ziyaret WHERE notlar LIKE 'TEST KAYDI%';"
$PSQL -c "DELETE FROM saha_ziyaret       WHERE notlar LIKE 'TEST KAYDI%';"
$PSQL -c "DELETE FROM saha_ziyaret_silinen WHERE notlar LIKE 'TEST KAYDI%';"
$PSQL -c "SELECT count(*) AS ziyaret FROM saha_ziyaret;"
echo "  ⚠ 2420 olmali."

echo
echo "############ 1) OTURUM ############"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL','$HASH', now() + interval '5 minutes', '{\"amac\":\"silme e2e\"}'::jsonb);"
A="Authorization: Bearer $TOKEN"
K=$(curl -s -o /dev/null -w '%{http_code}' -H "$A" http://localhost:8080/api/saha/ziyaretler)
echo "  oturum: HTTP $K"
[ "$K" = "200" ] || { echo "  ❌ oturum gecersiz"; exit 1; }

MUS=$($PSQL -tAc "SELECT id FROM saha_musteri WHERE tenant_id='$T' AND sorumlu_rep='$EFTAL' AND aktif LIMIT 1" | head -1 | tr -d '[:space:]')
echo "  test musterisi: $MUS"

# ⚠ DOGRU OKUMA: head -1 + tum bosluklari sil
yeni_ziyaret() {
  $PSQL -tAc "
    INSERT INTO saha_ziyaret (tenant_id, musteri_id, rep_id, tip, durum, ziyaret_tarihi, notlar, created_by)
    VALUES ('$T','$MUS','$EFTAL','TUKETICI','TAMAMLANDI', CURRENT_DATE - $1,
            'TEST KAYDI — silme testi, silinecek.', '$EFTAL')
    RETURNING id;" | head -1 | tr -d '[:space:]'
}

echo
echo "############ 2) BUGUNKU ZIYARET — SILINEBILMELI ############"
Z1=$(yeni_ziyaret 0)
echo "  olusturuldu: [$Z1]"
echo "  --- onizleme ---"
curl -s -H "$A" "http://localhost:8080/api/saha/ziyaretler/$Z1/silme-onizleme" | python3 -m json.tool

echo "  --- SIL ---"
curl -s -o /dev/null -w "      DELETE -> HTTP %{http_code}   (200 bekleniyor)\n" -X DELETE -H "$A" \
  "http://localhost:8080/api/saha/ziyaretler/$Z1"

echo "  --- ⚠ GITTI MI? ---"
$PSQL -c "SELECT count(*) AS ziyarette FROM saha_ziyaret WHERE id='$Z1';"
echo "      (0 olmali)"
echo "  --- ⚠ ARSIVDE VAR MI? (sessiz kayip OLMAMALI) ---"
$PSQL -c "SELECT count(*) AS arsivde, max(silen_adi) AS silen FROM saha_ziyaret_silinen WHERE id='$Z1';"
echo "      (1 olmali)"
echo "  --- ⚠ DENETIM IZI ---"
$PSQL -x -c "SELECT eylem, varlik, detay FROM saha_denetim WHERE varlik_id='$Z1';"

echo
echo "############ 3) 5 GUN ONCEKI ZIYARET — REDDEDILMELI ############"
Z2=$(yeni_ziyaret 5)
echo "  olusturuldu: [$Z2]"
echo "  --- onizleme (silebilir: false bekleniyor) ---"
curl -s -H "$A" "http://localhost:8080/api/saha/ziyaretler/$Z2/silme-onizleme" | python3 -m json.tool

echo "  --- SILMEYE CALIS (403 bekleniyor) ---"
curl -s -w "\n      HTTP %{http_code}\n" -X DELETE -H "$A" \
  "http://localhost:8080/api/saha/ziyaretler/$Z2" | sed 's/^/      /'

echo "  --- ⚠ HALA DURUYOR MU? ---"
$PSQL -c "SELECT count(*) AS hala_duruyor FROM saha_ziyaret WHERE id='$Z2';"
echo "      (1 olmali — 0 ise ZAMAN KAPISI CALISMIYOR)"

echo
echo "############ 4) TEMIZLIK ############"
$PSQL -c "DELETE FROM saha_ziyaret         WHERE notlar LIKE 'TEST KAYDI%';"
$PSQL -c "DELETE FROM saha_ziyaret_silinen WHERE notlar LIKE 'TEST KAYDI%';"
$PSQL -c "DELETE FROM saha_denetim WHERE eylem='ZIYARET_SIL' AND varlik_id IN ('$Z1','$Z2');"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='silme e2e';"

echo
echo "############ 5) ⚠ SON DURUM — test kendi izini birakmamali ############"
$PSQL -c "SELECT count(*) AS ziyaret FROM saha_ziyaret;"
$PSQL -c "SELECT count(*) AS arsiv FROM saha_ziyaret_silinen;"
$PSQL -c "SELECT count(*) AS test_artigi FROM saha_ziyaret WHERE notlar LIKE 'TEST KAYDI%';"
echo "  ⚠ ziyaret 2420 · arsiv 0 · test_artigi 0 olmali."
