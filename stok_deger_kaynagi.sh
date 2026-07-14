#!/usr/bin/env bash
# STOK_DEGER_KAYNAGI — 37 referansi tasimadan once: MALIYET NEREDEN GELECEK?
#
# ⚠ KANITLANDI:
#   bi_stok_anlik (CANLI) tablosunda  birim_maliyet YOK · toplam_deger YOK.
#   Sadece liste_fiyati var. Yani olu tablonun stok DEGERI hesapladigi kolonlarin
#   canlida KARSILIGI HIC YOK. 37 referansi korlemesine cevirseydim, stok degeri
#   hesaplayan her sorgu ya patlardi ya da sessizce LISTE FIYATI uzerinden hesap yapip
#   maliyeti satis fiyati sanardi. Marj %100 goruniirdu.
#
# ⚠ VE OLU TABLO ZATEN BOZUK:
#   bi_stok_durumu stok degerini 1.468,3M gosteriyor. Gercek 268,5M. 5,5 KATI.
#   (x10.000 virgul bozulmasinin izi.)
#   bi_stok_hareketleri'nin en son belge tarihi 5 ARALIK 2026 — bugun 14 Temmuz.
#   GELECEKTE bir tarih. Gun/ay takas bozulmasi.
#
# ⚠ SORU: 268,5M'yi hangi kaynak veriyor? Bulmadan tek satir degistirmem.
# Sadece OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ADAYLAR — maliyet hangi tablolarda var? ############"
$PSQL -c "
SELECT table_name, string_agg(column_name, ', ' ORDER BY column_name) AS maliyet_kolonlari
  FROM information_schema.columns
 WHERE column_name IN ('birim_maliyet','maliyet','toplam_deger','stok_bakiye_tutari','liste_fiyati')
   AND table_name LIKE 'bi_%'
 GROUP BY table_name ORDER BY table_name;"

echo
echo "############ 2) ⚠ STOK DEGERI — dort farkli yoldan hesapla ############"
echo "  (BEKLENEN: ~268,5M. Sapan yol, YANLIS yoldur.)"

echo
echo "  --- YOL A: olu tablo (bi_stok_durumu.toplam_deger) ---"
$PSQL -c "
SELECT round(sum(toplam_deger)/1e6, 1) AS deger_M, count(*) AS satir, max(export_date) AS tarih
  FROM bi_stok_durumu WHERE tenant_id='$T'::uuid
   AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id='$T'::uuid);"

echo "  --- YOL B: canli stok × SON SATINALMA maliyeti (bi_maliyet_sku) ---"
$PSQL -c "
SELECT round(sum(a.adet * m.birim_maliyet)/1e6, 1) AS deger_M,
       count(*) FILTER (WHERE m.birim_maliyet IS NOT NULL) AS maliyeti_olan_sku,
       count(*) FILTER (WHERE m.birim_maliyet IS NULL)     AS maliyeti_OLMAYAN_sku
  FROM bi_stok_anlik a
  LEFT JOIN bi_maliyet_sku m ON m.tenant_id=a.tenant_id AND m.kalem_kodu=a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);" 2>/dev/null \
 || echo "    (bi_maliyet_sku yok veya kolon adi farkli)"

echo "  --- YOL C: canli stok × HAREKET maliyeti (bi_stok_hareket son birim_maliyet) ---"
$PSQL -c "
WITH son_maliyet AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet
    FROM bi_stok_hareket
   WHERE tenant_id='$T'::uuid AND birim_maliyet > 0
   ORDER BY kalem_kodu, belge_tarihi DESC
)
SELECT round(sum(a.adet * s.birim_maliyet)/1e6, 1) AS deger_M,
       count(*) FILTER (WHERE s.birim_maliyet IS NULL) AS maliyeti_OLMAYAN_sku
  FROM bi_stok_anlik a
  LEFT JOIN son_maliyet s ON s.kalem_kodu = a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);"

echo "  --- YOL D: canli stok × LISTE FIYATI (⚠ maliyet DEGIL, satis fiyati) ---"
$PSQL -c "
SELECT round(sum(adet * liste_fiyati)/1e6, 1) AS deger_M
  FROM bi_stok_anlik WHERE tenant_id='$T'::uuid
   AND export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);"
echo "    ⚠ Bu YANLIS bir yol. Sadece 'yanlissa ne kadar sapardik' diye olcuyorum."

echo
echo "############ 3) ADET MUTABAKATI — iki tablo ayni stogu mu sayiyor? ############"
$PSQL -c "
SELECT 'bi_stok_durumu (OLU)' k, count(DISTINCT kalem_kodu) sku, round(sum(eldeki_miktar)) adet, max(export_date) tarih
  FROM bi_stok_durumu WHERE tenant_id='$T'::uuid
   AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id='$T'::uuid)
UNION ALL
SELECT 'bi_stok_anlik (CANLI)', count(DISTINCT kalem_kodu), round(sum(adet)), max(export_date)
  FROM bi_stok_anlik WHERE tenant_id='$T'::uuid
   AND export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);"
echo "  ⚠ Adetler cok farkliysa iki tablo AYNI SEYI saymiyor demektir."
echo "     (olu tabloda HAMMADDE/YARDIMCI MALZEME de olabilir; canli sadece lastik?)"

echo
echo "############ 4) OLU TABLODA NE VAR? — grup dagilimi ############"
$PSQL -c "
SELECT grup_adi, count(*) sku, round(sum(eldeki_miktar)) adet, round(sum(toplam_deger)/1e6,1) deger_M
  FROM bi_stok_durumu WHERE tenant_id='$T'::uuid
   AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id='$T'::uuid)
 GROUP BY 1 ORDER BY 4 DESC NULLS LAST LIMIT 8;"
echo "  --- canli ---"
$PSQL -c "
SELECT grup_adi, count(*) sku, round(sum(adet)) adet
  FROM bi_stok_anlik WHERE tenant_id='$T'::uuid
   AND export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid)
 GROUP BY 1 ORDER BY 3 DESC LIMIT 8;"
