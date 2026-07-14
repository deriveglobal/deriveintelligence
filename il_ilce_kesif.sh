#!/usr/bin/env bash
# IL_ILCE_KESIF — hasarin BUYUKLUGUNU olcmeden cozum yazmam.
#   Oneri 4a4e905d (Eftal): "Yeni musteri veya yeni ziyaret girerken il-ilce secimi
#   otomatik olmali. Diger turlu buyuk,kucuk harf veya cok fazla yazim yanlisi olacaktir."
#
# ⚠ VERI KALITESI SORUNLARI SESSIZDIR. Kimse hata gormez, sadece raporlar yanlis cikar.
#   "Kocaeli" ile "KOCAELİ" ayri il sayilirsa, bolge bazli her rapor bozulur.
# Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ HASAR — kac farkli 'il' yazimi var? ############"
$PSQL -c "
SELECT count(DISTINCT il)                      AS farkli_il_yazimi,
       count(DISTINCT upper(trim(il)))         AS normalize_edilince,
       count(DISTINCT ilce)                    AS farkli_ilce_yazimi,
       count(DISTINCT upper(trim(ilce)))       AS ilce_normalize
  FROM saha_musteri WHERE aktif;"
echo "  ⚠ Iki sayi arasindaki fark = YAZIM HATASI sayisi."

echo
echo "############ 2) AYNI IL, FARKLI YAZIM ############"
$PSQL -c "
SELECT upper(trim(il)) AS normal, count(DISTINCT il) AS yazim_sayisi,
       string_agg(DISTINCT il, ' | ') AS yazimlar, count(*) AS musteri
  FROM saha_musteri WHERE aktif AND il IS NOT NULL
 GROUP BY 1 HAVING count(DISTINCT il) > 1
 ORDER BY 2 DESC, 4 DESC LIMIT 15;"

echo
echo "############ 3) AYNI ILCE, FARKLI YAZIM ############"
$PSQL -c "
SELECT upper(trim(ilce)) AS normal, count(DISTINCT ilce) AS yazim_sayisi,
       string_agg(DISTINCT ilce, ' | ') AS yazimlar, count(*) AS musteri
  FROM saha_musteri WHERE aktif AND ilce IS NOT NULL
 GROUP BY 1 HAVING count(DISTINCT ilce) > 1
 ORDER BY 2 DESC, 4 DESC LIMIT 15;"

echo
echo "############ 4) ⚠ GECERSIZ IL — Turkiye'de olmayan ad? ############"
$PSQL -c "
SELECT il, count(*) AS musteri
  FROM saha_musteri WHERE aktif AND il IS NOT NULL
 GROUP BY 1 ORDER BY 2 DESC LIMIT 25;"
echo "  ⚠ Listede ilce adi, mahalle adi ya da sacma bir sey varsa: il alani ILCE ile doldurulmus."

echo
echo "############ 5) BOS OLANLAR ############"
$PSQL -c "
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE il IS NULL OR trim(il)='')     AS il_bos,
       count(*) FILTER (WHERE ilce IS NULL OR trim(ilce)='') AS ilce_bos,
       count(*) FILTER (WHERE lat IS NOT NULL)               AS konumu_var
  FROM saha_musteri WHERE aktif;"

echo
echo "############ 6) ARAYUZ — il/ilce nerede giriliyor? ############"
grep -n "ym-il\|ym-ilce\|zf-il\|\"il\"\|il:" shells/saha.js | head -12

echo
echo "############ 7) IL-ILCE KAYNAGI VAR MI? (tabloda hazir liste) ############"
$PSQL -c "
SELECT relname, n_live_tup FROM pg_stat_user_tables
 WHERE relname ~ 'il|ilce|sehir|city|district' ORDER BY n_live_tup DESC LIMIT 10;"
$PSQL -c "SELECT DISTINCT sehir FROM master_musteri WHERE sehir IS NOT NULL ORDER BY 1 LIMIT 20;"
echo "  ⚠ master_musteri.sehir ERP'den geliyor — bu, TEMIZ bir il listesi olabilir."
echo "     Ilce icin kaynak var mi, ona bakmali."
