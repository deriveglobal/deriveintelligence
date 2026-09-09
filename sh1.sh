PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. SAHA TABLOLARI + SATIR SAYISI ############"
$PG -t -c "SELECT c.relname || E'\t' || COALESCE(s.n_live_tup,0) || ' satir'
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
  LEFT JOIN pg_stat_user_tables s ON s.relid=c.oid
 WHERE c.relkind='r' AND c.relname LIKE 'saha_%' ORDER BY COALESCE(s.n_live_tup,0) DESC;"

echo
echo "############ 2. ANA SAHA TABLOLARININ SEMASI ############"
for t in saha_musteri saha_ziyaret saha_teklif saha_iskonto_talep saha_denetim; do
  echo "--- $t:"
  $PG -t -c "SELECT string_agg(column_name || ':' || data_type, ', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='$t';"
  echo
done

echo "############ 3. SAHA UCLARI ############"
sed -n '28001,32356p' server_container.mjs | grep -oE '(GET|POST|PUT|DELETE|PATCH).{0,6}url\.pathname[^)]{0,60}' | head -70
