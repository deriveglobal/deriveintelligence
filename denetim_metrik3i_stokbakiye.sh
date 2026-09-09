#!/usr/bin/env bash
# METRIK 3I — ERP'nin KENDI stok degeri (stok_bakiye_tutari). Reconstruction degil, ERP defteri. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ERP KENDI STOK DEGERI — her kalemin SON stok_bakiye_tutari toplami"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, stok_bakiye_tutari, belge_tarihi, giris-cikis
    FROM bi_stok_hareket WHERE tenant_id='$T'::uuid
   ORDER BY kalem_kodu, belge_tarihi DESC, ingested_at DESC)
SELECT round(sum(stok_bakiye_tutari)/1e6,1) AS erp_stok_degeri_m,
       count(*) kalem,
       round(sum(stok_bakiye_tutari) FILTER (WHERE stok_bakiye_tutari<0)/1e6,1) AS negatif_m
  FROM son;"
echo "  ⚠ Bu ERP'nin KENDI stok bakiye degeri. 274 (son alis) mi 309 (kup) mu hangisine yakin?"

hr "2. ⚠ UC SAYIYI YAN YANA"
echo "  son_alis reconstruction : ~274 M"
echo "  kup (maliyet_ay)        : ~309 M"
$PSQL -c "
WITH son AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, stok_bakiye_tutari FROM bi_stok_hareket WHERE tenant_id='$T'::uuid ORDER BY kalem_kodu, belge_tarihi DESC, ingested_at DESC)
SELECT round(sum(stok_bakiye_tutari)/1e6,1) AS ERP_stok_bakiye_m FROM son;"

hr "3. ⚠ TUTARLILIK — ERP stok bakiye adedi, bi_stok_anlik adediyle uyuyor mu?"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu,
         SUM(giris-cikis) OVER (PARTITION BY kalem_kodu) AS hesap_bakiye, stok_bakiye_tutari
    FROM bi_stok_hareket WHERE tenant_id='$T'::uuid ORDER BY kalem_kodu, belge_tarihi DESC, ingested_at DESC)
SELECT round((SELECT sum(adet) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid)) AS stok_anlik_adet;"
echo "  (bi_stok_anlik toplam adet — ERP hareket bakiyesiyle kabaca uyusmali)"

hr "4. ⚠ SAILUN kalemi — ERP stok_bakiye_tutari / adet = birim (699 mu 1501 mi?)"
$PSQL -c "
SELECT belge_tarihi, round(stok_bakiye_tutari) stok_deger, round(birim_maliyet) birim_maliyet, giris, cikis
  FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu='3220004884-25'
 ORDER BY belge_tarihi DESC LIMIT 5;"
echo "  ⚠ stok_bakiye_tutari / stok adedi = ERP'nin bu kalemi birim kac tuttugu."

hr "BITTI — ERP kendi defterinde stogu kaca tasiyorsa, dogru sayi O"
