PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -t"

echo "############ KUCUK TABLOLAR + GORUNUMLER ############"
$PG -c "SELECT c.relname || E'\t' || CASE c.relkind WHEN 'v' THEN 'GORUNUM' ELSE 'tablo' END || E'\t' || COALESCE(s.n_live_tup,0) || ' satir'
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
  LEFT JOIN pg_stat_user_tables s ON s.relid=c.oid
 WHERE c.relkind IN ('r','v') AND COALESCE(s.n_live_tup,0) < 25
 ORDER BY c.relkind, c.relname;"

echo
echo "############ OLU TABLOLAR: kodda HIC anilmayan ############"
for t in $($PG -c "SELECT relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public' WHERE c.relkind='r' ORDER BY 1;" | tr -d ' '); do
  [ -z "$t" ] && continue
  n=$(grep -c "$t" server_container.mjs erp_ingest.py 2>/dev/null | awk -F: '{s+=$2} END{print s}')
  [ "$n" = "0" ] && echo "  OLU: $t"
done

echo
echo "############ HAYALET: kodun andigi ama OLMAYAN tablolar ############"
grep -ohE "FROM (bi_|saha_|master_|brain_|ops_)[a-z_]+|JOIN (bi_|saha_|master_|brain_|ops_)[a-z_]+" server_container.mjs \
  | awk '{print $2}' | sort -u > /tmp/kod_tablolari.txt
$PG -c "SELECT relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public' WHERE c.relkind IN ('r','v');" | tr -d ' ' | sort -u > /tmp/db_tablolari.txt
comm -23 /tmp/kod_tablolari.txt /tmp/db_tablolari.txt | sed 's/^/  HAYALET: /'
