PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ RAPOR UCLARI — 5 alt rapor, ne hesapliyor ############"
for p in "rapor/ozet" "rapor/rep-performans" "rapor/bolge-marka" "rapor/rakip" "rapor/teklif"; do
  L=$(grep -n "path === \"/api/saha/$p\"" server_container.mjs | head -1 | cut -d: -f1)
  echo "───── /api/saha/$p  (satir $L) ─────"
  [ -n "$L" ] && sed -n "$((L)),$((L+22))p" server_container.mjs
  echo
done
