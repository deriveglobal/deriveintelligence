PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. RAKIP TABLOLARI + SATIR + SON TARAMA ############"
$PG -c "SELECT c.relname, COALESCE(s.n_live_tup,0) AS satir
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
  LEFT JOIN pg_stat_user_tables s ON s.relid=c.oid
 WHERE c.relkind='r' AND (c.relname LIKE 'bi_rakip%' OR c.relname LIKE 'bi_price%' OR c.relname LIKE 'bi_scrape%' OR c.relname='bi_urun_master' OR c.relname='bi_pazar_fiyat')
 ORDER BY satir DESC;"

echo "############ 2. ANA TABLO SEMALARI ############"
for t in bi_rakip_fiyat bi_rakip_fiyat_son bi_rakip_izle bi_rakip_fiyat_alarm bi_urun_master; do
  echo "--- $t:"
  $PG -t -c "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='$t';"
done

echo "############ 3. TARAMA TAZELIGI — bi_rakip_fiyat ne kadar guncel ############"
$PG -c "SELECT max(scraped_at)::date AS son_tarama, count(DISTINCT kaynak) AS pazaryeri, count(*) AS fiyat, count(DISTINCT scraped_at::date) AS kac_gun FROM bi_rakip_fiyat;"
$PG -c "SELECT scraped_at::date, count(*) FROM bi_rakip_fiyat GROUP BY 1 ORDER BY 1 DESC LIMIT 7;"
