PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. FIYAT/TESVIK TABLOLARI + SATIR ############"
$PG -c "SELECT c.relname, COALESCE(s.n_live_tup,0) AS satir
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
  LEFT JOIN pg_stat_user_tables s ON s.relid=c.oid
 WHERE c.relkind='r' AND (c.relname LIKE 'bi_fiyat%' OR c.relname LIKE 'bi_tedarikci_tesvik%' OR c.relname LIKE 'bi_tedarikci_kampanya%' OR c.relname LIKE '%iskonto%')
 ORDER BY satir DESC;"

echo "############ 2. SEMALAR ############"
for t in bi_fiyat_listesi_kalemler bi_fiyat_listesi_uploads bi_fiyat_iskonto bi_tedarikci_tesvik bi_tedarikci_kampanya; do
  echo "--- $t:"
  $PG -t -c "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='$t';"
done

echo "############ 3. price-list UCLARI — method+path+satir ############"
grep -nE "url\.pathname === '/api/price-list/[^']+'|url\.pathname === '/api/fiyat" server_container.mjs

echo "############ 4. TAZELIK — fiyat listesi ve tesvik ne kadar guncel ############"
$PG -c "SELECT 'fiyat_kalem' t, max(created_at)::date FROM bi_fiyat_listesi_kalemler
        UNION ALL SELECT 'tesvik', max(created_at)::date FROM bi_tedarikci_tesvik
        UNION ALL SELECT 'iskonto', max(created_at)::date FROM bi_fiyat_iskonto;" 2>&1 | head
