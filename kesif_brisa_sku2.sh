#!/usr/bin/env bash
# Brisa alış faturası — LASSA 205/55R16 (kalem_kodu 214992 / 218052) gerçek birim maliyet. READ-ONLY.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. BRISA ALIŞ FATURALARI — LASSA 205/55R16 (kalem_kodu 214992* / 218052*)"
$PSQL -c "SELECT fatura_tarihi, kalem_kodu, left(kalem_tanimi,32) tanim, jant_capi,
   round(birim_fiyat_kdv_haric) brisa_birim_maliyet, miktar
  FROM bi_tedarikci_faturalari
  WHERE tenant_id::text='$T' AND marka ILIKE '%LASSA%'
    AND (kalem_kodu LIKE '214992%' OR kalem_kodu LIKE '218052%')
  ORDER BY fatura_tarihi DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "2. Aynı SKU atom maliyeti + retail liste referansı"
$PSQL -c "SELECT '214992/218052 (205/55R16)' sku, 6087 retail_liste, round(6087*0.65) yuzde35_off,
   (SELECT round(avg(birim_maliyet)) FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND kalem_kodu LIKE '218052%') atom_maliyet_218052,
   (SELECT round(avg(birim_maliyet)) FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND kalem_kodu LIKE '214992%') atom_maliyet_214992;" 2>&1 | sed 's/^/  /'

hr "BITTI — Brisa gerçek birim maliyet ≈ 3.957 (%35 off, gross) mi, ≈ 2.679 (daha derin) mi?"
