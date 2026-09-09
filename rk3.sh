PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. SEGMENT zaman icinde — hep mi bos, ne zaman durdu ############"
$PG -c "SELECT scraped_at::date,
  count(*) FILTER (WHERE segment IS NULL OR segment='') AS bos,
  count(*) FILTER (WHERE segment IS NOT NULL AND segment<>'') AS dolu
  FROM bi_rakip_fiyat GROUP BY 1 ORDER BY 1 DESC LIMIT 8;"

echo "############ 2. SEGMENT'i kim yaziyor — kodda nerede set ediliyor ############"
grep -n "segment" server_container.mjs | grep -iE "UPDATE|INSERT|SET segment|segment =|segment IN|CASE" | head -12

echo "############ 3. brand-compare — 682 eslesene mi bagli, mantik ne ############"
sed -n '21048,21110p' server_container.mjs
