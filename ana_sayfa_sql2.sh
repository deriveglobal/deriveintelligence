#!/usr/bin/env bash
# ANA SAYFA RAKAMLARI v2 — kendi 3 hatam duzeltildi.
#
# ⚠ HATA 1: bi_sku_norm YOK. build_marj_kup2.sh hic kosmadi. Once kur.
#
# ⚠ HATA 2: KOR NOKTA sorgum YANLIŞTI. Iskonto satiri olmayan HER SEYI kor saydim.
#   Net-fiyat markalarinin (Kumho, Sailun, Yokohama...) ISKONTOYA IHTIYACI YOK —
#   maliyetleri zaten son alis faturasi, ve DOGRU. Onlari kor listesine atmak yanlis.
#   Kor nokta SADECE bayilik markalarinda (Brisa/Conti ailesi) anlamli.
#
# ⚠ HATA 3: DSO 26,9 gun YALAN. bi_fatura_tahsilat sadece TAHSIL EDILMIS faturalari
#   tutuyor. 145,4M gecikmis alacak bu ortalamanin ICINDE YOK. Hayatta kalan yanliligi.
#   Ort. gecikme -6,6 gun cikiyor (erken odeme!) cunku ODEMEYENLER SAYILMIYOR.
#   ✅ Gercek DSO = alacak / gunluk ciro. Tahsil edilmeyeni de icerir.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) EKSIK FONKSIYON ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE OR REPLACE FUNCTION bi_sku_norm(p text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT NULLIF(
    ltrim(
      regexp_replace(
        regexp_replace(
          regexp_replace(upper(COALESCE(p,'')), '^[A-Z]+[-_ ]', '', ''),  -- CNT- MTD-
          '[-_ ]?[0-9]{2}$', '', ''),                                     -- ⚠ YIL soneki (-25/-26) ONCE
        '[^0-9]', '', 'g'),                                               -- bosluklari sil
      '0'),                                                               -- bastaki sifir
    '');
$$;
SQL
echo "  ✅ bi_sku_norm()"

$PSQL <<SQL
SET app.current_tenant_id = '$TEN';

\echo ''
\echo '════════ 1) ⚠ BAGLI SERMAYE — STOK (taahhutlu vs serbest) ════════'
WITH sa AS (
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))
         bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS fiyat
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
   ORDER BY 1, fatura_tarihi DESC)
SELECT round(sum(st.adet * sa.fiyat)/1e6,1)           AS stok_deger_M,
       round(sum(st.taahhut * sa.fiyat)/1e6,1)        AS TAAHHUTLU_M,
       round(sum(st.kullanilabilir * sa.fiyat)/1e6,1) AS SERBEST_M,
       sum(st.adet)::int AS adet, count(*) AS sku,
       count(*) FILTER (WHERE sa.fiyat IS NULL) AS fiyatsiz_sku,
       round(100.0*count(*) FILTER (WHERE sa.fiyat IS NULL)/count(*)) AS fiyatsiz_pct
  FROM bi_stok_anlik st
  LEFT JOIN sa ON sa.sku = bi_sku_norm(st.kalem_kodu)
 WHERE st.tenant_id='$TEN'::uuid AND st.adet > 0;
\echo '  ^ ⚠ TAAHHUTLU = on siparise bagli. "Stogu azalt" tavsiyesi buna DOKUNAMAZ.'

\echo ''
\echo '════════ 2) ⚠⚠ GERCEK NAKIT DONGUSU (hayatta kalan yanliligi YOK) ════════'
WITH gc AS (SELECT sum(satir_tutar)/365.0 AS gunluk
              FROM bi_satis_faturalari
             WHERE tenant_id='$TEN' AND miktar>0 AND ebat IS NOT NULL
               AND fatura_tarihi >= CURRENT_DATE-365),
     al AS (SELECT sum(toplam_risk) AS alacak, sum(vadesi_gecmis) AS gecikmis
              FROM bi_musteri_risk WHERE tenant_id='$TEN'::uuid AND COALESCE(musteri_mi,true)),
     sk AS (SELECT sum(st.adet * sa.fiyat) AS stok
              FROM bi_stok_anlik st
              LEFT JOIN (SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku,
                                birim_fiyat_kdv_haric fiyat
                           FROM bi_tedarikci_faturalari
                          WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
                          ORDER BY 1, fatura_tarihi DESC) sa ON sa.sku=bi_sku_norm(st.kalem_kodu)
             WHERE st.tenant_id='$TEN'::uuid AND st.adet>0)
