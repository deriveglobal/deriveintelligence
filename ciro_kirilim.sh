#!/usr/bin/env bash
# Salt okuma. 2026 cirosu 371,9M cikiyor; Fatih Bilen 121,79M diyor.
# Veri artik TEMIZ (0 gelecek tarih, 0 ters vade). Yani bu bir VERI hatasi degil,
# bir TANIM farki. Hangi dilim 121,79M'e denk geliyor? Bulalim.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
W="tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01'"

echo "############ TOPLAM ############"
$PSQL -c "SELECT count(*) AS satir, round(sum(satir_tutar)/1e6,2) AS ciro_MTL FROM bi_satis_faturalari WHERE $W;"

echo "############ ŞUBE ############"
$PSQL -c "SELECT COALESCE(sube,'(bos)') AS sube, count(*) AS satir,
                 round(sum(satir_tutar)/1e6,2) AS ciro_MTL
            FROM bi_satis_faturalari WHERE $W GROUP BY 1 ORDER BY 3 DESC;"

echo "############ DEPO ############"
$PSQL -c "SELECT COALESCE(depo_adi,'(bos)') AS depo, count(*) AS satir,
                 round(sum(satir_tutar)/1e6,2) AS ciro_MTL
            FROM bi_satis_faturalari WHERE $W GROUP BY 1 ORDER BY 3 DESC LIMIT 12;"

echo "############ SATIŞ KANALI ############"
$PSQL -c "SELECT COALESCE(satis_kanali,'(bos)') AS kanal, count(*) AS satir,
                 round(sum(satir_tutar)/1e6,2) AS ciro_MTL
            FROM bi_satis_faturalari WHERE $W GROUP BY 1 ORDER BY 3 DESC;"

echo "############ ÜRÜN GRUBU (lastik / diger) ############"
$PSQL -c "SELECT COALESCE(grup_adi,'(bos)') AS grup, count(*) AS satir,
                 round(sum(satir_tutar)/1e6,2) AS ciro_MTL
            FROM bi_satis_faturalari WHERE $W GROUP BY 1 ORDER BY 3 DESC LIMIT 12;"

echo "############ İADE / NEGATİF SATIR ############"
$PSQL -c "SELECT sign(satir_tutar) AS isaret, count(*) AS satir,
                 round(sum(satir_tutar)/1e6,2) AS ciro_MTL
            FROM bi_satis_faturalari WHERE $W GROUP BY 1 ORDER BY 1;"

echo "############ 121,79M'e YAKIN OLAN DİLİMLER ############"
echo "  (100-145M arasindaki her kirilim -- Fatih Bilen'in kastettigi bu olabilir)"
$PSQL -c "
WITH k AS (
  SELECT 'SUBE: '||COALESCE(sube,'-')  AS dilim, sum(satir_tutar) AS t FROM bi_satis_faturalari WHERE $W GROUP BY 1
  UNION ALL
  SELECT 'DEPO: '||COALESCE(depo_adi,'-'), sum(satir_tutar) FROM bi_satis_faturalari WHERE $W GROUP BY 1
  UNION ALL
  SELECT 'KANAL: '||COALESCE(satis_kanali,'-'), sum(satir_tutar) FROM bi_satis_faturalari WHERE $W GROUP BY 1
  UNION ALL
  SELECT 'GRUP: '||COALESCE(grup_adi,'-'), sum(satir_tutar) FROM bi_satis_faturalari WHERE $W GROUP BY 1
  UNION ALL
  SELECT 'TEMSILCI: '||COALESCE(satis_temsilcisi,'-'), sum(satir_tutar) FROM bi_satis_faturalari WHERE $W GROUP BY 1
)
SELECT dilim, round(t/1e6,2) AS ciro_MTL
  FROM k WHERE t BETWEEN 100e6 AND 145e6
 ORDER BY abs(t - 121.79e6) ASC;"
echo "  ^ En ustteki 121,79M'e EN YAKIN olan. Fatih Bilen'e sorulacak: bu mu?"
