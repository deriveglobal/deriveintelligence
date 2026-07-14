#!/usr/bin/env bash
# STOK_ESLESME — 62 referans tasinacak. Ama once KOLONLARI ESLESTIR.
#
# ⚠ BU BIR YENIDEN ADLANDIRMA DEGIL:
#   bi_stok_durumu      -> bi_stok_anlik     (eldeki_miktar? miktar? birim_maliyet?)
#   bi_stok_hareketleri -> bi_stok_hareket   (hareket_tipi/miktar? giris/cikis/tutar?)
#   Kolonlar farkli VE ANLAMLARI farkli olabilir.
#   Korlemesine degistirirsem STOK DEGERINI bozarim — sirketin en buyuk kalemi (268,5M).
#
# ⚠ VE SATIR SAYILARI TUTMUYOR:
#   bi_stok_durumu 3.146 vs bi_stok_anlik 2.185      -> 961 fark. Neden?
#   bi_stok_hareketleri 358.028 vs bi_stok_hareket 579.771 -> 221.743 fark.
#   "Olu tablo daha az veri iceriyor" diyebilmek icin KANIT lazim, varsayim degil.
#
# Sadece OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) KOLONLAR — yan yana ############"
for P in "bi_stok_durumu:bi_stok_anlik" "bi_stok_hareketleri:bi_stok_hareket"; do
  OLU="${P%%:*}"; CANLI="${P##*:}"
  echo
  echo "  ══════ $OLU (OLU)  vs  $CANLI (CANLI) ══════"
  $PSQL -c "
  SELECT COALESCE(o.column_name, '—') AS olu_kolon, COALESCE(o.data_type,'') AS olu_tip,
         COALESCE(c.column_name, '—') AS canli_kolon, COALESCE(c.data_type,'') AS canli_tip,
         CASE WHEN o.column_name IS NULL THEN '➕ sadece canlida'
              WHEN c.column_name IS NULL THEN '⚠ SADECE OLUDA — karsiligi YOK'
              ELSE '✓' END AS durum
    FROM (SELECT column_name, data_type FROM information_schema.columns WHERE table_name='$OLU') o
    FULL OUTER JOIN
         (SELECT column_name, data_type FROM information_schema.columns WHERE table_name='$CANLI') c
      ON c.column_name = o.column_name
   ORDER BY durum, 1;"
done

echo
echo "############ 2) ⚠ TAZELIK — hangisi guncel? ############"
$PSQL -c "
SELECT 'bi_stok_durumu (OLU)'  t, count(*) satir, max(export_date)::text son FROM bi_stok_durumu
UNION ALL SELECT 'bi_stok_anlik (CANLI)', count(*), max(export_date)::text FROM bi_stok_anlik
UNION ALL SELECT 'bi_stok_hareketleri (OLU)', count(*), max(belge_tarihi)::text FROM bi_stok_hareketleri
UNION ALL SELECT 'bi_stok_hareket (CANLI)', count(*), max(belge_tarihi)::text FROM bi_stok_hareket;"

echo
echo "############ 3) ⚠⚠ STOK DEGERI — iki tablo AYNI SEYI mi soyluyor? ############"
echo "  (sirketin en buyuk kalemi. Yanlis tabloya gecersem 268,5M'yi bozarim.)"
$PSQL -c "
SELECT 'bi_stok_durumu (OLU)' AS kaynak,
       count(DISTINCT kalem_kodu) AS sku,
       round(sum(eldeki_miktar))  AS adet,
       round(sum(toplam_deger)/1e6, 1) AS deger_M
  FROM bi_stok_durumu
 WHERE export_date = (SELECT max(export_date) FROM bi_stok_durumu);"
echo "  --- bi_stok_anlik kolonlari neydi? (varsaymadan) ---"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_stok_anlik' ORDER BY ordinal_position;"
$PSQL -x -c "SELECT * FROM bi_stok_anlik LIMIT 1;"

echo
echo "############ 4) HAREKET — ayni SKU, iki tablo ############"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_stok_hareketleri' ORDER BY ordinal_position;"
$PSQL -x -c "SELECT * FROM bi_stok_hareketleri ORDER BY belge_tarihi DESC LIMIT 1;"
echo "  --- canli ---"
$PSQL -x -c "SELECT * FROM bi_stok_hareket ORDER BY belge_tarihi DESC LIMIT 1;"

echo
echo "⚠ CIKTIYI GONDER. Eslesmeyi GORMEDEN 62 referansa dokunmam."
