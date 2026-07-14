PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
echo "=== A. bi_sayi_koken YAPISI ==="
$PG -c "\d bi_sayi_koken"
echo "=== B. bi_sayi_koken ICERIGI ==="
$PG -x -c "SELECT * FROM bi_sayi_koken ORDER BY 1;"
echo "=== C. kpi_definitions ==="
$PG -x -c "SELECT * FROM kpi_definitions LIMIT 20;"
echo "=== D. 24070-24096 (koken blogu) ==="
sed -n '24070,24096p' server_container.mjs
echo "=== E. 23895-23935 (TEK_GERCEK sorgusu) ==="
sed -n '23895,23935p' server_container.mjs
echo "=== F. 25640-25660 (SAP satiri baglami) ==="
sed -n '25640,25660p' server_container.mjs
echo "=== G. 24460-24472 (38.604) ==="
sed -n '24460,24472p' server_container.mjs
echo "=== H. 25415-25430 (DSO araligi) ==="
sed -n '25415,25430p' server_container.mjs
echo "=== I. 25465-25472 (DPO/DSO araligi) ==="
sed -n '25465,25472p' server_container.mjs
