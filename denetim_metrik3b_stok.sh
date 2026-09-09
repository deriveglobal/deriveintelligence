#!/usr/bin/env bash
# METRIK 3B — stok degeri DOGRU kolonlarla. grup_adi ile lastik, uc maliyet yontemi capraz. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. grup_adi — LASTIK hangi grup(lar)? (lastik ayrimi buradan)"
$PSQL -c "
SELECT grup_adi, count(*) kalem, round(sum(adet)) adet
  FROM bi_stok_anlik WHERE tenant_id='$T'::uuid
 GROUP BY 1 ORDER BY 3 DESC NULLS LAST;"

hr "2. FONKSIYON — stok degeri, grup_adi kirilimli (son alis maliyeti)"
$PSQL -c "
WITH son_alis AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS fiyat
    FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT COALESCE(s.grup_adi,'(bos)') grup,
       round(sum(s.adet*a.fiyat)/1e6,1) deger_m,
       round(sum(s.adet) FILTER (WHERE a.fiyat IS NULL)) maliyetsiz_adet
  FROM bi_stok_anlik s LEFT JOIN son_alis a ON a.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid GROUP BY 1 ORDER BY 2 DESC NULLS LAST;"

hr "3. ⚠ TOPLAM + maliyetsiz kor nokta"
$PSQL -c "
WITH son_alis AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS fiyat
    FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT round(sum(s.adet*a.fiyat)/1e6,1) AS stok_toplam_m,
       round(sum(s.adet) FILTER (WHERE a.fiyat IS NULL)) AS maliyetsiz_adet,
       count(*) FILTER (WHERE a.fiyat IS NULL) AS maliyetsiz_kalem
  FROM bi_stok_anlik s LEFT JOIN son_alis a ON a.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid;"
echo "  ⚠ maliyetsiz_adet stok degerine GIRMIYOR — kor nokta, gizlenmez."

hr "4. ⚠ CAPRAZ-KONTROL — uc bagimsiz maliyet yontemi ayni mi?"
$PSQL -c "
WITH son_alis AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS f
    FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
may AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet AS f
    FROM bi_maliyet_ay WHERE tenant_id='$T'::uuid AND birim_maliyet>0 ORDER BY kalem_kodu, ay DESC)
SELECT
  round(sum(s.adet*sa.f)/1e6,1)  AS A_son_alis_m,
  round(sum(s.adet*may.f)/1e6,1) AS B_maliyet_ay_m,
  round(sum(s.adet*msku.birim_maliyet)/1e6,1) AS C_maliyet_sku_m
  FROM bi_stok_anlik s
  LEFT JOIN son_alis sa       ON sa.kalem_kodu = s.kalem_kodu
  LEFT JOIN may                ON may.kalem_kodu = s.kalem_kodu
  LEFT JOIN bi_maliyet_sku msku ON msku.sku = s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid;"
echo "  ⚠ A/B/C birbirine yakinsa (birkac %): stok degeri UC yontemle capraz-dogrulandi."
echo "     Uzaksa: maliyet yontemi onemli (son alis vs hareketli ortalama) — SINIR."

hr "BITTI"
