#!/usr/bin/env bash
# DENETIM_126 — VERI KAYNAGI HARITASI. SADECE OKUR.
#   Her tablo: canli/olu · kaynak · tazelik · tenant tipi · RLS · kanonik mi.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
SRC="server_container.mjs"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ERP INGEST HARITASI — hangi ERP dosyasi hangi tabloyu besliyor?"
echo "--- bi_ingestion_log: query_type -> son yukleme + satir ---"
$PSQL -c "
SELECT query_type,
       max(processed_at)::date AS son_yukleme,
       count(*) AS yukleme_sayisi,
       max(row_count_kept) AS son_satir
  FROM bi_ingestion_log GROUP BY 1 ORDER BY 2 DESC NULLS LAST;"
echo "--- erp_ingest.py: query_type -> HEDEF TABLO eslesmesi (koddan) ---"
grep -nE "query_type|INSERT INTO bi_|DELETE FROM bi_|hedef|target.*table|TABLE_MAP|tablo" erp_ingest.py 2>/dev/null | grep -iE "bi_|query_type|=" | head -30 | sed 's/^/  /'

hr "2. TAM ENVANTER — tum tablolar/view'ler siniflandirilmis"
$PSQL -c "
SELECT
  c.relname AS tablo,
  CASE c.relkind WHEN 'r' THEN 'tablo' WHEN 'v' THEN 'VIEW' WHEN 'm' THEN 'MATVIEW' WHEN 'p' THEN 'partition' END AS tip,
  to_char(COALESCE(s.n_live_tup,0),'FM999,999,999') AS satir,
  (SELECT data_type FROM information_schema.columns WHERE table_name=c.relname AND column_name='tenant_id') AS tenant_tipi,
  CASE WHEN c.relrowsecurity THEN 'RLS✓' ELSE 'acik' END AS rls,
  CASE
    WHEN c.relname ~ 'yedek|_bak|_old|olu_yedek|backup' THEN 'YEDEK'
    WHEN c.relname ~ '^(questions|responses|findings|recommendations|evidence|problem_types|maturity|pain_point|process_inventory|roadmap|stakeholder|assessment|response_analysis|opportunity|root_cause|framework|glossary|kpi_catalog|scoring|domain_tax|generated_report)' THEN 'ESKI_PLATFORM'
    WHEN c.relkind IN ('v','m') THEN 'GORUNUM'
    WHEN c.relname ~ '^bi_' THEN 'KRB_BI'
    WHEN c.relname ~ '^saha_' THEN 'KRB_SAHA'
    WHEN c.relname ~ '^master_' THEN 'KRB_MASTER'
    WHEN c.relname ~ '^brain_' THEN 'KRB_BRAIN'
    ELSE 'DIGER'
  END AS kategori
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace
  LEFT JOIN pg_stat_user_tables s ON s.relid=c.oid
 WHERE n.nspname='public' AND c.relkind IN ('r','v','m','p')
 ORDER BY kategori, COALESCE(s.n_live_tup,0) DESC;"

hr "3. CANLI mi OLU mu — her tablo kodda referansli mi? (0 = olu)"
echo "  (server_container.mjs icinde tablo adi araniyor; 0 ise kod okumuyor)"
TABLOLAR=$($PSQL -tAc "SELECT relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' ORDER BY relname")
printf "  %-42s %6s %s\n" "TABLO" "REF" "DURUM"
for t in $TABLOLAR; do
  # yedek/eski platform tablolarini isaretle ama yine de say
  n=$(grep -c "\b$t\b" "$SRC" 2>/dev/null || echo 0)
  if [ "$n" = "0" ]; then durum="⚠ OLU (kod okumuyor)"; else durum=""; fi
  # sadece olu olanlari ve krb tablolarini goster (gurultuyu azalt)
  if [ "$n" = "0" ] || echo "$t" | grep -qE '^(bi_|saha_|master_|brain_)'; then
    printf "  %-42s %6s %s\n" "$t" "$n" "$durum"
  fi
done

hr "4. CEKIRDEK METRIK TABLOLARI — tazelik (metrik tanimi bunlara dayanacak)"
$PSQL -c "
SELECT 'bi_satis_faturalari' t, max(fatura_tarihi)::date son_veri, max(export_date)::date son_export, count(*) satir FROM bi_satis_faturalari
UNION ALL SELECT 'bi_musteri_risk', NULL, max(export_date)::date, count(*) FROM bi_musteri_risk
UNION ALL SELECT 'bi_cari_bakiye', NULL, max(export_date)::date, count(*) FROM bi_cari_bakiye
UNION ALL SELECT 'bi_stok_anlik', NULL, max(export_date)::date, count(*) FROM bi_stok_anlik
UNION ALL SELECT 'bi_tedarikci_faturalari', max(fatura_tarihi)::date, max(export_date)::date, count(*) FROM bi_tedarikci_faturalari
UNION ALL SELECT 'bi_stok_hareket', max(hareket_tarihi)::date, NULL, count(*) FROM bi_stok_hareket
UNION ALL SELECT 'bi_fatura_tahsilat', max(fatura_tarihi)::date, NULL, count(*) FROM bi_fatura_tahsilat
ORDER BY 1;" 2>&1 | sed 's/^/  /'
echo "  ⚠ export_date FARKLI gunlerdeyse: pozisyon metrikleri melez (tarih karismasi #116)."

hr "5. OZET — kategori bazinda tablo/satir + olu sayisi"
$PSQL -c "
SELECT
  CASE
    WHEN relname ~ 'yedek|_bak|_old|olu_yedek|backup' THEN 'YEDEK'
    WHEN relname ~ '^(questions|responses|findings|recommendations|evidence|problem_types|maturity|pain_point|process_inventory|roadmap|stakeholder|assessment|response_analysis|opportunity|root_cause|framework|glossary|kpi_catalog|scoring|domain_tax|generated_report)' THEN 'ESKI_PLATFORM'
    WHEN relkind IN ('v','m') THEN 'GORUNUM'
    WHEN relname ~ '^bi_' THEN 'KRB_BI'
    WHEN relname ~ '^saha_' THEN 'KRB_SAHA'
    WHEN relname ~ '^master_' THEN 'KRB_MASTER'
    WHEN relname ~ '^brain_' THEN 'KRB_BRAIN'
    ELSE 'DIGER'
  END AS kategori,
  count(*) AS tablo_sayisi
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind IN ('r','v','m','p')
 GROUP BY 1 ORDER BY 2 DESC;"

hr "BITTI — bu harita: hangi tablo kanonik, hangisi olu/yedek/eski platform"
