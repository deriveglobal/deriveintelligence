#!/usr/bin/env bash
# KURU CALISMA #2 — hala HICBIR SEY YAZMAZ.
# Onceki turda IKI testim hataliydi. Duzeltilmis halleri burada.
#   1) parti testi patladi   : odeme_kosulu metin ("Pesin - Kredi Karti...")
#                              regex tum rakamlari yapistirdi -> int tasti.
#   2) mukerrer testi yaniltti: karsilastirmaya export_date'i KOYDUM.
#                              Ayni satir 2 kez yuklendiyse export_date farkli
#                              olur ve "gercek ayri kalem" gibi gorunur. YANLIS.
# Ayrica: SAYILAR DB'de SAGLAM cikti (102.367/102.574). Sayiya DOKUNULMAYACAK.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ INGEST TARIHI NASIL OKUYOR? (asil suclu) ############"
echo "  Sayilari dogru okuyor ama tarihi okuyamiyor. Kodu gorelim:"
grep -n "satis_faturalari" /opt/krb-assessment/server_container.mjs | head -5
echo "  -- tarih ayristirma fonksiyonlari --"
grep -n "parseDate\|toDate\|_tarih\|dateFrom\|new Date(\|XLSX.read\|cellDates\|sheet_to_json" \
     /opt/krb-assessment/server_container.mjs | head -25
echo "  -- sayi ayristirma (BU CALISIYOR -- ornek alacagiz) --"
grep -n "parseNum\|_sayi\|replace(/\\\\./g\|toplamaSayi\|trNum" \
     /opt/krb-assessment/server_container.mjs | head -10

echo
echo "############ 2) PARTI TESTI (duzeltilmis: sadece 'NN Gun' kaliplari) ############"
$PSQL -c "
WITH v AS (
  SELECT export_date, fatura_tarihi f, vade_tarihi v,
         (regexp_match(odeme_kosulu, '^\s*(\d{1,3})\s*[Gg]'))[1]::int AS gun,
         CASE WHEN EXTRACT(DAY FROM fatura_tarihi)<=12
              THEN make_date(EXTRACT(YEAR FROM fatura_tarihi)::int,
                             EXTRACT(DAY FROM fatura_tarihi)::int,
                             EXTRACT(MONTH FROM fatura_tarihi)::int) END AS f2,
         CASE WHEN EXTRACT(DAY FROM vade_tarihi)<=12
              THEN make_date(EXTRACT(YEAR FROM vade_tarihi)::int,
                             EXTRACT(DAY FROM vade_tarihi)::int,
                             EXTRACT(MONTH FROM vade_tarihi)::int) END AS v2
    FROM bi_satis_faturalari
   WHERE vade_tarihi IS NOT NULL
     AND odeme_kosulu ~ '^\s*\d{1,3}\s*[Gg]')
SELECT export_date,
       count(*)                                                    AS test_edilebilir,
       count(*) FILTER (WHERE v - f = gun)                         AS SIMDI_dogru,
       count(*) FILTER (WHERE COALESCE(v2,v)-COALESCE(f2,f) = gun) AS TAKAS_SONRASI,
       round(100.0*count(*) FILTER (WHERE COALESCE(v2,v)-COALESCE(f2,f) = gun)
             /NULLIF(count(*),0)) AS takas_basari_yuzde
  FROM v GROUP BY 1 ORDER BY 1;"
echo "  >>> Her partide TAKAS_SONRASI >> SIMDI ise: TUM partiler bozuk, hepsini onar."
echo "  >>> Bir partide SIMDI zaten yuksekse: O PARTI TEMIZ. Onu HARIC TUT."

echo
echo "############ 3) MUKERRER (duzeltilmis: export_date HARIC) ############"
$PSQL -c "
SELECT kez, count(*) AS grup,
       count(*) FILTER (WHERE ayni_veri)     AS AYNI_SATIR_yeniden_yukleme,
       count(*) FILTER (WHERE NOT ayni_veri) AS FARKLI_gercek_kalem
  FROM (SELECT fatura_no, kalem_kodu, count(*) AS kez,
               count(DISTINCT (miktar, birim_fiyat, satir_tutar)) = 1 AS ayni_veri
          FROM bi_satis_faturalari GROUP BY 1,2 HAVING count(*) > 1) t
 GROUP BY 1 ORDER BY 1;"
echo "  -- ayni fatura+kalem KAC FARKLI export_date'te var? (yeniden yukleme izi) --"
$PSQL -c "
SELECT kac_export, count(*) AS grup FROM (
  SELECT fatura_no, kalem_kodu, count(DISTINCT export_date) AS kac_export
    FROM bi_satis_faturalari GROUP BY 1,2) t
 WHERE kac_export > 1 GROUP BY 1 ORDER BY 1;"
echo "  ^ >1 cikan varsa: ayni fatura birden fazla export'ta -> mukerrer YUKLEME var."

echo
echo "############ 4) ⚠ CIRO TUTARSIZLIGI — 121,79M mi, 308M mi? ############"
echo "  2026 toplamim 308M cikti. Fatih Bilen 121,79M diyor. Biri yanlis."
$PSQL -c "
SELECT count(*) AS satir,
       round(sum(satir_tutar)/1e6,2)                              AS ham_toplam_MTL,
       round(sum(satir_tutar) FILTER (WHERE satir_tutar>0)/1e6,2) AS sadece_pozitif,
       round(sum(satir_tutar) FILTER (WHERE satir_tutar<0)/1e6,2) AS iadeler,
       count(DISTINCT export_date)                                AS kac_export
  FROM bi_satis_faturalari WHERE fatura_tarihi >= '2026-01-01';"
echo "  -- export_date basina ciro (ayni veri 2 kez sayiliyor mu?) --"
$PSQL -c "
SELECT export_date, count(*) AS satir, round(sum(satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari WHERE fatura_tarihi >= '2026-01-01'
 GROUP BY 1 ORDER BY 1;"
echo "  -- TEKILLESTIRILMIS ciro (ayni fatura+kalem bir kez) --"
$PSQL -c "
SELECT round(sum(tutar)/1e6,2) AS tekil_ciro_MTL FROM (
  SELECT DISTINCT ON (fatura_no, kalem_kodu, miktar, birim_fiyat)
         satir_tutar AS tutar
    FROM bi_satis_faturalari WHERE fatura_tarihi >= '2026-01-01'
   ORDER BY fatura_no, kalem_kodu, miktar, birim_fiyat) t;"
echo "  ^ Bu 121,79M'e yaklasiyorsa: ciro sisme sebebi MUKERRER YUKLEME."

echo
echo "############ 5) accountriskreport: 48.416 satir -> 399 satirlik tablo? ############"
$PSQL -c "
SELECT count(*) AS satir, count(DISTINCT musteri_kodu) AS musteri,
       max(export_date) AS son_export,
       round(sum(vadesi_gecmis_tutar)/1e6,2) AS vadesi_gecmis_MTL
  FROM bi_musteri_bakiye;"
echo "  ^ Excel'de 48.416 satir var (muhtemelen musteri x fatura)."
echo "    DB'de 399 musteri. Ozetleniyor mu, yoksa %99 DUSUYOR mu?"

echo
echo "═══════════════════════════════════════════════════════════════"
echo " KARAR: sayilar SAGLAM. Sadece TARIH onarilacak."
echo " Once bu ciktilar. Sonra tek islemde UPDATE + geri alma yedegi."
echo "═══════════════════════════════════════════════════════════════"
