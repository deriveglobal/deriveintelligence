#!/usr/bin/env bash
# METRIK 3C — %13 fark YONTEM mi KAPSAM mi? Ayni kalem kumesinde kiyasla. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_maliyet_ay tazelik + kapsam (hangi ay, kac kalem)"
$PSQL -c "SELECT max(ay) son_ay, count(DISTINCT kalem_kodu) kalem FROM bi_maliyet_ay WHERE tenant_id='$T'::uuid;"

hr "2. KAPSAM — her yontem stok adedinin ne kadarini maliyetliyor?"
$PSQL -c "
WITH son_alis AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric f FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0 ORDER BY kalem_kodu, fatura_tarihi DESC),
may AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet f FROM bi_maliyet_ay WHERE tenant_id='$T'::uuid AND birim_maliyet>0 ORDER BY kalem_kodu, ay DESC)
SELECT round(sum(s.adet)) toplam_adet,
       round(sum(s.adet) FILTER (WHERE sa.f IS NOT NULL)) A_kapsanan,
       round(sum(s.adet) FILTER (WHERE may.f IS NOT NULL)) B_kapsanan,
       round(sum(s.adet) FILTER (WHERE sa.f IS NOT NULL AND may.f IS NOT NULL)) ikisi_de
  FROM bi_stok_anlik s
  LEFT JOIN son_alis sa ON sa.kalem_kodu=s.kalem_kodu
  LEFT JOIN may ON may.kalem_kodu=s.kalem_kodu WHERE s.tenant_id='$T'::uuid;"

hr "3. ⚠ AYNI KUME — ikisinin de maliyetledigi kalemlerde A vs B"
$PSQL -c "
WITH son_alis AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric f FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0 ORDER BY kalem_kodu, fatura_tarihi DESC),
may AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet f FROM bi_maliyet_ay WHERE tenant_id='$T'::uuid AND birim_maliyet>0 ORDER BY kalem_kodu, ay DESC)
SELECT round(sum(s.adet*sa.f)/1e6,1) A_ayni_kume_m,
       round(sum(s.adet*may.f)/1e6,1) B_ayni_kume_m,
       round(100.0*(sum(s.adet*may.f)-sum(s.adet*sa.f))/nullif(sum(s.adet*sa.f),0)) B_A_fark_pct
  FROM bi_stok_anlik s
  JOIN son_alis sa ON sa.kalem_kodu=s.kalem_kodu
  JOIN may ON may.kalem_kodu=s.kalem_kodu WHERE s.tenant_id='$T'::uuid;"
echo "  ⚠ Ayni kumede hala buyuk farksa: YONTEM farki (son alis vs hareketli ort). Kapaniyorsa: KAPSAM."

hr "4. ⚠ Yon — son alis mi dusuk yoksa maliyet_ay mi yuksek? (birkac ornek)"
$PSQL -c "
WITH son_alis AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric f FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0 ORDER BY kalem_kodu, fatura_tarihi DESC),
may AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet f FROM bi_maliyet_ay WHERE tenant_id='$T'::uuid AND birim_maliyet>0 ORDER BY kalem_kodu, ay DESC)
SELECT left(s.kalem_tanimi,34) urun, s.adet,
       round(sa.f) son_alis, round(may.f) maliyet_ay,
       round(100.0*(may.f-sa.f)/nullif(sa.f,0)) fark_pct
  FROM bi_stok_anlik s JOIN son_alis sa ON sa.kalem_kodu=s.kalem_kodu JOIN may ON may.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid AND s.adet>0 ORDER BY s.adet DESC LIMIT 10;"

hr "BITTI"
