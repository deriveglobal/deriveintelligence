#!/usr/bin/env bash
# LASSA KIŞ örnek SKU — liste fiyatı vs bizim maliyet vs satış vs marj vs fatura-altı. READ-ONLY.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_fiyat_listesi_kalemler kolonları"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_fiyat_listesi_kalemler';" 2>&1 | sed 's/^/  /'

hr "2. LASSA fiyat listesi örnek (ilk 5) — hangi kolon liste fiyatı"
$PSQL -c "SELECT * FROM bi_fiyat_listesi_kalemler WHERE marka ILIKE '%LASSA%' LIMIT 5;" 2>&1 | head -20 | sed 's/^/  /'

hr "3. Atomda bu ay satılan LASSA KIŞ (tesvik-2026) — en yüksek ciro 5 SKU"
$PSQL -c "
SELECT kalem_kodu, ebat, to_char(ay,'YYYY-MM') ay,
  round(birim_maliyet) bizim_maliyet, round(ort_fiyat) bizim_satis,
  round(marj_pct,1) brut_marj_pct, tesvik_kesin_pct AS fatura_alti_pct
FROM bi_marj_atom
WHERE tenant_id='$T'::uuid AND upper(marka)='LASSA' AND tesvik_kaynak='tesvik-2026'
  AND ay=(SELECT max(ay) FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)='LASSA' AND tesvik_kaynak='tesvik-2026')
ORDER BY ciro DESC LIMIT 5;" 2>&1 | sed 's/^/  /'

hr "BITTI — 2. bloktaki liste fiyatı + 3. bloktaki maliyet yan yana: maliyet ≈ liste mi (gross), liste×(1−fatura) mi (net)?"
