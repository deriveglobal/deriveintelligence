#!/usr/bin/env bash
# Salt okuma. ⚠ %37,2 ciro NEGATIF marjda gorunuyor (152,7M). Bu GERCEK mi?
#
# ZAMANLAMA YANLILIGI: yilin ORTALAMA satis fiyatini, EN SON alis fiyatiyla
#   kiyasliyorduk. Fiyatlar yil icinde arttiysa, Ocak'ta KARLI yapilmis bir
#   satis bugunun maliyetiyle ZARARLI gorunur. Bu ayrimi yapmadan
#   "KRB zararina satiyor" DIYEMEYIZ.
#
# IKI AYRI SORU:
#   A) "Para kazandik mi?"        -> satisi O GUNKU alis fiyatiyla kiyasla (BATIK)
#   B) "Bugun bu fiyata satarsak?" -> satisi BUGUNKU ikame maliyetiyle kiyasla
#
#   A dogruysa ve B negatifse: gecmiste kazandik, AMA fiyat listemiz geride kaldi.
#   Ikisi de negatifse: gercekten zararina satiyoruz.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) KAPI: satis birim_fiyat KDV HARIC mi? ############"
echo "   (alis birim_fiyat_kdv_haric. Elmayla elma kiyasliyor muyuz?)"
$PSQL -c "
SELECT round(avg(birim_fiyat)) AS ort_birim_fiyat,
       round(avg(satir_tutar / NULLIF(miktar,0))) AS ort_satir_bolu_miktar,
       round(avg(kdv_orani)::numeric,2) AS ort_kdv_orani
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0
   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE);" 2>&1 | head -6
echo "  ^ Iki sutun BIRBIRINE YAKINSA satir_tutar da KDV haric -> tutarli."

echo
echo "############ 1) ⚠⚠ SORU A — GECMISTE PARA KAZANDIK MI? (batik marj) ############"
echo "   Her satisi, O TARIHTEN ONCEKI EN SON alis fiyatiyla kiyasla."
$PSQL -c "
WITH s AS (
  SELECT f.kalem_kodu, f.fatura_tarihi, f.birim_fiyat, f.satir_tutar
    FROM bi_satis_faturalari f
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)),
m AS (
  SELECT s.satir_tutar,
         100.0*(s.birim_fiyat - a.birim_fiyat_kdv_haric)/NULLIF(s.birim_fiyat,0) AS marj
    FROM s
    JOIN LATERAL (
      SELECT t.birim_fiyat_kdv_haric
        FROM bi_tedarikci_faturalari t
       WHERE t.tenant_id='$TEN'::uuid AND t.kalem_kodu = s.kalem_kodu
         AND t.birim_fiyat_kdv_haric > 0
         AND t.fatura_tarihi <= s.fatura_tarihi
       ORDER BY t.fatura_tarihi DESC LIMIT 1) a ON true)
SELECT CASE WHEN marj <   0 THEN 'a) NEGATIF  ❌'
            WHEN marj <  10 THEN 'b) %0-10    ⚠'
            WHEN marj <  25 THEN 'c) %10-25   ✅'
            WHEN marj <  40 THEN 'd) %25-40   ✅'
            ELSE                 'e) %40+     ✅' END AS batik_marj_bandi,
       count(*) AS satir, round(sum(satir_tutar)/1e6,1) AS ciro_MTL,
       round(100.0*sum(satir_tutar)/sum(sum(satir_tutar)) OVER (),1) AS ciro_pct
  FROM m GROUP BY 1 ORDER BY 1;"
echo "  ^ BU, 'para kazandik mi' sorusunun cevabi. Zamanlama yanliligi YOK."

echo
echo "############ 2) ⚠⚠ SORU B — BUGUNKU FIYATLARLA satsak? (son 60 gun satis) ############"
echo "   Zamanlama yanliligini kaldirmak icin SADECE son 60 gunun satislari."
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
m AS (
  SELECT f.satir_tutar,
         100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0) AS marj
    FROM bi_satis_faturalari f
    JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= CURRENT_DATE - 60)
SELECT CASE WHEN marj <   0 THEN 'a) NEGATIF  ❌ bugun zararina'
            WHEN marj <  10 THEN 'b) %0-10    ⚠ cok ince'
            WHEN marj <  25 THEN 'c) %10-25   ✅'
            WHEN marj <  40 THEN 'd) %25-40   ✅'
            ELSE                 'e) %40+     ✅' END AS ikame_marj_bandi,
       count(*) AS satir, round(sum(satir_tutar)/1e6,1) AS ciro_MTL,
       round(100.0*sum(satir_tutar)/sum(sum(satir_tutar)) OVER (),1) AS ciro_pct
  FROM m GROUP BY 1 ORDER BY 1;"
echo "  ^ Bolum 1 SAGLAM + bolum 2 NEGATIF ise: gecmiste kazandik ama"
echo "    FIYAT LISTEMIZ GERIDE KALDI. Zam yapilmali. Bu bir YONETIM karari."

echo
echo "############ 3) SON 60 GUN — en cok para kaybettiren kalemler ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame,
         (CURRENT_DATE - fatura_tarihi)::int AS alis_gun
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT f.marka, f.ebat,
       round(son.ikame) AS ikame_TL, son.alis_gun,
       round(avg(f.birim_fiyat)) AS ort_satis_TL,
       round(100.0*(avg(f.birim_fiyat) - son.ikame)/NULLIF(avg(f.birim_fiyat),0)) AS marj,
       round(sum(f.miktar)) AS adet,
       round(sum(f.miktar * (f.birim_fiyat - son.ikame))) AS toplam_zarar_TL
  FROM bi_satis_faturalari f
  JOIN son ON son.kalem_kodu = f.kalem_kodu
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
   AND f.fatura_tarihi >= CURRENT_DATE - 60
 GROUP BY 1,2,3,4
HAVING avg(f.birim_fiyat) < son.ikame
 ORDER BY 8 ASC LIMIT 15;"
echo "  ^ toplam_zarar_TL = ikame maliyetine gore son 60 gunde kaybedilen."
echo "    ⚠ Bu 'muhasebe zarari' DEGIL. 'Bu fiyatla stogu yenileyemeyiz' demek."

echo
echo "############ 4) KIM SATIYOR? — negatif marjli satislarda temsilci/musteri ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT COALESCE(f.temsilci,'(bos)') AS temsilci,
       count(*) AS negatif_satir,
       round(sum(f.satir_tutar)/1e6,2) AS ciro_MTL,
       round(avg(100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0))) AS ort_marj
  FROM bi_satis_faturalari f
  JOIN son ON son.kalem_kodu = f.kalem_kodu
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
   AND f.fatura_tarihi >= CURRENT_DATE - 60
   AND f.birim_fiyat < son.ikame
 GROUP BY 1 ORDER BY 3 DESC LIMIT 10;" 2>&1 | head -14
echo "  ^ 'temsilci' kolonu yoksa hata verir — sorun degil, atla."
