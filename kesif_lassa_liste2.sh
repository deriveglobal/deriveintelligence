#!/usr/bin/env bash
# LASSA liste fiyatı (upload join) — bizim maliyet/satış ile yan yana. READ-ONLY.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. fiyat listesi upload tablosu (marka burada) — LASSA yüklemeleri"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_fiyat_listesi_uploads';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT id, marka, tarih FROM bi_fiyat_listesi_uploads WHERE marka ILIKE '%LASSA%' ORDER BY tarih DESC NULLS LAST LIMIT 6;" 2>&1 | sed 's/^/  /'

hr "1. LASSA liste fiyatları — bu 4 ebat (ebat·desen·liste·bayi·net·perakende)"
$PSQL -c "
SELECT k.ebat, k.desen, k.hiz_yuk,
  round(k.liste_fiyati) liste, round(k.bayi_fiyati) bayi, round(k.net_fiyati) net, round(k.perakende_fiyati) perakende, k.para_birimi
FROM bi_fiyat_listesi_kalemler k
JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
WHERE u.marka ILIKE '%LASSA%' AND k.ebat IN ('185/65R15','205/55R16','225/45R17','235/65R16C')
ORDER BY k.ebat, k.desen;" 2>&1 | sed 's/^/  /'

hr "2. HATIRLATMA — bizim (atom) maliyet/satış (aynı 4 ebat)"
$PSQL -c "
SELECT ebat, round(birim_maliyet) bizim_maliyet, round(ort_fiyat) bizim_satis, round(marj_pct,1) brut_marj, tesvik_kesin_pct fatura_alti
FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)='LASSA' AND tesvik_kaynak='tesvik-2026'
  AND ebat IN ('185/65R15','205/55R16','225/45R17','235/65R16C')
  AND ay=(SELECT max(ay) FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)='LASSA' AND tesvik_kaynak='tesvik-2026')
ORDER BY ebat;" 2>&1 | sed 's/^/  /'

hr "BITTI — bayi/net fiyat ile bizim maliyet: maliyet≈bayi (gross) mi, bayi×(1−0,35) (net) mi?"
