echo "############ SAHA UCLARI ############"
sed -n '28001,32356p' server_container.mjs | grep -oE '["'"'"']/api/saha/[^"'"'"']*' | tr -d '"'"'"'' | sort -u
echo "--- sayi:"
sed -n '28001,32356p' server_container.mjs | grep -oE '["'"'"']/api/saha/[^"'"'"']*' | sort -u | wc -l

echo
echo "############ TABLO SAYIMI ############"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -t <<'SQL'
SELECT c.relname || E'\t' || CASE c.relkind WHEN 'v' THEN 'GORUNUM' ELSE 'tablo' END
       || E'\t' || COALESCE(s.n_live_tup::text,'?') || ' satir'
  FROM pg_class c
  JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public'
  LEFT JOIN pg_stat_user_tables s ON s.relid=c.oid
 WHERE c.relkind IN ('r','v')
 ORDER BY c.relkind, COALESCE(s.n_live_tup,0) DESC;
SQL
