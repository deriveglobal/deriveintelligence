#!/usr/bin/env bash
# DOVIZ_V1 — birim_fiyat DOVIZ cinsinden, satir_tutar TL. TL'ye cevir.
#
# ⚠ ONCEKI DENEME GERI ALINDI (dogru davrandi):
#     UPDATE 2712 -> "RED: 6 satir hala bozuk" -> ROLLBACK. DB DEGISMEDI.
#   SEBEP: birim = round(satir_tutar/miktar, 4). satir_tutar cok kucuk +
#     miktar cok buyukse sonuc 0.0000'a yuvarlanip carpim tutmuyor.
#     Tolerans YUZDESEL oldugu icin kurusluk satirlarda %100 sapma gorunuyor.
#   COZUM: 6 haneye yuvarla + toleransa MUTLAK TABAN (1 kurus) koy.
#
# KANIT — bunlar bozuk veri DEGIL, YABANCI PARA faturalari:
#   241,14 -> 9.961,18  = x41,3   (22.09.2025)
#   230,20 -> 9.509,10  = x41,3   (22.09.2025)   <- ayni gun, AYNI ORAN
#   345,43 -> 18.249,98 = x52,8   (05.05.2026)
#   338,80 -> 17.900,01 = x52,8   (05.05.2026)   <- ayni gun, AYNI ORAN
#   6.720  -> 194.812   = x29,0   (04.09.2023)
#   548    -> 10.201,90 = x18,6   (08.12.2022)
#   2022:18,6 · 2023:29,0 · 2025:41,3 · 2026:52,8 -> BU DOVIZ KURU.
#
# ⚠ 338,80 x 60 adet, 05.05.2026 = ZEYMIR COMPANY DOO / fatura 187387.
#   Gunlerdir "1M TL'lik aykiri deger" diye kovaladigimiz sey.
#   Veri hatasi degilmis: EURO cinsinden IHRACAT satisi. Biz TL sanmisiz.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ DIRENEN 6 SATIR — bunlar ne? ############"
$PSQL -c "
SELECT id, kalem_kodu, left(kalem_tanimi,26) AS kalem,
       miktar, birim_fiyat, satir_tutar,
       satir_tutar/NULLIF(miktar,0) AS hesaplanan_birim, fatura_tarihi
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
   AND abs(birim_fiyat*miktar - satir_tutar) > 0.02*abs(satir_tutar)
   AND abs(satir_tutar) < 100
 ORDER BY abs(satir_tutar) LIMIT 10;"
echo "  ^ satir_tutar kuruş seviyesinde -> yuvarlama tabani gerekiyor."

echo
echo "############ 2) KUR DAGILIMI — hipotezi bir kez daha dogrula ############"
$PSQL -c "
SELECT EXTRACT(YEAR FROM fatura_tarihi)::int AS yil,
       count(*) AS satir,
       round(percentile_cont(0.5) WITHIN GROUP (
             ORDER BY satir_tutar/NULLIF(miktar,0)/NULLIF(birim_fiyat,0))::numeric,1) AS ima_edilen_kur,
       round(min(satir_tutar/NULLIF(miktar,0)/NULLIF(birim_fiyat,0))::numeric,1) AS min_kur,
       round(max(satir_tutar/NULLIF(miktar,0)/NULLIF(birim_fiyat,0))::numeric,1) AS max_kur
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0 AND birim_fiyat > 0
   AND abs(birim_fiyat*miktar - satir_tutar) > 0.02*abs(satir_tutar)
   AND abs(satir_tutar) >= 100
 GROUP BY 1 ORDER BY 1;"
echo "  ^ Yillara gore ARTAN ve yil ICINDE DAR bir bantsa -> KUR. Hipotez saglam."
echo "    Rastgele dagilmissa -> DUR, baska bir sey var."

if [ "${1:-}" != "--yaz" ]; then
  echo
  echo "  KURU CALISMA. Yazmak icin: ./deploy_doviz.sh --yaz"
  exit 0
fi

