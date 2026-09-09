\pset pager off
SELECT kayit_kaynagi, count(*) FROM saha_musteri
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND created_at::date=current_date
 GROUP BY kayit_kaynagi ORDER BY count DESC;
SELECT count(*) AS kalan_oneri FROM saha_eslestirme_oneri
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND saha_musteri_id IN (SELECT id FROM saha_musteri WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND created_at::date=current_date);
SELECT count(*) FILTER (WHERE musteri_kodu IS NOT NULL) AS hala_linkli FROM saha_musteri
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND created_at::date=current_date;
