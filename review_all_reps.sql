-- TÜM repler: ERP'ye bağlı OLMAYAN (musteri_kodu NULL) aktif müşterileri rep-inceleme paneline al.
-- "aday yok = otomatik yeni" kararını geri alır → rep hepsini kendi onaylar. Guard: sahibi rep'in ziyareti olanlar.
-- Geri dönüş: EXCEL_IMPORT_KONTROL → SAHA_ZIYARETI. ERP-linkli müşterilere DOKUNMAZ.
BEGIN;
UPDATE saha_musteri m
   SET kayit_kaynagi='EXCEL_IMPORT_KONTROL', updated_at=now()
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND m.aktif=true
   AND m.musteri_kodu IS NULL
   AND m.kayit_kaynagi='SAHA_ZIYARETI'
   AND EXISTS (SELECT 1 FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.rep_id=m.sorumlu_rep);
COMMIT;
\pset pager off
\echo '== sonrası: tüm repler =='
SELECT COALESCE(u.full_name,'(sahipsiz)') AS rep,
       count(*) FILTER (WHERE m.aktif AND m.musteri_kodu IS NOT NULL) AS erp_linkli,
       count(*) FILTER (WHERE m.aktif AND m.musteri_kodu IS NULL AND m.kayit_kaynagi='SAHA_ZIYARETI') AS eslesmemis_listede,
       count(*) FILTER (WHERE m.aktif AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL') AS inceleme_panelinde
 FROM saha_musteri m LEFT JOIN users u ON u.id=m.sorumlu_rep
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
 GROUP BY 1 ORDER BY inceleme_panelinde DESC, rep;
