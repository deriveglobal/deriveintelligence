\pset pager off
\echo '== Eftal & Hüseyin — müşteri özeti (sorumlu_rep) =='
SELECT CASE m.sorumlu_rep WHEN 'ae0c55f9-68cc-421d-96d9-409222452f1a' THEN 'Eftal'
                          WHEN '80fff50c-ffc7-4623-a382-a814263609c4' THEN 'Hüseyin' END AS rep,
       count(*) AS musteri,
       count(*) FILTER (WHERE m.musteri_kodu IS NOT NULL) AS erp_linkli,
       count(*) FILTER (WHERE m.musteri_kodu IS NULL)     AS erp_yok,
       count(*) FILTER (WHERE m.kayit_kaynagi='EXCEL_IMPORT_KONTROL') AS kontrol_bekleyen,
       count(*) FILTER (WHERE NOT m.aktif) AS pasif
 FROM saha_musteri m
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND m.sorumlu_rep IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4')
 GROUP BY 1 ORDER BY 1;
\echo '== kayit_kaynagi dağılımı (bu iki rep) =='
SELECT CASE m.sorumlu_rep WHEN 'ae0c55f9-68cc-421d-96d9-409222452f1a' THEN 'Eftal' ELSE 'Hüseyin' END AS rep,
       m.kayit_kaynagi, count(*)
 FROM saha_musteri m
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND m.sorumlu_rep IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4')
 GROUP BY 1,2 ORDER BY 1,3 DESC;
\echo '== ziyaretleri (değişmedi doğrulaması) =='
SELECT rep_adi, count(*) ziyaret, min(ziyaret_tarihi) ilk, max(ziyaret_tarihi) son, max(updated_at)::date son_guncelleme
 FROM saha_ziyaret
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND rep_id IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4')
 GROUP BY rep_adi;
