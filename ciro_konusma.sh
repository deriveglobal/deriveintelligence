#!/usr/bin/env bash
# Salt okuma. Fatih Bilen ciro hakkinda TAM OLARAK ne dedi?
# Tahmin etmeyi birakip kaydi okuyalim.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) '121' ya da '121,79' gecen HER mesaj ############"
$PSQL -x -c "
SELECT created_at::timestamp(0) AS ne_zaman, role, left(content, 900) AS mesaj
  FROM brain_conversations
 WHERE content ~ '121[.,]?7|121\.79|121,79'
 ORDER BY created_at;"

echo "############ 2) ciro / hasilat / satis rakami gecen mesajlar ############"
$PSQL -x -c "
SELECT created_at::timestamp(0) AS ne_zaman, role, left(content, 700) AS mesaj
  FROM brain_conversations
 WHERE content ~* 'ciro|hasilat|hasılat|milyon|69[.,]1|M TL|mio'
 ORDER BY created_at DESC
 LIMIT 15;"

echo "############ 3) tum konusma (son 40 mesaj, kim ne demis) ############"
$PSQL -c "
SELECT created_at::timestamp(0) AS zaman, role,
       left(regexp_replace(content, E'[\n\r]+', ' ', 'g'), 110) AS mesaj
  FROM brain_conversations
 ORDER BY created_at DESC LIMIT 40;"

echo "############ 4) mesaj var mi, hic? ############"
$PSQL -c "SELECT count(*) AS toplam_mesaj, min(created_at)::date AS ilk,
                 max(created_at)::date AS son FROM brain_conversations;"
echo "  ⚠ NOT: deploy_brisa.sh BUGUNKU mesajlari silmisti."
echo "     Konusma 12 Temmuz'da olduysa duruyor olmali."

echo
echo "############ 5) KARSILASTIRMA: temiz veriden aylik ciro ############"
$PSQL -c "
SELECT to_char(fatura_tarihi,'YYYY-MM') AS ay,
       round(sum(satir_tutar)/1e6,2)                    AS ciro_KDVsiz_MTL,
       round(sum(satir_tutar)*1.20/1e6,2)               AS ciro_KDVli_MTL
  FROM bi_satis_faturalari
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND fatura_tarihi >= DATE '2026-01-01'
 GROUP BY 1 ORDER BY 1;"
echo "  ^ 121,79M hangi ayla / hangi tanimla ortusuyor? Gozle bak."