echo
echo "############ 3) ONAR ############"
DAMGA=$(date +%Y%m%d_%H%M%S)
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
-- ⚠ Yedek: eski (DOVIZ cinsi) birim fiyat KAYBOLMUYOR.
CREATE TABLE bi_satis_doviz_yedek_${DAMGA} AS
  SELECT id, birim_fiyat AS doviz_birim_fiyat, miktar, satir_tutar, fatura_tarihi,
         round((satir_tutar/NULLIF(miktar,0)/NULLIF(birim_fiyat,0))::numeric,4) AS ima_edilen_kur,
         now() AS yedek_zamani
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
     AND abs(birim_fiyat*miktar - satir_tutar) > greatest(0.02*abs(satir_tutar), 0.01);

UPDATE bi_satis_faturalari
   SET birim_fiyat = round((satir_tutar / miktar)::numeric, 6)
 WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
   AND abs(birim_fiyat*miktar - satir_tutar) > greatest(0.02*abs(satir_tutar), 0.01);

DO \$\$
DECLARE kalan int; yedek int;
BEGIN
  SELECT count(*) INTO yedek FROM bi_satis_doviz_yedek_${DAMGA};
  SELECT count(*) INTO kalan FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND miktar > 0 AND satir_tutar <> 0
     AND abs(birim_fiyat*miktar - satir_tutar) > greatest(0.02*abs(satir_tutar), 0.01);
  RAISE NOTICE 'yedeklenen: % satir', yedek;
  IF kalan > 0 THEN RAISE EXCEPTION 'RED: % satir hala bozuk', kalan; END IF;
  RAISE NOTICE '✅ tum satirlar tutarli';
END \$\$;
COMMIT;
SQL
echo "  yedek: bi_satis_doviz_yedek_${DAMGA}"

echo
echo "############ 4) DOGRULAMA ############"
echo "   -- 584010 (12.00R24 BRIDGESTONE): 1128 -> 59.829 olmali --"
$PSQL -c "
SELECT kalem_kodu, ebat, miktar, birim_fiyat, satir_tutar
  FROM bi_satis_faturalari WHERE tenant_id='$TEN' AND kalem_kodu='584010'
 ORDER BY fatura_tarihi DESC LIMIT 3;"

echo "   -- ZEYMIR / 385/65R22.5 x60 (05.05.2026): 338,80 -> 17.900 olmali --"
$PSQL -c "
SELECT musteri_adi, ebat, miktar, birim_fiyat, satir_tutar, fatura_tarihi
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND kalem_kodu='656876' AND fatura_tarihi='2026-05-05';"

echo "   -- ⚠ CIRO DEGISMEMELI (satir_tutar'a DOKUNMADIK) --"
$PSQL -c "
SELECT round(sum(satir_tutar)/1e6,2) AS haziran2026_MTL
  FROM bi_satis_faturalari WHERE tenant_id='$TEN'
   AND fatura_tarihi >= DATE '2026-06-01' AND fatura_tarihi < DATE '2026-07-01';"
echo "  ^ 121,76 olmali (Fatih Bilen'in SAP rakami). Degistiyse DUR."

echo
echo "############ 5) MARJ — simdi ne diyor? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
m AS (
  SELECT EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(f.marka)) AS bayilik,
         100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0) AS marj
    FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= CURRENT_DATE - 60)
SELECT CASE WHEN bayilik THEN '🅑 BAYILIK (BRUT — prim haric)' ELSE '🅝 NET ALIM (gercek)' END AS sinif,
       count(*) AS satir,
       round(avg(marj)) AS ort_marj,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY marj)::numeric) AS medyan_marj,
       count(*) FILTER (WHERE marj < -50) AS asiri_negatif
  FROM m GROUP BY 1 ORDER BY 1;"
echo "  ^ 'asiri_negatif' 0'a yakin olmali. ort_marj artik -244 OLMAMALI."

git add -A && git commit -q -m "fix(veri): DOVIZ_V1 — 2712 satirda birim_fiyat doviz cinsindeydi (satir_tutar TL). TL'ye cevrildi; ima edilen kur yillara gore 18,6->29,0->41,3->52,8. ZEYMIR COMPANY DOO 339 TL aykiri degeri cozuldu: EUR cinsinden ihracat satisi. Doviz fiyati yedek tabloda saklandi. satir_tutar'a DOKUNULMADI -> ciro degismedi." && echo "  COMMITTED"

echo
echo "✅ Geri alma:"
echo "   UPDATE bi_satis_faturalari f SET birim_fiyat = y.doviz_birim_fiyat"
echo "     FROM bi_satis_doviz_yedek_${DAMGA} y WHERE y.id = f.id;"
