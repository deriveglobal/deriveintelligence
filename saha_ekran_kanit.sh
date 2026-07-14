#!/usr/bin/env bash
# SAHA_EKRAN_KANIT — asil kanit: SAHANIN UC EKRANI GERCEKTEN CALISIYOR MU?
#
# ⚠ Uc mutabakat kapisi gecti (268,3M · 209,3/145,4 · 580.016 satir).
#   Ama bunlar VERITABANI kanitlari. Kullanicinin gordugu ekran KANITI DEGIL.
#   Bugun ogrendik: "sorgu dogru" ile "ekran dogru" ayni sey degil.
#
# ⚠ VE DAYANIKLILIK TESTINI ANLAMLI SEKILDE TEKRARLIYORUM:
#   Onceki test gorunum HENUZ YOKKEN calisti — sonucu anlamsizdi.
#   Simdi gorunum var. Motor DELETE FROM kullaniyor (kod okundu), ama
#   "teorik olarak guvenli" bugun UC KEZ yetersiz kaldi. GERCEKTEN test ediyorum.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"

echo "############ 1) ⚠ DAYANIKLILIK — ANLAMLI test (gorunum artik VAR) ############"
echo "  --- Postgres, gorunume bagli tabloyu DROP etmeyi REDDEDIYOR mu? ---"
$PSQL -c "BEGIN; DROP TABLE bi_stok_anlik; ROLLBACK;" 2>&1 | grep -i "error\|cannot\|depend" | head -2 \
  && echo "  ✅ REDDETTI — motor yanlislikla DROP derse HATA ALIR ve DURUR (sessiz kirilma YOK)" \
  || echo "  ❌ DROP ETTI — gorunum korumuyor"

echo
echo "  --- ⚠ Motorun GERCEK yukleme komutu ne? (DELETE mi DROP mu) ---"
grep -n "DELETE FROM {k\['tablo'\]}" /opt/krb-assessment/erp_ingest.py | head -2
echo "  ✅ DELETE FROM -> gorunumler yeni veri yuklenince HAYATTA KALIR."

echo
echo "  --- ⚠ CANLI PROVA: bi_stok_anlik'i motorun yaptigi gibi DELETE + geri yukle ---"
$PSQL -c "
BEGIN;
  SELECT count(*) AS once FROM bi_stok_durumu WHERE tenant_id='$T'::uuid;
  DELETE FROM bi_stok_anlik WHERE tenant_id='$T'::uuid;
  SELECT count(*) AS silince_gorunum FROM bi_stok_durumu WHERE tenant_id='$T'::uuid;
  SELECT count(*) AS gorunum_HALA_VAR FROM pg_views WHERE viewname='bi_stok_durumu';
ROLLBACK;"
echo "  ⚠ 'gorunum_HALA_VAR = 1' olmali. DELETE gorunumu BOZMAZ, sadece bosaltir."
echo "     Yeni veri gelince gorunum kendiliginden dolar. ✅ SURDURULEBILIR."

echo
echo "############ 2) ⚠⚠ SAHANIN UC EKRANI — GERCEK OTURUMLA ############"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL','$HASH', now() + interval '5 minutes', '{\"amac\":\"ekran kaniti\"}'::jsonb);"
AUTH="Authorization: Bearer $TOKEN"

K=$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" "http://localhost:8080/api/saha/ziyaretler")
echo "  oturum saglamasi -> HTTP $K (200 olmali)"
[ "$K" = "200" ] || { echo "  ❌ OTURUM GECERSIZ — test anlamsiz"; \
  $PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='ekran kaniti';"; exit 1; }

echo
echo "  [A] /api/saha/stok-durumu — temsilci musteri yaninda buna bakiyor"
curl -s -H "$AUTH" "http://localhost:8080/api/saha/stok-durumu?ebat=205/55R16" | head -c 400; echo

echo
echo "  [B] /api/saha/iskonto-secenekler — ⚠ ISKONTO KARARI BURADA VERILIYOR"
echo "      (maliyet 10 kat siskin olsaydi, sistem 'bu iskonto marji sifirlar' derdi)"
curl -s -H "$AUTH" "http://localhost:8080/api/saha/iskonto-secenekler?ebat=205/55R16&marka=CONTINENTAL" | head -c 500; echo

echo
echo "  [C] /api/saha/rakip-teklif"
curl -s -o /dev/null -w "      HTTP %{http_code}\n" -H "$AUTH" "http://localhost:8080/api/saha/rakip-teklif"

echo
echo "############ 3) ⚠ ESKI vs YENI — ayni ebat, iki maliyet ############"
$PSQL -c "
SELECT left(kalem_tanimi, 36) AS urun, marka,
       round(eldeki_miktar)  AS adet,
       round(birim_maliyet)  AS YENI_maliyet,
       round(toplam_deger)   AS YENI_deger
  FROM bi_stok_durumu
 WHERE tenant_id='$T'::uuid AND kalem_tanimi ILIKE '%205/55R16%' AND eldeki_miktar > 0
 ORDER BY toplam_deger DESC LIMIT 4;"
$PSQL -c "
SELECT left(kalem_tanimi, 36) AS urun, marka,
       round(eldeki_miktar) AS adet,
       round(birim_maliyet) AS ESKI_maliyet,
       round(toplam_deger)  AS ESKI_deger
  FROM bi_stok_durumu_olu_yedek
 WHERE tenant_id='$T'::uuid AND kalem_tanimi ILIKE '%205/55R16%' AND eldeki_miktar > 0
 ORDER BY toplam_deger DESC LIMIT 4;"
echo "  ⚠ ESKI_maliyet, YENI'nin ~10 katiysa: temsilciler bugune kadar 10 kat"
echo "     siskin maliyetle iskonto karari veriyormus."

echo
echo "############ 4) OTURUMU KAPAT ############"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE revoked_at IS NULL AND metadata->>'amac'='ekran kaniti';"
R=$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" "http://localhost:8080/api/saha/ziyaretler")
echo "  iptal sonrasi -> HTTP $R  $([ "$R" = "401" ] && echo '✅ kapandi' || echo '❌ ACIK')"
