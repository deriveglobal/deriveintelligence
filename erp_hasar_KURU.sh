#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#  KURU CALISMA — HICBIR SEY YAZMAZ. Sadece bakar, sayar, kanit uretir.
#  Kaynakta (Excel) iki bozulma KANITLANDI. Simdi soru:
#  bunlarin hangisi DB'ye de gecti?
#     A) TARIH takasi  (gun<=12 -> ay/gun yer degistirmis)
#     B) SAYI x10.000  (Turkce virgul binlik ayraci sanilmis)
#  Ingest bunlari duzeltmis de olabilir. VARSAYMA -- OLC.
# ═══════════════════════════════════════════════════════════════════════
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 0) ⚠ INGEST KODU NEREDE? (onceki grep bos dondu) ############"
grep -rln "bi_satis_faturalari" /opt 2>/dev/null | grep -v "\.bak\|/backups/" | head
docker exec krb-assessment sh -c 'grep -rln "bi_satis_faturalari" /app 2>/dev/null | head'
grep -rln "bi_ingestion_log" /opt 2>/dev/null | grep -v "\.bak" | head
crontab -l 2>/dev/null | grep -i "ingest\|erp\|xlsx" || echo "  (cron'da ERP ingest YOK -> elle/UI'dan yukleniyor)"

echo
echo "############ 1) ⚠⚠ SAYI HASARI: miktar x10.000 mu? ############"
echo "  ERP kendi kendini dogrular: miktar × birim_fiyat ≈ satir_tutar"
$PSQL -c "
SELECT count(*)                                                             AS test_edilebilir,
       count(*) FILTER (WHERE abs(miktar*birim_fiyat - satir_tutar)
                              <= GREATEST(0.05, abs(satir_tutar)*0.02))     AS SIMDI_tutuyor,
       count(*) FILTER (WHERE abs((miktar/10000)*birim_fiyat - satir_tutar)
                              <= GREATEST(0.05, abs(satir_tutar)*0.02))     AS BOLUNCE_tutuyor
  FROM bi_satis_faturalari
 WHERE miktar IS NOT NULL AND birim_fiyat IS NOT NULL AND satir_tutar IS NOT NULL
   AND satir_tutar <> 0;"
echo "  >>> BOLUNCE >> SIMDI  ise: miktar DB'de de x10.000 BOZUK."
echo "  >>> SIMDI  yuksekse    : ingest zaten duzeltmis. SAYIYA DOKUNMA."

echo "  -- miktar buyuklugu (goz testi: lastik adedi 10.000 olamaz) --"
$PSQL -c "
SELECT min(miktar) AS en_kucuk, max(miktar) AS en_buyuk,
       round(avg(miktar),2) AS ortalama,
       count(*) FILTER (WHERE miktar >= 1000) AS bin_ve_ustu_satir
  FROM bi_satis_faturalari WHERE miktar IS NOT NULL;"
echo "  ^ ortalama ~10.000 civariysa BOZUK. ~5-20 ise SAGLAM."

echo
echo "############ 2) ⚠ TARIH HASARI: parti parti semantik test ############"
echo "  Kural: vade_tarihi - fatura_tarihi == odeme_kosulu'ndaki gun sayisi."
echo "  Bu test hipotezimden BAGIMSIZ. Veri kendini dogruluyor."
$PSQL -c "
WITH v AS (
  SELECT export_date, fatura_tarihi f, vade_tarihi v,
         NULLIF(regexp_replace(COALESCE(odeme_kosulu,''),'[^0-9]','','g'),'')::int AS gun,
         CASE WHEN EXTRACT(DAY FROM fatura_tarihi)<=12
              THEN make_date(EXTRACT(YEAR FROM fatura_tarihi)::int,
                             EXTRACT(DAY FROM fatura_tarihi)::int,
                             EXTRACT(MONTH FROM fatura_tarihi)::int) END AS f2,
         CASE WHEN EXTRACT(DAY FROM vade_tarihi)<=12
              THEN make_date(EXTRACT(YEAR FROM vade_tarihi)::int,
                             EXTRACT(DAY FROM vade_tarihi)::int,
                             EXTRACT(MONTH FROM vade_tarihi)::int) END AS v2
    FROM bi_satis_faturalari
   WHERE vade_tarihi IS NOT NULL AND odeme_kosulu IS NOT NULL)
