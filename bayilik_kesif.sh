#!/usr/bin/env bash
# Salt okuma. HIPOTEZ (Fatih): KRB sadece BRISA + CONTINENTAL bayisi.
#   Bayilik markasi -> liste fiyati + tesvik VAR  -> ikame = liste x (1-tesvik)
#   Diger marka     -> NET alinir, tesvik YOK     -> ikame = EN SON net alis fiyati
# Bunu yazmadan once: kolon adlari ne, ve net alim markalarinin kacinda
# gercekten son alis fiyati BULUNABILIYOR?
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) bi_tedarikci_faturalari — KOLONLAR ############"
$PSQL -c "\d bi_tedarikci_faturalari"

echo
echo "############ 2) BAYILIK MARKALARI (tesvik tablosunda olanlar) ############"
$PSQL -c "
SELECT marka, count(*) AS iskonto_satiri,
       string_agg(DISTINCT sezon, ', ')     AS sezonlar,
       string_agg(DISTINCT arac_tipi, ', ') AS arac_tipleri
  FROM bi_fiyat_iskonto WHERE tenant_id='$TEN'::uuid AND aktif
 GROUP BY 1 ORDER BY 1;"
echo "  ^ BRISA = BRIDGESTONE/LASSA/DAYTON · CONTINENTAL = CONTINENTAL/BARUM/MATADOR"

echo
echo "############ 3) ⚠ BU YIL SATILAN MARKALAR — bayilik mi, net alim mi? ############"
$PSQL -c "
WITH s AS (
  SELECT s.marka, s.miktar, s.satir_tutar,
         EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(s.marka)) AS bayilik
    FROM bi_satis_faturalari s
   WHERE s.tenant_id='$TEN' AND s.grup_adi LIKE 'LASTIK%'
     AND s.fatura_tarihi >= date_trunc('year', CURRENT_DATE))
SELECT CASE WHEN bayilik THEN '🅑 BAYILIK (liste-tesvik)' ELSE '🅝 NET ALIM (son alis fiyati)' END AS sinif,
       marka, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS ciro_MTL,
       round(100.0*sum(satir_tutar)/sum(sum(satir_tutar)) OVER (),1) AS ciro_pct
  FROM s GROUP BY 1,2 ORDER BY 4 DESC;"

echo
echo "############ 4) ⚠⚠ NET ALIM markalarinda SON ALIS FIYATI BULUNABILIYOR MU? ############"
echo "   (bulunamazsa ikame maliyeti yine hesaplanamaz — kac satir?)"
$PSQL -c "
WITH s AS (
  SELECT DISTINCT s.kalem_kodu, s.marka, s.ebat
    FROM bi_satis_faturalari s
   WHERE s.tenant_id='$TEN' AND s.grup_adi LIKE 'LASTIK%'
     AND s.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
     AND NOT EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                      WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                        AND upper(i.marka)=upper(s.marka)))
SELECT CASE WHEN EXISTS (SELECT 1 FROM bi_tedarikci_faturalari t
                          WHERE t.tenant_id='$TEN'::uuid
                            AND t.kalem_kodu = s.kalem_kodu
                            AND t.birim_fiyat_kdv_haric > 0)
            THEN '✅ ALIS FATURASI VAR' ELSE '❌ HIC ALINMAMIS' END AS durum,
       count(*) AS urun_cesidi,
       round(100.0*count(*)/sum(count(*)) OVER (),1) AS pct
  FROM s GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 5) ORNEK — net alim markasi, son alis fiyati + tarihi ############"
$PSQL -c "
SELECT DISTINCT ON (t.kalem_kodu)
       t.marka, t.ebat, t.kalem_kodu,
       round(t.birim_fiyat_kdv_haric) AS son_alis_TL,
       t.fatura_tarihi,
       (CURRENT_DATE - t.fatura_tarihi) AS gun_once
  FROM bi_tedarikci_faturalari t
 WHERE t.tenant_id='$TEN'::uuid AND t.birim_fiyat_kdv_haric > 0
   AND upper(t.marka) IN ('SAILUN','KUMHO','PETLAS','ÖZKA','OZKA','HERKUL')
 ORDER BY t.kalem_kodu, t.fatura_tarihi DESC
 LIMIT 8;"
echo "  ^ 'gun_once' cok buyukse (>180) fiyat BAYAT — ekranda uyari verecegiz."

echo
echo "############ 6) BAYILIK markalarinda liste fiyati VAR MI? (kontrol) ############"
$PSQL -c "
SELECT u.marka,
       count(*) FILTER (WHERE k.liste_fiyati > 0) AS liste_fiyatli_kalem,
       EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                  AND upper(i.marka)=upper(u.marka)) AS bayilik
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id = k.upload_id
 WHERE k.tenant_id='$TEN'::uuid AND u.aktif
 GROUP BY 1 ORDER BY 3 DESC, 2 DESC;"
echo "  ^ bayilik=false olan markada liste fiyati VARSA hipotez eksik — soyle."
