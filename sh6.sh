PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. DURUM ENUM — gercekte hangi degerler var (RISKLI_NOKTA var mi) ############"
$PG -c "SELECT durum, count(*) FROM saha_musteri GROUP BY durum ORDER BY 2 DESC;"

echo "############ 2. TEKLIF sekmesi — win/loss anlamli mi (kac kayit) ############"
$PG -c "SELECT durum, count(*), round(sum(toplam_tutar)/1e6,2) AS tutar_m FROM saha_teklif GROUP BY durum;"

echo "############ 3. ONERILER (14 rozet) — saha_oneri mantigi ############"
grep -n 'path === "/api/saha/oneriler"\|path === "/api/saha/oneri"' server_container.mjs | head
$PG -c "SELECT durum, count(*) FROM saha_oneri GROUP BY durum;" 2>/dev/null
$PG -c "SELECT column_name FROM information_schema.columns WHERE table_name='saha_oneri' ORDER BY ordinal_position;"

echo "############ 4. RAPOR/RAKIP tedarikci-fallback — detay'da rakipler dolu mu ############"
$PG -c "SELECT count(*) FILTER (WHERE detay ? 'rakipler') AS rakipler_dolu, count(*) FILTER (WHERE detay ? 'tedarikci_markalar') AS tedarikci_dolu, count(*) AS toplam FROM saha_ziyaret WHERE durum='TAMAMLANDI';"

echo "############ 5. MESAJLAR / DUYURULAR — hacim ############"
$PG -c "SELECT 'konusma' t,count(*) FROM saha_konusma UNION ALL SELECT 'konusma_mesaj',count(*) FROM saha_konusma_mesaj UNION ALL SELECT 'duyuru',count(*) FROM saha_duyuru UNION ALL SELECT 'rep_not',count(*) FROM saha_rep_not;"