SELECT round((SELECT gunluk FROM gc)/1e6,2)                        AS gunluk_ciro_M,
       round((SELECT stok FROM sk)/1e6,1)                          AS stok_M,
       round((SELECT alacak FROM al)/1e6,1)                        AS alacak_M,
       round(((SELECT stok FROM sk)+(SELECT alacak FROM al))/1e6,1) AS BAGLI_SERMAYE_M,
       round((SELECT stok FROM sk)/(SELECT gunluk FROM gc))         AS stok_gun,
       round((SELECT alacak FROM al)/(SELECT gunluk FROM gc))       AS GERCEK_DSO_gun,
       round(((SELECT stok FROM sk)+(SELECT alacak FROM al))*0.40/1e6,1) AS YILLIK_SERMAYE_YUKU_M;
\echo '  ^ ⚠ GERCEK_DSO: tahsil edilmemisleri de icerir. Tablodaki 26,9 gun'
\echo '    SADECE odeyenleri olcuyordu — 145,4M odemeyen ortalamaya HIC GIRMIYORDU.'

\echo ''
\echo '════════ 3) ⚠⚠ KOR NOKTA — SADECE BAYILIK markalarinda anlamli ════════'
\echo '   (net-fiyat markalarinin maliyeti son alistir ve DOGRUDUR — kor degil)'
WITH isk AS (SELECT DISTINCT upper(marka) marka, sezon FROM bi_fiyat_iskonto
              WHERE tenant_id='$TEN'::uuid AND aktif),
lst AS (SELECT DISTINCT upper(marka) marka, kategori FROM bi_fiyat_listesi_uploads
         WHERE tenant_id='$TEN'::uuid AND aktif),
s AS (SELECT f.kategori, upper(f.marka) AS marka, sum(f.satir_tutar) AS ciro
        FROM bi_satis_faturalari f
       WHERE f.tenant_id='$TEN' AND f.miktar>0 AND f.ebat IS NOT NULL
         AND f.fatura_tarihi >= CURRENT_DATE-365
         AND upper(f.marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR','BARUM','DAYTON')
         AND COALESCE(f.kategori,'') NOT IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
         AND COALESCE(f.satis_kanali,'') NOT ILIKE '%YANSIT%'
       GROUP BY 1,2)
SELECT round(sum(ciro)/1e6,1) AS bayilik_ciro_M,
       round(sum(ciro) FILTER (WHERE i.marka IS NOT NULL)/1e6,1) AS OLCULEBILIR_M,
       round(sum(ciro) FILTER (WHERE i.marka IS NULL)/1e6,1)     AS KOR_M,
       round(100.0*sum(ciro) FILTER (WHERE i.marka IS NULL)/sum(ciro)) AS KOR_PCT
  FROM s
  LEFT JOIN isk i ON i.marka=s.marka AND i.sezon=s.kategori;

\echo ''
\echo '  -- EKSIK OLAN TAM OLARAK NE? (KRB bu 3 dosyayi yukleyecek) --'
SELECT s.kategori, round(sum(s.ciro)/1e6,1) AS ciro_M,
       CASE WHEN bool_or(i.marka IS NOT NULL) THEN 'tamam'
            WHEN bool_or(l.marka IS NOT NULL) THEN 'ISKONTO EKSIK (liste var)'
            ELSE 'LISTE + ISKONTO EKSIK' END AS eksik
  FROM (SELECT f.kategori, upper(f.marka) AS marka, sum(f.satir_tutar) AS ciro
          FROM bi_satis_faturalari f
         WHERE f.tenant_id='$TEN' AND f.miktar>0 AND f.ebat IS NOT NULL
           AND f.fatura_tarihi >= CURRENT_DATE-365
           AND upper(f.marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR','BARUM','DAYTON')
         GROUP BY 1,2) s
  LEFT JOIN isk i ON i.marka=s.marka AND i.sezon=s.kategori
  LEFT JOIN lst l ON l.marka=s.marka AND l.kategori=s.kategori
 GROUP BY 1 ORDER BY 2 DESC;

\echo ''
\echo '════════ 4) ⚠ KARAR KUYRUGU — planli odemeler AYRILIYOR ════════'
\echo '   "18 Kas odemesi" bir SORUN degil, TAKVIM. Karar kuyrugunu tikiyor.'
\echo '   -- KARAR GEREKTIREN --'
SELECT bi_sinyal_puan(tutar_tl,son_tarih,eylem_var) AS puan, tur,
       left(baslik,44) AS baslik, round(tutar_tl/1e6,1) AS M, oda
  FROM bi_sinyal
 WHERE tenant_id='$TEN' AND durum='acik' AND tur <> 'odeme'
 ORDER BY 1 DESC LIMIT 5;

\echo '   -- BILGI (takvim, karar yok) --'
SELECT count(*) AS planli_odeme, round(sum(tutar_tl)/1e6,1) AS toplam_M,
       min(son_tarih) AS en_yakin
  FROM bi_sinyal WHERE tenant_id='$TEN' AND durum='acik' AND tur='odeme';
SQL
