echo '=== A: VIEW SEMASI ==='
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c '\d v_finans_ticari_sermaye'
echo '=== A2: VIEW ORNEK SATIR (expanded) ==='
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -x -c 'SELECT * FROM v_finans_ticari_sermaye'
echo '=== B: SHELL SERVE DISPATCH (kokpit desenleri) ==='
docker exec krb-assessment sed -n '26958,27012p' /app/server.mjs
echo '=== C: KOKPIT-DATA STOK HEDEFLERI ==='
docker exec krb-assessment grep -n "toplam_deger\|kokpit-data\|/api/bi/kokpit" /app/server.mjs
