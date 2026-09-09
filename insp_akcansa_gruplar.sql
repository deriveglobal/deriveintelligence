\pset pager off
\echo '== TÜM AKÇANSA kayıtları =='
SELECT m.id, m.firma, m.il, m.ilce, m.kayit_kaynagi, m.aktif, m.musteri_kodu,
       (SELECT count(*) FROM saha_ziyaret z WHERE z.musteri_id=m.id) ziyaret,
       u.full_name rep
 FROM saha_musteri m LEFT JOIN users u ON u.id=m.sorumlu_rep
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND (upper(m.firma) LIKE '%AKÇANSA%' OR upper(m.firma) LIKE '%AKCANSA%')
 ORDER BY m.aktif DESC, ziyaret DESC;
\echo '== Panelde AYNI İSİM birden çok kayıt (şubeye çevrilebilir gruplar) — ilk 30 =='
SELECT upper(m.firma) AS firma, count(*) AS kayit, count(DISTINCT m.il||'/'||m.ilce) AS farkli_lokasyon
 FROM saha_musteri m
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND m.aktif=true AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL'
 GROUP BY 1 HAVING count(*)>1
 ORDER BY kayit DESC LIMIT 30;
\echo '== Panelde toplam kaç kayıt, kaçı aynı-isim grubunda =='
WITH g AS (SELECT upper(firma) f, count(*) c FROM saha_musteri
           WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND aktif AND kayit_kaynagi='EXCEL_IMPORT_KONTROL'
           GROUP BY 1)
SELECT (SELECT count(*) FROM saha_musteri WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND aktif AND kayit_kaynagi='EXCEL_IMPORT_KONTROL') panel_toplam,
       (SELECT COALESCE(sum(c),0) FROM g WHERE c>1) coklu_kayit,
       (SELECT count(*) FROM g WHERE c>1) grup_sayisi,
       (SELECT COALESCE(sum(c-1),0) FROM g WHERE c>1) sube_olabilecek;
