#!/usr/bin/env bash
# STOK_GERCEK_DEGER — 268,5M'nin TANIMI bulundu. Simdi DOGRULUGUNU olcuyorum.
#
# ✅ IYI HABER: 268,5M uydurma DEGIL.
#   Ana sayfa (23807-23819) stogu soyle degerliyor:
#     her SKU icin TEDARIKCI FATURASINDAKI EN SON birim_fiyat_kdv_haric × eldeki adet
#   Yani ERP'nin supheli "maliyet" kolonunu KULLANMIYOR. Yontem SAGLAM.
#
# ⚠ AMA DUN KENDIMIZ BULMUSTUK:
#   birim_fiyat_kdv_haric = SATIR ISKONTOSUNDAN ONCEKI fiyat.
#     Miktar × Birim Fiyat                  -> Satir Toplami ile %46 tutuyor
#     Miktar × Birim Fiyat × (1 - iskonto%) -> %97,8 tutuyor
#   Toplamda: liste 843,8M · fiilen odenen 576,4M -> %46,4 SISKINLIK.
#   Yani 268,5M ISKONTO ONCESI fiyatla hesaplanmis. Gercek ODENEN fiyatla DAHA DUSUK cikar.
#
# ⚠ VE MALIYET CURUKLUGU OLCULDU:
#   2.129 SKU'nun 289'unda maliyet = liste fiyati BIREBIR AYNI
#   118'inde maliyet liste fiyatinin USTUNDE  -> %19'u anlamsiz.
#   (Maliyeti satis fiyatindan yuksek urun, her satista zarar ediyor gorunur.)
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) bi_tedarikci_faturalari — GERCEK kolon adlari ############"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_tedarikci_faturalari' ORDER BY ordinal_position;"
$PSQL -x -c "SELECT * FROM bi_tedarikci_faturalari ORDER BY fatura_tarihi DESC LIMIT 1;"

echo
echo "############ 2) ⚠⚠ STOK DEGERI — ALTI YOL YAN YANA ############"
$PSQL -c "
WITH
-- YOL 1: ana sayfanin bugun kullandigi (ISKONTO ONCESI birim fiyat)
y1 AS (
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku, birim_fiyat_kdv_haric f
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$T'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
   ORDER BY 1, fatura_tarihi DESC),
-- YOL 2: GERCEKTEN ODENEN (satir toplami / miktar)  ← dogru olan bu
y2 AS (
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku,
         toplam_tutar / NULLIF(miktar,0) f
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$T'::uuid AND miktar>0 AND toplam_tutar>0
   ORDER BY 1, fatura_tarihi DESC),
-- YOL 3: ERP hareket maliyeti (supheli)
y3 AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu sku, birim_maliyet f
    FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND birim_maliyet>0
   ORDER BY kalem_kodu, belge_tarihi DESC),
s AS (
  SELECT bi_sku_norm(kalem_kodu) sku, kalem_kodu, adet, liste_fiyati
    FROM bi_stok_anlik
   WHERE tenant_id='$T'::uuid AND adet>0
     AND export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid))
SELECT
  round(sum(s.adet * y1.f)/1e6, 1) AS \"1_iskonto_ONCESI (ekranda)\",
  round(sum(s.adet * y2.f)/1e6, 1) AS \"2_GERCEK_ODENEN\",
  round(sum(s.adet * y3.f)/1e6, 1) AS \"3_ERP_maliyeti\",
  round(sum(s.adet * s.liste_fiyati)/1e6, 1) AS \"4_liste_fiyati\"
  FROM s
  LEFT JOIN y1 ON y1.sku=s.sku
  LEFT JOIN y2 ON y2.sku=s.sku
  LEFT JOIN y3 ON y3.sku=s.kalem_kodu;" 2>&1 | head -8

echo
echo "############ 3) ⚠ KAPSAM — kac SKU'nun tedarikci faturasi VAR? ############"
$PSQL -c "
WITH y1 AS (
  SELECT DISTINCT bi_sku_norm(kalem_kodu) sku FROM bi_tedarikci_faturalari
   WHERE tenant_id='$T'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0)
SELECT count(*) AS stoktaki_sku,
       count(*) FILTER (WHERE y1.sku IS NOT NULL) AS faturasi_VAR,
       count(*) FILTER (WHERE y1.sku IS NULL)     AS faturasi_YOK,
       round(sum(a.adet) FILTER (WHERE y1.sku IS NULL)) AS faturasiz_adet
  FROM bi_stok_anlik a
  LEFT JOIN y1 ON y1.sku = bi_sku_norm(a.kalem_kodu)
 WHERE a.tenant_id='$T'::uuid AND a.adet>0
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);"
echo "  ⚠ 'faturasi_YOK' buyukse: o stok DEGERSIZ sayiliyor (0 TL) — stok DUSUK gorunur."
echo "     268,5M eksik olabilir cunku faturasi olmayan SKU'lar hic sayilmiyor."

echo
echo "############ 4) ⚠ SAP'IN KENDI DEFTERI — 433,9M neyi iceriyor? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (depo, kalem_kodu) depo, kalem_kodu, grup_adi, stok_bakiye_tutari
    FROM bi_stok_hareket WHERE tenant_id='$T'::uuid
   ORDER BY depo, kalem_kodu, belge_tarihi DESC, ingested_at DESC)
SELECT grup_adi, count(*) AS sku, round(sum(stok_bakiye_tutari)/1e6, 1) AS deger_M
  FROM son GROUP BY 1 ORDER BY 3 DESC NULLS LAST LIMIT 10;"
echo "  ⚠ Lastik disi gruplar varsa: 433,9M ile 268,5M FARKLI KAPSAM demektir."
echo "     Biri 'tum stok', digeri 'sadece lastik'. Ikisi de dogru olabilir."
