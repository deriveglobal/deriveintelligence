\pset pager off
\echo '== TÜM repler: müşteri durumu (linkli / eşleşmemiş-SAHA / inceleme / şubede-pasif) =='
SELECT COALESCE(u.full_name,'(sahipsiz)') AS rep,
       count(*) FILTER (WHERE m.aktif AND m.musteri_kodu IS NOT NULL) AS erp_linkli,
       count(*) FILTER (WHERE m.aktif AND m.musteri_kodu IS NULL AND m.kayit_kaynagi='SAHA_ZIYARETI') AS eslesmemis_listede,
       count(*) FILTER (WHERE m.aktif AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL') AS inceleme_panelinde,
       count(*) FILTER (WHERE NOT m.aktif) AS pasif
 FROM saha_musteri m
 LEFT JOIN users u ON u.id=m.sorumlu_rep
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
 GROUP BY 1 ORDER BY erp_linkli DESC, rep;
