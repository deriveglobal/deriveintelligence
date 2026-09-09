PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1. ESLESME SAGLIGI — bi_urun_master KRB'ye baglaniyor mu ############"
$PG -c "SELECT
  count(*) AS toplam_sku,
  count(*) FILTER (WHERE krb_kalem_kodu IS NOT NULL) AS krb_eslesen,
  count(*) FILTER (WHERE krb_liste_fiyati IS NOT NULL) AS krb_fiyatli,
  count(*) FILTER (WHERE min_fiyat IS NOT NULL) AS piyasa_fiyatli,
  count(*) FILTER (WHERE durum='AKTIF') AS aktif
  FROM bi_urun_master;"

echo "############ 2. PARA BIRIMI — karisma var mi (TRY/EUR/USD) ############"
$PG -c "SELECT para_birimi, count(*), round(min(fiyat)) AS min, round(max(fiyat)) AS max FROM bi_rakip_fiyat GROUP BY 1 ORDER BY 2 DESC;"

echo "############ 3. SEGMENT dagilimi (binek vs kamyon — prompt sabiti) ############"
$PG -c "SELECT segment, count(*) FROM bi_rakip_fiyat WHERE scraped_at::date = (SELECT max(scraped_at)::date FROM bi_rakip_fiyat) GROUP BY 1 ORDER BY 2 DESC;"

echo "############ 4. bi_rakip_fiyat_son GORUNUM MU, nasil 'son' seciyor ############"
$PG -c "SELECT pg_get_viewdef('bi_rakip_fiyat_son', true);" 2>/dev/null | head -25

echo "############ 5. PIYASA KARSILASTIRMA UCU — hangi satir ############"
grep -n 'path === "/api/rakip/urun-master"\|path === "/api/rakip/piyasa"\|/api/bi/brand-compare' server_container.mjs | head
