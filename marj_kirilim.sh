#!/usr/bin/env bash
# Salt okuma. ⚠ KARAR TESTI — "KRB zararina satiyor" demeden ONCE.
#
# BULGULAR:
#   Soru A (o gunku alis fiyatiyla): %29,0 ciro NEGATIF marjda.
#   Soru B (son 60 gun, bugunku maliyet): %37,2 NEGATIF.
#   -> Zamanlama yanliligi DEGIL. Gercek bir sey var.
#
# ⚠ AMA: negatif marj listesindeki 15 kalemin HEPSI BRIDGESTONE/LASSA/CONTINENTAL.
#   TEK BIR net alim markasi YOK (KUMHO, SAILUN, HERKUL = cironun %38'i).
#   Bu TESADUF DEGIL.
#
# HIPOTEZ: bayilik markalarinda ALIS FATURASI NIHAI MALIYET DEGIL.
#   Brisa/Continental'de CIRO PRIMI / SKALA PRIMI var -- yil sonu, hacim bazli,
#   faturaya GIRMEYEN geri odemeler. (bi_fiyat_iskonto.skala_primi tam olarak bu.)
#   Yani fatura fiyati BRUT maliyet; gercek NET maliyet daha DUSUK.
#
#   Hipotez DOGRUYSA -> "%37 zararina satiyoruz" YANLIS bir cumle.
#   Hipotez YANLISSA -> KRB gercekten para kaybediyor ve Fatih Bilen BILMELI.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) KAPI: satis fiyati KDV HARIC mi? (kolon adlari) ############"
$PSQL -c "\d bi_satis_faturalari" | grep -Ei 'kdv|tutar|fiyat|miktar'
echo "  ^ birim_fiyat x miktar = satir_tutar TUTUYORSA ikisi ayni bazda."
$PSQL -c "
SELECT CASE WHEN abs(birim_fiyat*miktar - satir_tutar) <= 0.02*abs(NULLIF(satir_tutar,0))
            THEN '✅ birim x miktar = satir_tutar' ELSE '❌ TUTMUYOR' END AS durum,
       count(*) AS satir
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar > 0 AND satir_tutar <> 0
   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
 GROUP BY 1;"

echo
echo "############ 1) ⚠⚠ KARAR TESTI — negatif marj BAYILIKTE mi, NET ALIMDA mi? ############"
echo "   (son 60 gun satis, bugunku ikame maliyeti)"
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
    FROM bi_satis_faturalari f
    JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= CURRENT_DATE - 60)
SELECT CASE WHEN bayilik THEN '🅑 BAYILIK (Brisa/Conti)' ELSE '🅝 NET ALIM' END AS sinif,
       count(*) FILTER (WHERE marj < 0) AS negatif_satir,
       count(*) AS toplam_satir,
       round(100.0*count(*) FILTER (WHERE marj < 0)/NULLIF(count(*),0),1) AS negatif_satir_pct,
       round(sum(satir_tutar) FILTER (WHERE marj < 0)/1e6,1) AS negatif_ciro_MTL,
       round(100.0*sum(satir_tutar) FILTER (WHERE marj < 0)/NULLIF(sum(satir_tutar),0),1) AS negatif_ciro_pct,
       round(avg(marj)) AS ort_marj
  FROM m GROUP BY 1 ORDER BY 1;"
echo
echo "  >>> NASIL OKUNUR:"
echo "      BAYILIK negatif %40+, NET ALIM negatif ~%0-10 ise"
echo "        -> HIPOTEZ DOGRU. Ciro/skala primi faturada YOK. Maliyet BRUT."
echo "        -> 'zararina satiyoruz' DEMEK YANLIS. Ekranda 'brut maliyet' demeliyiz."
echo "      IKISI DE negatifse"
echo "        -> HIPOTEZ YANLIS. KRB GERCEKTEN para kaybediyor. Fatih Bilen BILMELI."

echo
echo "############ 2) NET ALIM markalarinda marj dagilimi (temiz olcum) ############"
echo "   Bu markalarda geri odeme YOK -> fatura fiyati = GERCEK maliyet."
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT f.marka,
       count(*) AS satir,
       round(avg(100.0*(f.birim_fiyat - son.ikame)/NULLIF(f.birim_fiyat,0))) AS ort_marj_pct,
       round(sum(f.satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari f
  JOIN son ON son.kalem_kodu = f.kalem_kodu
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
   AND f.fatura_tarihi >= CURRENT_DATE - 60
   AND NOT EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                    WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                      AND upper(i.marka)=upper(f.marka))
 GROUP BY 1 HAVING count(*) >= 5
 ORDER BY 4 DESC LIMIT 12;"
echo "  ^ Bunlar SAGLIKLI marj gosteriyorsa, KRB'nin fiyatlama disiplini VAR."
echo "    Sorun sadece bayilik maliyetinin BRUT olmasindan geliyor demektir."

echo
echo "############ 3) SKALA PRIMI tabloda ne diyor? ############"
$PSQL -c "
SELECT marka, arac_tipi, sezon, rim_alt, rim_ust,
       baz_iskonto1, baz_iskonto2, ds, skala_primi,
       round((1 - (1-baz_iskonto1/100.0)*(1-baz_iskonto2/100.0)
                *(1-ds/100.0)*(1-skala_primi/100.0))*100, 1) AS toplam_iskonto_pct
  FROM bi_fiyat_iskonto
 WHERE tenant_id='$TEN'::uuid AND aktif
 ORDER BY marka, rim_alt NULLS FIRST LIMIT 20;"
echo "  ^ skala_primi > 0 ise: KRB bu primi ALIYOR ama fatura fiyatinda YOK."
echo "    Yani gercek maliyet = fatura x (1 - skala_primi/100) civari."

echo
echo "############ 4) SON 60 GUN — en cok kaybettiren kalemler (duzeltilmis) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame,
         (CURRENT_DATE - fatura_tarihi)::int AS alis_gun
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
g AS (
  SELECT f.marka, f.ebat, son.ikame, son.alis_gun,
         EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(f.marka)) AS bayilik,
         avg(f.birim_fiyat) AS ort_satis,
         sum(f.miktar) AS adet,
         sum(f.miktar * (f.birim_fiyat - son.ikame)) AS fark
    FROM bi_satis_faturalari f
    JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
     AND f.fatura_tarihi >= CURRENT_DATE - 60
   GROUP BY 1,2,3,4,5)
SELECT CASE WHEN bayilik THEN '🅑' ELSE '🅝' END AS s,
       marka, ebat, round(ikame) AS ikame_TL, alis_gun,
       round(ort_satis) AS satis_TL,
       round(100.0*(ort_satis-ikame)/NULLIF(ort_satis,0)) AS marj,
       round(adet) AS adet, round(fark) AS fark_TL
  FROM g WHERE fark < 0
 ORDER BY fark ASC LIMIT 15;"
echo "  ^ 🅝 (net alim) satir SAYISI az ise hipotez guclenir."
