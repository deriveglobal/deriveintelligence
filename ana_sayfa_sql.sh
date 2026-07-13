#!/usr/bin/env bash
# ⚠ ANA SAYFANIN HER RAKAMI — endpoint'e KOYMADAN ONCE Postgres'te dogrulaniyor.
#   Ekrana giden hicbir sayi burada gorunmeden yazilmayacak.
#
# ⚠ bi_stok_anlik'ta MALIYET KOLONU YOK. Sadece liste_fiyati (= maliyet DEGIL).
#   Stok degeri HESAPLANMAK zorunda: adet x son_alis (tedarikci faturasindan).
#
# ⚠ taahhut / kullanilabilir kolonlari VAR — "hangi stoga dokunulmaz" sorusunun cevabi.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

$PSQL <<SQL
SET app.current_tenant_id = '$TEN';

\echo '════════ 1) BAGLI SERMAYE — stok ════════'
WITH sa AS (   -- son alis fiyati, SKU bazinda
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))
         bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS fiyat
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
   ORDER BY 1, fatura_tarihi DESC)
SELECT round(sum(st.adet * sa.fiyat)/1e6,1)            AS stok_deger_M,
       round(sum(st.taahhut * sa.fiyat)/1e6,1)         AS TAAHHUTLU_M,
       round(sum(st.kullanilabilir * sa.fiyat)/1e6,1)  AS SERBEST_M,
       sum(st.adet)::int                                AS adet,
       count(*)                                         AS sku,
       count(*) FILTER (WHERE sa.fiyat IS NULL)         AS FIYATSIZ_sku
  FROM bi_stok_anlik st
  LEFT JOIN sa ON sa.sku = bi_sku_norm(st.kalem_kodu)
 WHERE st.tenant_id='$TEN'::uuid AND st.adet > 0;
\echo '  ^ TAAHHUTLU = on siparise bagli, DOKUNULMAZ. SERBEST = azaltilabilir.'

\echo ''
\echo '════════ 2) BAGLI SERMAYE — alacak ════════'
SELECT round(sum(toplam_risk)/1e6,1)     AS toplam_risk_M,
       round(sum(vadesi_gecmis)/1e6,1)   AS GECIKMIS_M,
       count(*) FILTER (WHERE vadesi_gecmis > 0)              AS gecikmis_musteri,
       count(*) FILTER (WHERE limit_asimi > 0)                AS LIMIT_ASAN,
       round(sum(cek_senet_riski)/1e6,1) AS cek_senet_M,
       round(sum(bekleyen_siparis)/1e6,1) AS bekleyen_siparis_M
  FROM bi_musteri_risk
 WHERE tenant_id='$TEN'::uuid AND COALESCE(musteri_mi,true);

\echo ''
\echo '════════ 3) NAKIT DONGUSU ════════'
WITH cogs AS (   -- gunluk satilan mal maliyeti (yaklasik: ciro x (1-marj))
  SELECT sum(satir_tutar)/365.0 AS gunluk_ciro
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND miktar>0 AND ebat IS NOT NULL
     AND fatura_tarihi >= CURRENT_DATE-365),
dso AS (
  SELECT round(avg(tahsilat_gun)::numeric,1) AS gun
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL AND tahsilat_gun BETWEEN 0 AND 365)
SELECT round((SELECT gunluk_ciro FROM cogs)/1e6,2) AS gunluk_ciro_M,
       (SELECT gun FROM dso)                        AS DSO_gun,
       round(avg(gecikme_gun)::numeric,1)           AS ort_gecikme_gun
  FROM bi_fatura_tahsilat
 WHERE tenant_id='$TEN' AND gecikme_gun IS NOT NULL;

\echo ''
\echo '════════ 4) ⚠⚠ KOR NOKTA — cironun yuzde kaci FIYATLANAMIYOR? ════════'
\echo '   (Bu, ana sayfanin BIRINCI sinyali olacak. EVA bu yuzden hesaplanamiyor.)'
WITH isk AS (SELECT DISTINCT upper(marka) marka, sezon FROM bi_fiyat_iskonto
              WHERE tenant_id='$TEN'::uuid AND aktif),
s AS (
  SELECT f.kategori, upper(f.marka) AS marka, sum(f.satir_tutar) AS ciro
    FROM bi_satis_faturalari f
   WHERE f.tenant_id='$TEN' AND f.miktar>0 AND f.ebat IS NOT NULL
     AND f.fatura_tarihi >= CURRENT_DATE-365
     AND COALESCE(f.kategori,'') NOT IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
     AND COALESCE(f.satis_kanali,'') NOT ILIKE '%YANSIT%'
   GROUP BY 1,2)
SELECT round(sum(ciro)/1e6,1) AS lastik_ciro_M,
       round(sum(ciro) FILTER (WHERE i.marka IS NOT NULL)/1e6,1) AS FIYATLANABILIR_M,
       round(100.0*sum(ciro) FILTER (WHERE i.marka IS NULL)/sum(ciro)) AS KOR_PCT,
       round(sum(ciro) FILTER (WHERE i.marka IS NULL)/1e6,1) AS KOR_M
  FROM s LEFT JOIN isk i ON i.marka=s.marka
      AND i.sezon = CASE WHEN s.kategori='KIS' THEN 'KIS' ELSE s.kategori END;

\echo ''
\echo '  -- eksik olan TAM OLARAK NE? --'
SELECT kategori,
       round(sum(satir_tutar)/1e6,1) AS ciro_M,
       CASE WHEN kategori='KIS' THEN '✅ iskonto var'
            WHEN kategori IN ('YAZ','4 MEVSIM') THEN '❌ ISKONTO YOK (liste var)'
            WHEN kategori IN ('TBR','OTR') THEN '❌ LISTE de ISKONTO da YOK'
            ELSE '— bayilik disi (net fiyat, son alis dogru)' END AS durum
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND miktar>0 AND ebat IS NOT NULL
   AND upper(marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR','BARUM','DAYTON')
   AND fatura_tarihi >= CURRENT_DATE-365
 GROUP BY 1 ORDER BY 2 DESC;

\echo ''
\echo '════════ 5) SINYALLER — ana sayfada ilk 3 ════════'
SELECT bi_sinyal_puan(tutar_tl,son_tarih,eylem_var) AS puan,
       tur, left(baslik,46) AS baslik,
       round(tutar_tl/1e6,1) AS M,
       CASE WHEN son_tarih IS NULL THEN '—' ELSE (son_tarih-CURRENT_DATE)||'g' END AS kalan,
       oda, durum
  FROM bi_sinyal
 WHERE tenant_id='$TEN' AND durum='acik'
 ORDER BY 1 DESC LIMIT 6;

\echo ''
\echo '════════ 6) ⚠ SEVK SINYALLERI — grupla (ana sayfada 1 satir) ════════'
SELECT count(*) AS sinyal, round(sum(tutar_tl)/1e6,1) AS toplam_M,
       min(son_tarih) AS en_yakin
  FROM bi_sinyal
 WHERE tenant_id='$TEN' AND durum='acik' AND tur='sevk_gecikme';
SQL