SELECT export_date,
       count(*) FILTER (WHERE gun IS NOT NULL)                       AS test_edilebilir,
       count(*) FILTER (WHERE v-f = gun)                             AS SIMDI_dogru,
       count(*) FILTER (WHERE COALESCE(v2,v)-COALESCE(f2,f) = gun)   AS TAKAS_SONRASI
  FROM v GROUP BY 1 ORDER BY 1;"
echo "  >>> TAKAS_SONRASI >> SIMDI olan HER parti bozuk. Esitse o parti TEMIZ -- ELLEME."

echo
echo "############ 3) IMKANSIZ DEGERLER (bozulmanin parmak izi) ############"
$PSQL -c "
SELECT 'gelecek tarihli fatura' AS bulgu, count(*)::text AS adet,
       max(fatura_tarihi)::text AS en_uc FROM bi_satis_faturalari
 WHERE fatura_tarihi > CURRENT_DATE
UNION ALL SELECT 'vade faturadan ONCE', count(*)::text, min(vade_tarihi-fatura_tarihi)::text
  FROM bi_satis_faturalari WHERE vade_tarihi < fatura_tarihi
UNION ALL SELECT 'miktar >= 1.000 adet', count(*)::text, max(miktar)::text
  FROM bi_satis_faturalari WHERE miktar >= 1000;"
echo "  ^ UCU DE 0 OLMALI."

echo
echo "############ 4) DIGER ERP TABLOLARI — ayni hastalik var mi? ############"
for T in bi_tedarikci_faturalari bi_stok_hareketleri bi_odeme_gecmisi bi_stok_durumu bi_musteri_bakiye; do
  echo "── $T"
  $PSQL -tAc "SELECT string_agg(column_name,',') FROM information_schema.columns
               WHERE table_name='$T' AND data_type IN ('numeric','double precision','integer','bigint')"
  $PSQL -tAc "SELECT string_agg(column_name,',') FROM information_schema.columns
               WHERE table_name='$T' AND data_type LIKE '%date%' OR
                     (table_name='$T' AND data_type LIKE 'timestamp%')"
done

echo
echo "############ 5) MUKERRERLER: ingest kazasi mi, gercek satir mi? ############"
$PSQL -c "
SELECT kez, count(*) AS grup,
       count(*) FILTER (WHERE ayni)     AS birebir_ayni_INGEST_KAZASI,
       count(*) FILTER (WHERE NOT ayni) AS farkli_GERCEK_KALEM
  FROM (SELECT fatura_no, kalem_kodu, count(*) AS kez,
               count(DISTINCT (miktar,birim_fiyat,satir_tutar,export_date))=1 AS ayni
          FROM bi_satis_faturalari GROUP BY 1,2 HAVING count(*)>1) t
 GROUP BY 1 ORDER BY 1;"

echo
echo "############ 6) CIRO: 2026 -- simdi ne cikiyor? ############"
$PSQL -c "
SELECT to_char(fatura_tarihi,'YYYY-MM') AS ay, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari WHERE fatura_tarihi >= '2026-01-01'
 GROUP BY 1 ORDER BY 1;"
echo "  ^ Fatih Bilen 121,79M diyor. Toplam buna yakin mi?"
echo "    satir_tutar METINDEN geldi (saglam) -> ciro DOGRU olabilir,"
echo "    ama AYLARA yanlis dagilmis olabilir. Ustteki dagilima bak."

echo
echo "═══════════════════════════════════════════════════════════════════"
echo " Bu ciktilar gelmeden HICBIR YAZMA yapilmayacak."
echo "═══════════════════════════════════════════════════════════════════"
