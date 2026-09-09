#!/usr/bin/env bash
# BORÇ GEÇMİŞİ KURULABİLİR Mİ — odeme_tarihi + bi_odeme_gecmisi ile reconstruct test. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_tedarikci_faturalari — TÜM kolonlar (tutar + ödeme alanları)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_tedarikci_faturalari' ORDER BY ordinal_position;"

hr "2. odeme_durumu değerleri + odeme_tarihi doluluk + fatura_tarihi aralığı"
$PSQL -c "SELECT odeme_durumu, count(*), count(odeme_tarihi) odeme_tarihi_dolu FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 2 DESC;"
$PSQL -c "SELECT min(fatura_tarihi)::text ilk, max(fatura_tarihi)::text son FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid;"

hr "3. bi_odeme_gecmisi — kolonlar + satır + tarih aralığı (ödeme defteri mi?)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='bi_odeme_gecmisi' ORDER BY ordinal_position;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT count(*), min(ingested_at)::text FROM bi_odeme_gecmisi WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "4. ⚠ RECONSTRUCTION TEST — bugün ödenmemiş tedarikçi faturaları ≈ 403M mü? (net; brüt ~×1,2)"
$PSQL -c "
SELECT round(sum(satir_kdv_haric) FILTER (WHERE odeme_tarihi IS NULL OR odeme_tarihi > CURRENT_DATE)/1e6,1) acik_net_m,
       round(sum(satir_kdv_haric)/1e6,1) tum_net_m,
       count(*) FILTER (WHERE odeme_tarihi IS NULL OR odeme_tarihi > CURRENT_DATE) acik_satir
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid;"
echo "  ⚠ acik_net ~336M (403/1,2) civarıysa reconstruction TUTUYOR → borç geçmişi kurulabilir."

hr "5. ⚠ GEÇMİŞ BORÇ — çeyrek çeyrek açık tedarikçi bakiyesi (trend mantıklı mı?)"
for D in 2025-07-01 2025-10-01 2026-01-01 2026-04-01 2026-07-01; do
  V=$($PSQL -tAc "
    SELECT round(sum(satir_kdv_haric)/1e6,1) FROM bi_tedarikci_faturalari
     WHERE tenant_id='$T'::uuid AND fatura_tarihi <= '$D'
       AND (odeme_tarihi IS NULL OR odeme_tarihi > '$D')" | tr -d '[:space:]')
  printf "    %s : ~%s M net (brüt ~×1,2)\n" "$D" "$V"
done
echo "  ⚠ Yumuşak, mantıklı trend ise borç DSO/stok gibi kurulur (geçmiş=yaklaşık)."

hr "BITTI — borç geçmişi kurulabiliyorsa iddiamı düzeltir, backfill'i kurarım."
