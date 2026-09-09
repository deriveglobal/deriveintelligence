#!/usr/bin/env bash
# MÜKERRER + SÜREKLİLİK KEŞİF — ingest-log, dedup anahtarı, mevcut mükerrer, tarih geçmişi. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. INGEST-LOG — erp_ingest.py hangi tabloya yazıyor (export_date/tarih tutuyor mu)"
grep -nE "INSERT INTO .*log|ingest_log|yukleme_log|processed_at|received_at|export_date" erp_ingest.py | head -12 | sed 's/^/  /'
echo "  --- log INSERT bağlamı (satır ~680-695) ---"
sed -n '680,696p' erp_ingest.py | sed 's/^/  /'

hr "2. DEDUP ANAHTARI — erp_ingest.py GROUP BY (mükerrer nasıl tanımlanıyor)"
sed -n '668,680p' erp_ingest.py | sed 's/^/  /'

hr "3. DB'de INGEST-LOG benzeri tablo var mı + son kayıtları"
$PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ~* 'ingest|yukleme|yukle_log|erp_log|log') ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "4. MEVCUT MÜKERRER — bi_satis_faturalari doğal anahtar (fatura_no+kalem+tarih) tekrar var mı"
$PSQL -c "SELECT count(*) mukerrer_grup, COALESCE(sum(c-1),0) fazla_satir FROM (
  SELECT fatura_no, kalem_kodu, fatura_tarihi, count(*) c
  FROM bi_satis_faturalari WHERE tenant_id='$T' GROUP BY 1,2,3 HAVING count(*)>1) x;" 2>&1 | sed 's/^/  /'

hr "5. TARİH SÜREKLİLİĞİ — her flow tablosunun min/max tarihi (regresyon/boşluk için baz)"
$PSQL -c "SELECT 'satis' t, min(fatura_tarihi)::text, max(fatura_tarihi)::text FROM bi_satis_faturalari WHERE tenant_id='$T'
          UNION ALL SELECT 'tedarik', min(fatura_tarihi)::text, max(fatura_tarihi)::text FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid
          UNION ALL SELECT 'stok_hrk', min(belge_tarihi)::text, max(belge_tarihi)::text FROM bi_stok_hareket WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "BITTI — mükerrer + süreklilik guard'ı gerçek yapıya göre tasarlanır."
