#!/usr/bin/env bash
# LASSA adet/ciro tutarsızlığı: birim fiyat gerçek mi, adet doğru mu, ebatlar kamyon mu. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. LASSA birim ekonomisi — son 6 kapanmış ay (Oca–Haz 2026)"
$PSQL -c "
SELECT count(*) satir, sum(miktar)::numeric adet, round(sum(satir_tutar)/1e6,2) ciro_m,
       round(sum(satir_tutar)/NULLIF(sum(miktar),0)) birim_ort,
       round(min(birim_fiyat)) fiyat_min, round(max(birim_fiyat)) fiyat_max,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)) fiyat_medyan
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND ebat IS NOT NULL AND upper(marka)='LASSA'
   AND fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - interval '6 month') AND fatura_tarihi < date_trunc('month',CURRENT_DATE);" 2>&1 | sed 's/^/  /'

hr "2. miktar × birim_fiyat ≈ satir_tutar mı — 10 örnek LASSA satırı"
$PSQL -c "
SELECT left(kalem_tanimi,26) kalem, ebat, miktar, round(birim_fiyat) birim_fiyat, round(satir_tutar) satir_tutar,
       round(satir_tutar/NULLIF(miktar,0)) tutar_bolu_miktar
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND ebat IS NOT NULL AND upper(marka)='LASSA'
   AND fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - interval '6 month')
 ORDER BY satir_tutar DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "3. LASSA ebat dağılımı — kamyon mu binek mi (ilk 12, adet + ort fiyat)"
$PSQL -c "
SELECT ebat, sum(miktar)::numeric adet, round(avg(birim_fiyat)) ort_fiyat
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND ebat IS NOT NULL AND upper(marka)='LASSA'
   AND fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - interval '6 month')
 GROUP BY ebat ORDER BY adet DESC NULLS LAST LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "4. miktar tuhaflığı — negatif/ondalık/sıfır var mı (iade? birim karışık mı)"
$PSQL -c "
SELECT sign(miktar) isaret, count(*), min(miktar) mn, max(miktar) mx,
       count(*) FILTER (WHERE miktar<>round(miktar)) ondalikli
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND ebat IS NOT NULL AND upper(marka)='LASSA'
   AND fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - interval '6 month')
 GROUP BY 1 ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "5. ÇAPRAZ — omurga ciro_lastik×LASSA (üst tablo) vs satis_faturalari (drill) aynı mı"
$PSQL -c "
SELECT 'omurga' k, round(sum(deger)/1e6,2) ciro_m FROM bi_metrik_gecmis
 WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND boyut_tipi='marka' AND boyut_deger='LASSA'
   AND donem >= (date_trunc('month',CURRENT_DATE) - interval '6 month') AND donem < date_trunc('month',CURRENT_DATE)
UNION ALL
SELECT 'satis_fat', round(sum(satir_tutar)/1e6,2) FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND ebat IS NOT NULL AND upper(marka)='LASSA'
   AND fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - interval '6 month') AND fatura_tarihi < date_trunc('month',CURRENT_DATE);" 2>&1 | sed 's/^/  /'

hr "BITTI — birim fiyat gerçekse kamyon; adet düşükse miktar/birim tuzağı."
