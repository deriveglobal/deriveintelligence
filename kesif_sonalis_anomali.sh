#!/usr/bin/env bash
# SON_ALIS ANOMALİSİ — 40.847 neden? Ham giriş satırları + anomali yaygın mı. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. O SKU'nun HAM giriş satırları — 315/70R22.5 156 (belge, adet, tutar, birim)"
$PSQL -c "
SELECT h.belge_tarihi, h.belge_no, h.giris adet, round(h.giris_tutari) tutar, round(h.giris_tutari/NULLIF(h.giris,0)) birim, h.kalem_kodu
  FROM bi_stok_hareket h
 WHERE h.tenant_id='$T'::uuid AND h.giris>0
   AND h.kalem_kodu IN (SELECT DISTINCT kalem_kodu FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND kalem_tanimi ILIKE '%315/70R22.5%156%')
 ORDER BY h.belge_tarihi DESC LIMIT 20;" 2>&1 | sed 's/^/  /'

hr "2. ANOMALİ YAYGIN MI — CONTINENTAL SKU'larında son_alis birim, son6ay'ın kaç katı (>2× kaç SKU)"
$PSQL -c "
WITH son6 AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 AND belge_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY kalem_kodu),
sonalis AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, giris_tutari/NULLIF(giris,0) c, giris adet_son FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 ORDER BY kalem_kodu, belge_tarihi DESC),
cnt AS (SELECT DISTINCT kalem_kodu FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL)
SELECT count(*) toplam_sku,
       count(*) FILTER (WHERE sa.c > s6.c*2) son_alis_2x_ustu,
       count(*) FILTER (WHERE sa.adet_son<=2) son_giris_adet_kucuk,
       round(avg(sa.c/NULLIF(s6.c,0)),2) ort_oran
  FROM cnt JOIN son6 s6 USING(kalem_kodu) JOIN sonalis sa USING(kalem_kodu) WHERE s6.c>0;" 2>&1 | sed 's/^/  /'

hr "3. KÜÇÜK-ADET GİRİŞ tuzağı mı — CONTINENTAL, son giriş adedi ≤2 olanlarda birim şişiyor mu"
$PSQL -c "
WITH son6 AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 AND belge_tarihi>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY kalem_kodu),
sonalis AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, giris_tutari/NULLIF(giris,0) c, giris adet_son, belge_tarihi FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 ORDER BY kalem_kodu, belge_tarihi DESC),
cnt AS (SELECT DISTINCT kalem_kodu FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL)
SELECT sa.adet_son son_giris_adet, round(sa.c) son_alis_birim, round(s6.c) son6ay_birim, round(sa.c/NULLIF(s6.c,0),1) oran, sa.kalem_kodu
  FROM cnt JOIN son6 s6 USING(kalem_kodu) JOIN sonalis sa USING(kalem_kodu)
 WHERE s6.c>0 AND sa.c>s6.c*1.5 ORDER BY oran DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "BITTI — 40.847'nin kaynağı (küçük adet mi, hatalı tutar mı, gerçek pahalı alış mı) + yaygınlık net."
