#!/usr/bin/env bash
# metrik_ciro'nun lastik tanımı — drill'i buna hizalamak için. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. metrik_ciro fonksiyon gövdesi (lastik filtresi nasıl)"
$PSQL -c "SELECT pg_get_functiondef('metrik_ciro'::regproc);" 2>&1 | sed 's/^/  /'

hr "2. FARK — omurga(95,5) vs ebat-not-null(93,5): hangi satırlar ebatsız ama lastik"
$PSQL -c "
SELECT COALESCE(kategori,'(bos)') kategori, COALESCE(grup_adi,'(bos)') grup, count(*) satir,
       round(sum(satir_tutar)/1e6,2) ciro_m
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND upper(marka)='LASSA' AND ebat IS NULL
   AND fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - interval '6 month') AND fatura_tarihi < date_trunc('month',CURRENT_DATE)
 GROUP BY 1,2 ORDER BY ciro_m DESC NULLS LAST LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "BITTI — metrik_ciro filtresini görünce drill'i birebir aynı filtreye çekerim."
