#!/usr/bin/env bash
# Salt okuma. TEKLIF ONAY modulunu yamalamadan once TAM olarak gormem lazim.
S=/opt/krb-assessment/server_container.mjs
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) saha_teklif + kalem SEMASI ############"
$PSQL -c "\d saha_teklif"
$PSQL -c "\d saha_teklif_kalem"

echo
echo "############ 2) MEVCUT TEKLIFLER — ne var? ############"
$PSQL -c "
SELECT durum, count(*) AS adet, max(olusturma_tarihi)::date AS son
  FROM saha_teklif GROUP BY 1 ORDER BY 2 DESC;" 2>/dev/null \
 || $PSQL -c "SELECT * FROM saha_teklif ORDER BY 1 DESC LIMIT 2;"

echo
echo "############ 3) ONAY EKRANI endpoint'leri ############"
grep -n "teklif" $S | grep -i "api/\|pathname" | head -20

echo
echo "############ 4) ONAY ekranini besleyen sorgu (stok+rakip paneli) ############"
grep -n "onay\|approve\|bekleyen" $S | grep -i "teklif" | head -10

echo
echo "############ 5) BI kabugunda teklif onay ekrani ############"
grep -n "teklif\|Teklif" /opt/krb-assessment/shells/bi.js | head -15

echo
echo "############ 6) ⚠ YENI VERI HAZIR MI? — teklif icin gereken 5 sey ############"
echo "  (1) satis vadesi:"
$PSQL -c "
SELECT count(*) AS satir_2026,
       count(*) FILTER (WHERE vade_tarihi IS NOT NULL) AS vadesi_olan
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01';"

echo "  (2)(4) min/max/medyan + MUSTERI — ornek: en cok satilan ebat"
$PSQL -c "
WITH e AS (
  SELECT ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01'
     AND grup_adi LIKE 'LASTIK%' AND ebat IS NOT NULL AND ebat<>''
   GROUP BY 1 ORDER BY sum(miktar) DESC LIMIT 1)
SELECT s.ebat, s.marka,
       count(*) AS satis_adedi,
       round(min(s.birim_fiyat))  AS min_fiyat,
       round(max(s.birim_fiyat))  AS max_fiyat,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY s.birim_fiyat)::numeric) AS medyan,
       (array_agg(s.musteri_adi ORDER BY s.birim_fiyat ASC))[1]  AS en_ucuz_ALAN,
       (array_agg(s.musteri_adi ORDER BY s.birim_fiyat DESC))[1] AS en_pahali_ALAN
  FROM bi_satis_faturalari s JOIN e ON e.ebat = s.ebat
 WHERE s.tenant_id='$TEN' AND s.fatura_tarihi >= DATE '2026-01-01'
   AND s.birim_fiyat > 0
 GROUP BY 1,2 ORDER BY 3 DESC LIMIT 5;"

echo "  (3) AGIRLIKLI ORTALAMA alis + satis vadesi (ayni ebat):"
$PSQL -c "
WITH e AS (
  SELECT ebat FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01'
     AND grup_adi LIKE 'LASTIK%' AND ebat IS NOT NULL AND ebat<>''
   GROUP BY 1 ORDER BY sum(miktar) DESC LIMIT 1),
sat AS (
  SELECT s.kalem_kodu, s.marka,
         round(sum(s.miktar*(s.vade_tarihi - s.fatura_tarihi))/NULLIF(sum(s.miktar),0)) AS ag_satis_vadesi,
         round(sum(s.miktar*s.birim_fiyat)/NULLIF(sum(s.miktar),0)) AS ag_satis_fiyati
    FROM bi_satis_faturalari s JOIN e ON e.ebat=s.ebat
   WHERE s.tenant_id='$TEN' AND s.fatura_tarihi >= DATE '2026-01-01' AND s.vade_tarihi IS NOT NULL
   GROUP BY 1,2),
al AS (
  SELECT t.kalem_kodu,
         round(sum(t.miktar*t.vade_gun)/NULLIF(sum(t.miktar),0)) AS ag_alis_vadesi,
         round(sum(t.miktar*t.birim_fiyat_kdv_haric)/NULLIF(sum(t.miktar),0)) AS ag_alis_fiyati
    FROM bi_tedarikci_faturalari t
   WHERE t.tenant_id='$TEN'::uuid AND t.fatura_tarihi >= DATE '2026-01-01' AND t.vade_gun IS NOT NULL
   GROUP BY 1)
SELECT sat.marka, sat.kalem_kodu,
       al.ag_alis_fiyati, al.ag_alis_vadesi AS alis_vade_gun,
       sat.ag_satis_fiyati, sat.ag_satis_vadesi AS satis_vade_gun,
       round((sat.ag_satis_fiyati - al.ag_alis_fiyati)/NULLIF(sat.ag_satis_fiyati,0)*100,1) AS marj_pct
  FROM sat LEFT JOIN al ON al.kalem_kodu = sat.kalem_kodu
 ORDER BY sat.ag_satis_fiyati DESC LIMIT 6;"
echo "  ^ HEPSI HESAPLANABILIYOR MU? Teklif ekrani bunlari gosterecek."
