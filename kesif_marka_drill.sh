#!/usr/bin/env bash
# Marka drill: _finansTrendCiz UI + ciro/adet/marj aylık sorgu fizibilitesi (1 marka örnek). OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. _finansTrendCiz TAM (marka tablosu nasıl render + satır yapısı)"
sed -n '649,724p' shells/bi.js

hr "2. marka kolonu + lastik filtresi — bi_satis_faturalari (marka nasıl duruyor)"
$PSQL -c "SELECT marka, count(*) satir, round(sum(satir_tutar)/1e6,1) ciro_m FROM bi_satis_faturalari WHERE tenant_id='$T' AND ebat IS NOT NULL AND fatura_tarihi>='2026-01-01' GROUP BY marka ORDER BY ciro_m DESC NULLS LAST LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "3. DRILL SORGU testi — BRIDGESTONE aylık ciro + adet + marj (maliyet join + kapsam)"
$PSQL -c "
WITH km AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) AS bmaliyet FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu)
SELECT to_char(date_trunc('month',s.fatura_tarihi),'YYYY-MM') ay,
       round(sum(s.satir_tutar)/1e6,2) ciro_m,
       sum(s.miktar)::int adet,
       round(sum(CASE WHEN km.bmaliyet IS NOT NULL THEN s.satir_tutar - s.miktar*km.bmaliyet END)/1e6,2) marj_m,
       round(100.0*count(*) FILTER (WHERE km.bmaliyet IS NOT NULL)/count(*)) marj_kapsam_pct
  FROM bi_satis_faturalari s LEFT JOIN km ON km.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$T' AND s.ebat IS NOT NULL AND upper(s.marka)='BRIDGESTONE' AND s.fatura_tarihi>='2025-07-01'
 GROUP BY 1 ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "BITTI — ciro/adet kesin mi, marj kapsamı ne kadar (kırılım buna göre kurulur)"
