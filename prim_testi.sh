#!/usr/bin/env bash
# Salt okuma. ⚠ KESIN TEST — "KRB TBR'de zararina satiyor" DOGRU MU?
#
# BULGULAR:
#   • Negatif marj BAYILIKTE yogunlasiyor (ciro %45 vs net alim %17)
#   • Negatif kalemlerin HEPSI TBR olculeri (385/65R22.5, 315/80R22.5...)
#   • Tesvik tablosunda TBR SATIRI HIC YOK
#   • Net alim markalari SAGLIKLI (KUMHO +%17, SAILUN +%55) -> fiyatlama disiplini VAR
#
# HIPOTEZ: fatura fiyati BRUT. Tedarikci primi FATURAYA GIRMIYOR, ayri bir
#   GELIR satiri olarak kaydediliyor: 'PRIM HAKEDISLERI'.
#   (LASTIK filtresini koyarken bu kalem 3. buyuk 'marka' gibi gorunuyordu, 9,16M.)
#
#   DOGRUYSA  -> marj primsiz hesaplandigi icin TBR zararli GORUNUYOR. Gercek degil.
#   YANLISSA  -> KRB TBR'de GERCEKTEN para kaybediyor. Fatih Bilen BILMELI.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠⚠ PRIM HAKEDISLERI — bu yil ne kadar? ############"
$PSQL -c "
SELECT grup_adi, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS tutar_MTL
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN'
   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   AND (grup_adi ILIKE '%PRIM%' OR grup_adi ILIKE '%PRİM%'
        OR kalem_tanimi ILIKE '%PRIM HAKEDIS%' OR kalem_tanimi ILIKE '%PRİM HAKEDİŞ%'
        OR marka ILIKE '%PRIM%' OR marka ILIKE '%PRİM%')
 GROUP BY 1 ORDER BY 3 DESC;" 2>&1 | head -12

echo
echo "   -- marka/kalem bazinda ne yaziyor? --"
$PSQL -c "
SELECT left(COALESCE(kalem_tanimi, marka, grup_adi),45) AS kalem, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS tutar_MTL,
       min(fatura_tarihi) AS ilk, max(fatura_tarihi) AS son
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN'
   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   AND (grup_adi ILIKE '%PRIM%' OR grup_adi ILIKE '%PRİM%'
        OR marka ILIKE '%PRIM%' OR marka ILIKE '%PRİM%')
 GROUP BY 1 ORDER BY 3 DESC LIMIT 10;" 2>&1 | head -14

echo
echo "############ 2) ⚠ ACIK ne kadar? — TBR negatif marj zarari vs prim ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS ikame
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT round(sum(f.miktar * (f.birim_fiyat - son.ikame))/1e6, 2) AS bayilik_negatif_fark_MTL,
       count(*) AS satir
  FROM bi_satis_faturalari f
  JOIN son ON son.kalem_kodu = f.kalem_kodu
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.birim_fiyat > 0
   AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   AND f.birim_fiyat < son.ikame
   AND EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                  AND upper(i.marka)=upper(f.marka))
   AND f.ebat NOT LIKE '12.00R2%';"
echo "  ^ Bu ACIGI prim KAPATIYOR mu? Bolum 1'deki rakamla kiyasla."
echo "    Prim >= acik ise: TBR gercekte KARLI, sadece primi gormuyoruz."

echo
echo "############ 3) ⚠ BRIDGESTONE 12.00R2 — 871k TL'lik veri hatasi ############"
$PSQL -c "
SELECT f.kalem_kodu, left(f.kalem_tanimi,40) AS satis_kalem, f.ebat,
       count(*) AS satir, round(sum(f.miktar)) AS adet,
       round(avg(f.birim_fiyat)) AS ort_satis_TL, round(sum(f.satir_tutar)) AS ciro_TL
  FROM bi_satis_faturalari f
 WHERE f.tenant_id='$TEN' AND f.ebat LIKE '12.00R2%'
   AND f.fatura_tarihi >= CURRENT_DATE - 60
 GROUP BY 1,2,3 ORDER BY 7 DESC LIMIT 5;"
echo "   -- ayni kalem_kodu ALIS tarafinda ne? --"
$PSQL -c "
SELECT t.kalem_kodu, left(t.kalem_tanimi,40) AS alis_kalem, t.marka,
       round(t.miktar,2) AS miktar, round(t.birim_fiyat_kdv_haric) AS birim_TL,
       round(t.satir_kdv_haric) AS satir_TL, t.fatura_tarihi
  FROM bi_tedarikci_faturalari t
 WHERE t.tenant_id='$TEN'::uuid
   AND t.kalem_kodu IN (
     SELECT DISTINCT kalem_kodu FROM bi_satis_faturalari
      WHERE tenant_id='$TEN' AND ebat LIKE '12.00R2%'
        AND fatura_tarihi >= CURRENT_DATE - 60)
 ORDER BY t.fatura_tarihi DESC LIMIT 5;"
echo "  ^ ALIS kalemi ile SATIS kalemi AYNI URUN mu? Degilse kalem_kodu eslesmesi BOZUK."

echo
echo "############ 4) KAPLAMA markalari — maliyet eslesmesi neden negatif? ############"
$PSQL -c "
SELECT t.marka, t.grup_adi, count(*) AS alis_satiri,
       round(avg(t.birim_fiyat_kdv_haric)) AS ort_alis_TL
  FROM bi_tedarikci_faturalari t
 WHERE t.tenant_id='$TEN'::uuid
   AND upper(t.marka) IN ('KRB','HERKUL','AVON+','BANDAG','RECAMIC')
   AND t.fatura_tarihi >= CURRENT_DATE - 365
 GROUP BY 1,2 ORDER BY 3 DESC LIMIT 10;"
echo "  ^ Kaplamada 'alis' = KARKAS + KAPLAMA HIZMETI. Tek kalem_kodu ile"
echo "    eslesmiyor olabilir -> maliyet eksik gorunur -> marj negatif cikar."
