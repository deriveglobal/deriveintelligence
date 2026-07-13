#!/usr/bin/env bash
# Salt okuma. Onarim sonrasi 5 asiri negatif satir kaldi (1 bayilik + 4 net alim).
# Ortalamayi suruklüyorlar. birim x miktar = satir_tutar TUTUYOR ama ikisi de kucuk.
# NE BUNLAR: numune? duzeltme? garanti? iade?
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ ASIRI NEGATIF 5 SATIR (marj < -%50, son 60 gun) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT f.fatura_no, f.musteri_adi, f.marka, f.ebat,
       f.miktar, round(f.birim_fiyat,2) AS satis_birim,
       round(son.ikame) AS ikame_maliyet,
       round(f.satir_tutar,2) AS satir_tutar,
       round(100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0)) AS marj,
       f.fatura_tarihi
  FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
   AND f.fatura_tarihi >= CURRENT_DATE - 60
   AND 100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0) < -50
 ORDER BY 9 ASC;"
echo "  ^ miktar 1 + kurusluk fiyat -> NUMUNE / GARANTI / DUZELTME satiri."
echo "    Gercek satis degil. Ortalamayi bozar, medyani bozmaz."

echo
echo "############ AYNI SORU, TUM YIL ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT count(*) AS asiri_negatif_satir,
       round(sum(f.satir_tutar)) AS toplam_ciro_TL,
       round(min(f.birim_fiyat),2) AS en_dusuk_satis_TL,
       round(max(f.birim_fiyat),2) AS en_yuksek_satis_TL
  FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
   AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   AND 100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0) < -50;"
echo "  ^ Ciro'ya oraninin ONEMSIZ oldugunu gormek istiyorum."

echo
echo "############ ⚠ SAGLIK KARNESI — onarim sonrasi gercek tablo ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
m AS (
  SELECT f.satir_tutar,
         EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(f.marka)) AS bayilik,
         100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0) AS marj
    FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= CURRENT_DATE - 60
     AND 100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0) >= -50)
SELECT CASE WHEN bayilik THEN '🅑 BAYILIK (BRUT — prim haric, gercegi DAHA IYI)'
            ELSE '🅝 NET ALIM (gercek maliyet)' END AS sinif,
       count(*) AS satir,
       round(avg(marj)) AS ort_marj,
       round(percentile_cont(0.25) WITHIN GROUP (ORDER BY marj)::numeric) AS q1,
       round(percentile_cont(0.5)  WITHIN GROUP (ORDER BY marj)::numeric) AS medyan,
       round(percentile_cont(0.75) WITHIN GROUP (ORDER BY marj)::numeric) AS q3,
       round(sum(satir_tutar)/1e6,1) AS ciro_MTL
  FROM m GROUP BY 1 ORDER BY 1;"
echo "  ^ 5 aykiri satir HARIC. Ortalama artik medyana yakin olmali."
echo "    ⚠ BAYILIK marji BRUT: 33,5M prim dusulmemis. GERCEK MARJ DAHA YUKSEK."
