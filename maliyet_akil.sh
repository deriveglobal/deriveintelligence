#!/usr/bin/env bash
# Salt okuma. ⚠ alis_aykiri.sh bolum 5 GROUP BY hatasiyla patladi — ASIL TEST OYDU.
#
# BULGULAR (alis_aykiri.sh):
#   ✅ x10.000 bozuklugu YOK — 145.882 satirin %100'u tutarli.
#   ✅ Lastik alis fiyatlari makul bantta (70 - 345.788 TL).
#   ⚠ %279,8 ortalama zam = ALINAN HIZMET / ISCILIK / DIGER kirliligi.
#      (Satis tarafinda LASTIK filtresi koyduk; ALIS tarafinda YOK.)
#   ❌ TEK supheli satir: GREENTRAC 315/70R22.5 = 1 TL (2023, MP Otomotiv)
#
# SORU: bu yil satilan kalemlerde IKAME MALIYETI akla yatkin mi?
#   %80+ marj  -> maliyet muhtemelen BOZUK (lastikte olmaz)
#   Negatif    -> ya gercek zarar ya bozuk maliyet. IKISI DE onemli.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ IKAME MALIYETINE GORE MARJ DAGILIMI (bu yil, ciro agirlikli) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
m AS (
  SELECT f.satir_tutar,
         100.0*(f.birim_fiyat - son.maliyet)/NULLIF(f.birim_fiyat,0) AS marj
    FROM bi_satis_faturalari f
    JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE))
SELECT CASE WHEN marj <   0 THEN 'a) NEGATIF     ❌ zararina mi satiyoruz?'
            WHEN marj <  10 THEN 'b) %0-10       ⚠ cok ince'
            WHEN marj <  25 THEN 'c) %10-25      ✅ normal'
            WHEN marj <  40 THEN 'd) %25-40      ✅ iyi'
            WHEN marj <  80 THEN 'e) %40-80      ⚠ lastikte supheli'
            ELSE                 'f) %80+        ❌ MALIYET BOZUK olmali' END AS bant,
       count(*) AS satir,
       round(sum(satir_tutar)/1e6,1) AS ciro_MTL,
       round(100.0*sum(satir_tutar)/sum(sum(satir_tutar)) OVER (),1) AS ciro_pct
  FROM m GROUP BY 1 ORDER BY 1;"
echo "  ^ 'f' bandi buyukse ikame maliyeti guvenilmez. Kucukse sistem saglam."

echo
echo "############ 2) %80+ MARJ GOSTEREN KALEMLER — tek tek ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet,
         fatura_tarihi AS alis_tarihi
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
g AS (
  SELECT f.marka, f.ebat, son.maliyet, son.alis_tarihi,
         avg(f.birim_fiyat) AS ort_satis,
         count(*) AS satir, sum(f.satir_tutar) AS ciro
    FROM bi_satis_faturalari f
    JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   GROUP BY 1,2,3,4)
SELECT marka, ebat, round(maliyet) AS ikame_TL, alis_tarihi,
       round(ort_satis) AS ort_satis_TL,
       round(100.0*(ort_satis - maliyet)/NULLIF(ort_satis,0)) AS gorunen_marj,
       satir, round(ciro/1e6,2) AS ciro_MTL
  FROM g
 WHERE 100.0*(ort_satis - maliyet)/NULLIF(ort_satis,0) > 80
 ORDER BY ciro DESC LIMIT 15;"
echo "  ^ Bunlar EKRANDA %80+ marj gosterecek. Gercek mi, bozuk mu?"

echo
echo "############ 3) NEGATIF MARJ — gercek zarar mi, bozuk maliyet mi? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet,
         (CURRENT_DATE - fatura_tarihi)::int AS gun
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
g AS (
  SELECT f.marka, f.ebat, son.maliyet, son.gun,
         avg(f.birim_fiyat) AS ort_satis, count(*) AS satir, sum(f.satir_tutar) AS ciro
    FROM bi_satis_faturalari f
    JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   GROUP BY 1,2,3,4)
SELECT marka, ebat, round(maliyet) AS ikame_TL, gun AS alis_gun_once,
       round(ort_satis) AS ort_satis_TL,
       round(100.0*(ort_satis - maliyet)/NULLIF(ort_satis,0)) AS marj,
       satir, round(ciro/1e6,2) AS ciro_MTL
  FROM g
 WHERE 100.0*(ort_satis - maliyet)/NULLIF(ort_satis,0) < 0
 ORDER BY ciro DESC LIMIT 15;"
echo "  ^ 'alis_gun_once' KUCUKSE (taze fiyat) -> GERCEK ZARAR. Fatih Bilen bunu bilmeli."
echo "    BUYUKSE -> maliyet guncel degil, zam gelmis, satis fiyati geride kalmis."

echo
echo "############ 4) GREENTRAC 1 TL — bu yil satildi mi? ############"
$PSQL -c "
SELECT f.marka, f.ebat, count(*) AS satis_satiri,
       round(avg(f.birim_fiyat)) AS ort_satis_TL,
       round(sum(f.satir_tutar)) AS ciro_TL
  FROM bi_satis_faturalari f
 WHERE f.tenant_id='$TEN' AND upper(f.marka)='GREENTRAC'
   AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
 GROUP BY 1,2;"
echo "  ^ Bos ise: 1 TL'lik satir teklife DUSMEZ, risk YOK."
