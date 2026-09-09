#!/usr/bin/env bash
# DENETIM_126B — cekirdek tablo TAZELIGI (pozisyon verisi bayat mi?) + Python referanslari. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ⚠ CEKIRDEK TABLO TAZELIGI — export_date / son veri (pozisyon bayat mi?)"
for t in bi_musteri_risk bi_cari_bakiye bi_stok_anlik bi_on_siparis; do
  echo "  --- $t (export_date) ---"
  $PSQL -tAc "SELECT max(export_date), count(*) FROM $t" 2>&1 | sed 's/^/     /'
done
echo "  --- bi_satis_faturalari (fatura_tarihi + export_date) ---"
$PSQL -tAc "SELECT max(fatura_tarihi), max(export_date), count(*) FROM bi_satis_faturalari" 2>&1 | sed 's/^/     /'
echo "  --- bi_tedarikci_faturalari (fatura_tarihi + export_date) ---"
$PSQL -tAc "SELECT max(fatura_tarihi), max(export_date), count(*) FROM bi_tedarikci_faturalari" 2>&1 | sed 's/^/     /'
echo "  --- bi_stok_hareket (tarih kolonu ne?) ---"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_stok_hareket' AND (data_type LIKE '%date%' OR data_type LIKE '%timestamp%');" 2>&1 | sed 's/^/     /'
echo "  --- bi_marj_fact (kup — tarih/export kolonu?) ---"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_marj_fact' AND (column_name ILIKE '%tarih%' OR column_name ILIKE '%date%' OR column_name ILIKE '%export%' OR column_name ILIKE '%ay%');" 2>&1 | sed 's/^/     /'

hr "2. ⚠ ISIN OZU — net sermaye/DSO'nun uc bacagi AYNI GUNDEN mi?"
$PSQL -c "
SELECT 'stok  (bi_stok_anlik)'   AS bacak, max(export_date)::date AS export_gun FROM bi_stok_anlik
UNION ALL SELECT 'alacak (bi_musteri_risk)', max(export_date)::date FROM bi_musteri_risk
UNION ALL SELECT 'borc  (bi_cari_bakiye)',   max(export_date)::date FROM bi_cari_bakiye;"
echo "  ⚠ Uc gun FARKLIYSA: net sermaye melez fotograf. Ayni ise: tutarli."

hr "3. 'OLU' bayragi yanlis pozitif mi? — Python/scraper referanslari"
for t in bi_marj_fact bi_maliyet_ay bi_maliyet_sku bi_musteri_risk_odeme bi_stok_hareket; do
  n_py=$(grep -rl "\b$t\b" /opt/krb-assessment/*.py /opt/price_monitor/*.py 2>/dev/null | wc -l | tr -d ' ')
  n_erp=$(grep -c "\b$t\b" /opt/krb-assessment/erp_ingest.py 2>/dev/null || echo 0)
  echo "  $t: erp_ingest=$n_erp, python_dosya=$n_py"
done
echo "  ⚠ Python'da kuruluyorsa 'olu' degil — server grep goremiyordu."

hr "4. bi_ingestion_log query_type -> gercek tablo (isim uyusmazligi neden?)"
echo "  --- erp_ingest.py: her query_type hangi tabloyu hedefliyor ---"
grep -nE '"query_type"|"tablo"' erp_ingest.py 2>/dev/null | sed 's/^/  /'

hr "5. ⚠ COK KIRACILI RISK — cekirdek finansal tablolar tenant_id + RLS"
$PSQL -c "
SELECT c.relname,
       (SELECT data_type FROM information_schema.columns WHERE table_name=c.relname AND column_name='tenant_id') AS tenant_tipi,
       CASE WHEN c.relrowsecurity THEN 'RLS✓' ELSE '⚠ ACIK' END AS rls
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN
   ('bi_satis_faturalari','bi_musteri_risk','bi_cari_bakiye','bi_stok_anlik',
    'bi_tedarikci_faturalari','bi_marj_fact','bi_stok_hareket','master_musteri')
 ORDER BY c.relname;"
echo "  ⚠ ACIK olanlar + TEXT tenant_id: 2. kiracidan once duzeltilmeli."

hr "BITTI — pozisyon bayatsa DSO dahil tum pozisyon metrikleri once bunu cozmeli"
