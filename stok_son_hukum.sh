#!/usr/bin/env bash
# STOK_SON_HUKUM — uc yol, DOGRU kolonlarla, DOGRU kapsamla.
#
# ⚠ IKI SEYI GERI CEKIYORUM:
#   1. "SAP 433,9M diyor" — YANLIS. Sorgum, gecmiste bir kez hareket gormus ama
#      BUGUN STOKTA OLMAYAN her kalemi de sayiyordu (LASTIK TUKETICI'de 21.420 SKU
#      gorunuyor, oysa guncel stokta 1.883 var). Yontem hatasi, yine benim.
#   2. "268,5M eksik olabilir, faturasiz SKU'lar sifir sayiliyor" — YANLIS.
#      2.185 SKU'nun 2.177'sinin faturasi VAR. Sadece 8'i faturasiz (523 adet).
#
# ⚠ GERIYE TEK GERCEK SORU KALDI:
#   Ana sayfa ISKONTO ONCESI birim fiyat kullaniyor (birim_fiyat_kdv_haric).
#   GERCEKTEN ODENEN = satir_kdv_haric / miktar.
#   Dun olcmustuk: iskonto oncesi fiyat %46,4 SISKIN (liste 843,8M vs odenen 576,4M).
#   Oyleyse 268,5M de SISKIN olmali. NE KADAR?
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠⚠ STOK DEGERI — DORT YOL, DOGRU KOLONLARLA ############"
$PSQL -c "
WITH
y1 AS (  -- ekranda: ISKONTO ONCESI birim fiyat
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku, birim_fiyat_kdv_haric f
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$T'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
   ORDER BY 1, fatura_tarihi DESC),
y2 AS (  -- ⚠ GERCEKTEN ODENEN: satir toplami / miktar
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku,
         satir_kdv_haric / NULLIF(miktar,0) f
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$T'::uuid AND miktar>0 AND satir_kdv_haric>0
   ORDER BY 1, fatura_tarihi DESC),
y3 AS (  -- ERP hareket maliyeti (SUPHELI: %19'u bozuk)
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu sku, birim_maliyet f
    FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND birim_maliyet>0
   ORDER BY kalem_kodu, belge_tarihi DESC),
s AS (
  SELECT bi_sku_norm(kalem_kodu) nsku, kalem_kodu, adet, liste_fiyati
    FROM bi_stok_anlik
   WHERE tenant_id='$T'::uuid AND adet>0
     AND export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid))
SELECT round(sum(s.adet * y1.f)/1e6, 1)          AS iskonto_ONCESI_ekranda,
       round(sum(s.adet * y2.f)/1e6, 1)          AS GERCEKTEN_ODENEN,
       round(sum(s.adet * y3.f)/1e6, 1)          AS ERP_maliyeti,
       round(sum(s.adet * s.liste_fiyati)/1e6,1) AS liste_fiyati,
       round(100.0 * (sum(s.adet*y1.f) - sum(s.adet*y2.f)) / NULLIF(sum(s.adet*y2.f),0), 1) AS ekran_siskinligi_pct
  FROM s
  LEFT JOIN y1 ON y1.sku = s.nsku
  LEFT JOIN y2 ON y2.sku = s.nsku
  LEFT JOIN y3 ON y3.sku = s.kalem_kodu;"

echo
echo "############ 2) SAP DEFTERI — DOGRU KAPSAM (sadece BUGUN stokta olanlar) ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (h.depo, h.kalem_kodu) h.depo, h.kalem_kodu, h.stok_bakiye_tutari, h.belge_tarihi
    FROM bi_stok_hareket h
   WHERE h.tenant_id='$T'::uuid
     AND EXISTS (SELECT 1 FROM bi_stok_anlik a
                  WHERE a.tenant_id=h.tenant_id AND a.kalem_kodu=h.kalem_kodu AND a.adet>0
                    AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid))
   ORDER BY h.depo, h.kalem_kodu, h.belge_tarihi DESC, h.ingested_at DESC)
SELECT count(*) AS depo_sku_cifti,
       round(sum(stok_bakiye_tutari)/1e6, 1) AS sap_defteri_M,
       min(belge_tarihi) AS en_eski_hareket
  FROM son;"
echo "  ⚠ 'en_eski_hareket' cok eskiyse, o bakiye BAYAT — SAP defteri diye sunulamaz."

echo
echo "############ 3) ⚠ HANGI SKU'LARDA ISKONTO BUYUK? (ekranin sismesi nereden) ############"
$PSQL -c "
WITH y1 AS (
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku, kalem_tanimi, marka,
         birim_fiyat_kdv_haric f1, satir_kdv_haric/NULLIF(miktar,0) f2
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$T'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0 AND satir_kdv_haric>0
   ORDER BY 1, fatura_tarihi DESC)
SELECT left(y1.kalem_tanimi,34) AS urun, y1.marka, s.adet,
       round(y1.f1) AS iskonto_oncesi, round(y1.f2) AS gercekten_odenen,
       round(100.0*(y1.f1-y1.f2)/NULLIF(y1.f1,0),1) AS iskonto_pct,
       round(s.adet*(y1.f1-y1.f2)/1e6, 1) AS fark_M
  FROM bi_stok_anlik s
  JOIN y1 ON y1.sku = bi_sku_norm(s.kalem_kodu)
 WHERE s.tenant_id='$T'::uuid AND s.adet>0
   AND s.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid)
 ORDER BY s.adet*(y1.f1-y1.f2) DESC NULLS LAST LIMIT 8;"

echo
echo "############ 4) MARKA BAZINDA ISKONTO — hangi tedarikci ne veriyor? ############"
$PSQL -c "
SELECT marka,
       count(*) AS fatura_satiri,
       round(avg(100.0*(birim_fiyat_kdv_haric - satir_kdv_haric/NULLIF(miktar,0))
             / NULLIF(birim_fiyat_kdv_haric,0)), 1) AS ort_iskonto_pct
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$T'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0 AND satir_kdv_haric>0
   AND grup_adi LIKE 'LASTIK%'
   AND fatura_tarihi >= current_date - 365
 GROUP BY 1 HAVING count(*) > 20
 ORDER BY 3 DESC NULLS LAST LIMIT 12;"
echo "  ⚠ Bu, KRB'nin her markadan aldigi GERCEK satir iskontosu."
