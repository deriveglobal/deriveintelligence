#!/usr/bin/env bash
# DOĞAL ANAHTAR + LOG — gerçek dedup anahtarı + ingestion_log geçmişi. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. GERÇEK DOĞAL ANAHTAR — erp_ingest.py'deki dogal_anahtar tanımları (tablo başına)"
grep -nE "\"tablo\"|dogal_anahtar" erp_ingest.py | sed 's/^/  /'

hr "2. bi_ingestion_log — son 12 yükleme (süreklilik kontrolü için)"
$PSQL -c "SELECT query_type, export_date::text, row_count_raw, row_count_kept, status, processed_at::date
          FROM bi_ingestion_log WHERE tenant_id='$T'::uuid ORDER BY processed_at DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "3. bi_satis_faturalari GERÇEK mükerrer — birden fazla anahtar denemesi (hangisi 0?)"
echo "  --- (fatura_no, kalem_kodu, fatura_tarihi) ---"
$PSQL -c "SELECT COALESCE(sum(c-1),0) fazla FROM (SELECT fatura_no,kalem_kodu,fatura_tarihi,count(*) c FROM bi_satis_faturalari WHERE tenant_id='$T' GROUP BY 1,2,3 HAVING count(*)>1) x;" 2>&1 | sed 's/^/    /'
echo "  --- + birim_fiyat + miktar (satır ayrımı) ---"
$PSQL -c "SELECT COALESCE(sum(c-1),0) fazla FROM (SELECT fatura_no,kalem_kodu,fatura_tarihi,birim_fiyat,miktar,count(*) c FROM bi_satis_faturalari WHERE tenant_id='$T' GROUP BY 1,2,3,4,5 HAVING count(*)>1) x;" 2>&1 | sed 's/^/    /'
echo "  --- TÜM kolonlar (tam satır tekrarı = kesin mükerrer) ---"
$PSQL -c "SELECT COALESCE(sum(c-1),0) fazla FROM (SELECT fatura_no,kalem_kodu,fatura_tarihi,birim_fiyat,miktar,satir_tutar,odeme_kosulu,muhatap_kodu,count(*) c FROM bi_satis_faturalari WHERE tenant_id='$T' GROUP BY 1,2,3,4,5,6,7,8 HAVING count(*)>1) x;" 2>&1 | sed 's/^/    /'

hr "4. ÖRNEK — aynı (fatura_no,kalem,tarih) neden 2 satır (meşru mu mükerrer mi)"
$PSQL -c "WITH d AS (SELECT fatura_no,kalem_kodu,fatura_tarihi FROM bi_satis_faturalari WHERE tenant_id='$T' GROUP BY 1,2,3 HAVING count(*)>1 LIMIT 1)
          SELECT s.fatura_no,left(s.kalem_tanimi,20) kalem,s.miktar,s.birim_fiyat,s.satir_tutar,s.odeme_kosulu,s.muhatap_kodu
          FROM bi_satis_faturalari s JOIN d ON d.fatura_no=s.fatura_no AND d.kalem_kodu=s.kalem_kodu AND d.fatura_tarihi=s.fatura_tarihi
          WHERE s.tenant_id='$T';" 2>&1 | sed 's/^/  /'

hr "BITTI — gerçek anahtar + gerçek mükerrer + log geçmişi görülünce guard kurulur."
