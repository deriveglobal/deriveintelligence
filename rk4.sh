PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'"

echo "############ 1. BRISA brifing kamyon sorgusu — BUGUN kac doner ############"
$PG -c "SELECT count(*) AS ilan, count(DISTINCT marka) AS marka, count(DISTINCT kaynak) AS pazaryeri
  FROM bi_rakip_fiyat
 WHERE lastik_mi AND segment IN ('KAMYON_OTOBUS','HAFIF_TICARI')
   AND scraped_at > now() - interval '30 days';"
echo "--- (segment bos oldugu icin 0 beklenir; devirdeki 292 rakami bu filtreye dayaniyordu)"

echo "############ 2. brand-compare koprü gorunumleri — maliyet donuyor mu ############"
echo "--- bi_stok_hareketleri gorunum kolonlari (birim_maliyet, giris_miktari var mi):"
$PG -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_stok_hareketleri' AND column_name IN ('birim_maliyet','giris_miktari','kalem_kodu','belge_tarihi');"
echo "--- gorunum satir doner mi (birim_maliyet dolu):"
$PG -c "SELECT count(*) AS satir, count(*) FILTER (WHERE birim_maliyet>0) AS maliyetli FROM bi_stok_hareketleri WHERE tenant_id=$T::uuid;" 2>&1 | head -5

echo "############ 3. IZLEME LISTESI — tek SKU ne, alarm neden 0 ############"
$PG -c "SELECT marka, ebat, aktif, alarm_esigi, son_min_fiyat FROM bi_rakip_izle;"
