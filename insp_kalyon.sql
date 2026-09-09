\pset pager off
SELECT m.id, m.firma, m.il, m.ilce, m.kayit_kaynagi, m.aktif, m.musteri_kodu,
       (SELECT count(*) FROM saha_ziyaret z WHERE z.musteri_id=m.id) ziyaret,
       u.full_name rep
 FROM saha_musteri m LEFT JOIN users u ON u.id=m.sorumlu_rep
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND upper(m.firma) LIKE 'KALYON%'
 ORDER BY m.aktif DESC, ziyaret DESC;
