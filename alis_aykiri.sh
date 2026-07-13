#!/usr/bin/env bash
# Salt okuma. ⚠ Ayni kalemde ort. zam %279,8 ama medyan %19.
#   Medyan saglam -> yani birkac kalem ASIRI ucuyor. NEDEN?
#
# HIPOTEZLER:
#   H1) x10.000 virgul bozulmasi ALIS verisinde hayatta kalmis
#       (satis'ta duzelttik; alis ayri dosyadan geldi)
#   H2) Ambalaj/adet degisikligi (1 adet -> 4'lu set)
#   H3) Gercek zam (doviz kurlu is makinesi lastigi vs)
#   H4) Iade/duzeltme faturasi negatif ya da sacma birim fiyatla
#
# ⚠ Onemli: eger H1 ise IKAME MALIYETI de bozuk demektir --
#   yani dun kurdugumuz kademe 2 bazi kalemlerde 10.000 kat yanlis maliyet verir.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) EN UC 20 KALEM — ne olmus? ############"
$PSQL -c "
WITH eski AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS f_eski,
         fatura_tarihi AS t_eski, miktar AS m_eski, satir_kdv_haric AS s_eski
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
     AND fatura_tarihi < CURRENT_DATE - 180
   ORDER BY kalem_kodu, fatura_tarihi DESC),
yeni AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS f_yeni,
         fatura_tarihi AS t_yeni, miktar AS m_yeni, satir_kdv_haric AS s_yeni, marka, kalem_tanimi
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
     AND fatura_tarihi >= CURRENT_DATE - 90
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT y.marka, left(y.kalem_tanimi, 26) AS kalem,
       round(e.f_eski) AS eski_TL, e.t_eski,
       round(y.f_yeni) AS yeni_TL, y.t_yeni,
       round(100.0*(y.f_yeni - e.f_eski)/NULLIF(e.f_eski,0)) AS zam_pct,
       round(y.f_yeni / NULLIF(e.f_eski,0), 1) AS KAT
  FROM eski e JOIN yeni y ON y.kalem_kodu = e.kalem_kodu
 ORDER BY (y.f_yeni / NULLIF(e.f_eski,0)) DESC NULLS LAST LIMIT 20;"
echo "  ^ KAT ~10000 ise: VIRGUL BOZUKLUGU (H1) — CIDDI."
echo "    KAT 2-5 arasi ise: gercek zam / ambalaj (H2,H3) — normal."

echo
echo "############ 2) ⚠ H1 TESTI — alis verisinde x10.000 izi var mi? ############"
echo "   Kontrol: birim_fiyat x miktar = satir_tutar TUTUYOR mu?"
$PSQL -c "
SELECT CASE WHEN abs(birim_fiyat_kdv_haric * miktar - satir_kdv_haric)
              <= 0.02 * abs(NULLIF(satir_kdv_haric,0)) THEN '✅ TUTARLI'
            ELSE '❌ TUTMUYOR' END AS durum,
       count(*) AS satir,
       round(100.0*count(*)/sum(count(*)) OVER (),2) AS pct
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND miktar > 0 AND satir_kdv_haric <> 0
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ^ Bu KAPI erp_donustur.py'de %95 esigiyle gecmisti."
echo "    ❌ oran YUKSEKSE ikame maliyeti de bozuk demektir."

echo
echo "############ 3) SACMA BIRIM FIYATLAR — mutlak esik ############"
$PSQL -c "
SELECT CASE WHEN birim_fiyat_kdv_haric <  50      THEN 'a) < 50 TL      ❌ lastik olamaz'
            WHEN birim_fiyat_kdv_haric < 100000   THEN 'b) 50-100.000   ✅ makul'
            WHEN birim_fiyat_kdv_haric < 1000000  THEN 'c) 100k-1M      ⚠ is makinesi olabilir'
            ELSE                                       'd) > 1.000.000  ❌ supheli' END AS bant,
       count(*) AS satir,
       round(min(birim_fiyat_kdv_haric)) AS min_TL,
       round(max(birim_fiyat_kdv_haric)) AS max_TL
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   AND grup_adi LIKE 'LASTIK%'
 GROUP BY 1 ORDER BY 1;"

echo
echo "############ 4) '< 50 TL' olanlar KIM? (varsa) ############"
$PSQL -c "
SELECT marka, left(kalem_tanimi,30) AS kalem, miktar,
       birim_fiyat_kdv_haric AS birim_TL, satir_kdv_haric AS satir_TL,
       fatura_tarihi, tedarikci_adi
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND grup_adi LIKE 'LASTIK%'
   AND birim_fiyat_kdv_haric > 0 AND birim_fiyat_kdv_haric < 50
 ORDER BY fatura_tarihi DESC LIMIT 10;"
echo "  ^ Bunlar IKAME MALIYETI olarak kullanilirsa marj %99 gorunur."

echo
echo "############ 5) ⚠ BU YIL SATILANLARDA sacma maliyet var mi? (asil risk) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT f.marka, f.ebat,
       round(son.maliyet) AS ikame_maliyet_TL,
       round(avg(f.birim_fiyat)) AS ort_satis_TL,
       round(100.0*(avg(f.birim_fiyat) - son.maliyet)/NULLIF(avg(f.birim_fiyat),0)) AS gorunen_marj_pct,
       count(*) AS satis_satiri
  FROM bi_satis_faturalari f
  JOIN son ON son.kalem_kodu = f.kalem_kodu
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
   AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
 GROUP BY 1,2,3
HAVING 100.0*(avg(f.birim_fiyat) - son.maliyet)/NULLIF(avg(f.birim_fiyat),0) > 80
    OR 100.0*(avg(f.birim_fiyat) - son.maliyet)/NULLIF(avg(f.birim_fiyat),0) < -20
 ORDER BY 6 DESC LIMIT 15;"
echo "  ^ %80+ marj = maliyet muhtemelen BOZUK (lastikte olmaz)."
echo "    Negatif marj = ya gercek zarar ya bozuk maliyet. IKISI DE onemli."
