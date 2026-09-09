PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. TESVIK hesabi — 23040-23075 (tavan uygulaniyor mu) ############"
sed -n '23040,23075p' server_container.mjs

echo
echo "############ 2. Koddaki 4-bilesen toplami GERCEKTEN tavani asiyor mu ############"
$PG -c "SELECT marka, segment,
  COALESCE(donem_primi_pct,0)+COALESCE(sellout_primi_pct,0)+COALESCE(buyume_bonus_pct,0)+COALESCE(kanal_operasyon_pct,0) AS kod_toplam,
  max_toplam_pct,
  CASE WHEN COALESCE(donem_primi_pct,0)+COALESCE(sellout_primi_pct,0)+COALESCE(buyume_bonus_pct,0)+COALESCE(kanal_operasyon_pct,0) > COALESCE(max_toplam_pct,999) THEN 'ASIYOR' ELSE 'ok' END AS durum
  FROM bi_tedarikci_tesvik ORDER BY kod_toplam DESC LIMIT 20;"

echo "############ 3. incentives ucu (31308) — tavan uyguluyor mu ############"
sed -n '31305,31335p' server_container.mjs
