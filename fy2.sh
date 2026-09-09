PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. TAZELIK (dogru kolonlar) ############"
$PG -c "SELECT marka, liste_tarihi, kayit_sayisi, aktif FROM bi_fiyat_listesi_uploads WHERE aktif ORDER BY liste_tarihi DESC LIMIT 10;"

echo "############ 2. PARA BIRIMI KARISMASI — fiyat listesi EUR/USD/TRY ############"
$PG -c "SELECT para_birimi, count(*) FROM bi_fiyat_listesi_kalemler GROUP BY 1;"

echo "############ 3. TESVIK TAVANI — bilesenler toplami max_toplam_pct'i asiyor mu ############"
$PG -c "SELECT marka, segment,
  COALESCE(fatura_alti_pct,0)+COALESCE(donem_primi_pct,0)+COALESCE(sellout_primi_pct,0)+COALESCE(kanal_operasyon_pct,0)+COALESCE(kesin_siparis_pct,0)+COALESCE(buyume_bonus_pct,0) AS bilesen_toplam,
  max_toplam_pct
  FROM bi_tedarikci_tesvik
  WHERE COALESCE(fatura_alti_pct,0)+COALESCE(donem_primi_pct,0)+COALESCE(sellout_primi_pct,0)+COALESCE(kanal_operasyon_pct,0)+COALESCE(kesin_siparis_pct,0)+COALESCE(buyume_bonus_pct,0) > COALESCE(max_toplam_pct,999)
  LIMIT 20;"
echo "--- kac tesvikte bilesen toplami tavani asiyor:"
$PG -c "SELECT count(*) FILTER (WHERE bt > mx) AS asan, count(*) AS toplam FROM (SELECT COALESCE(fatura_alti_pct,0)+COALESCE(donem_primi_pct,0)+COALESCE(sellout_primi_pct,0)+COALESCE(kanal_operasyon_pct,0)+COALESCE(kesin_siparis_pct,0)+COALESCE(buyume_bonus_pct,0) AS bt, COALESCE(max_toplam_pct,999) AS mx FROM bi_tedarikci_tesvik) x;"

echo "############ 4. TESVIK hesaplayan kod — max_toplam_pct'e uyuyor mu ############"
grep -n "max_toplam_pct\|donem_primi_pct\|ciro_pct\|tesvik_pct" server_container.mjs | head -12
