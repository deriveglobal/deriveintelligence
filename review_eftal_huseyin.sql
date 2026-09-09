-- Eftal & Hüseyin'in ERP'ye bağlı OLMAYAN (musteri_kodu NULL) müşterilerini rep-inceleme paneline al.
-- Guard: yalnız sahibi rep'in ziyareti olanlar (yoksa listeden de panelden de kaybolurdu). Geri dönüş: SAHA_ZIYARETI.
BEGIN;
UPDATE saha_musteri m
   SET kayit_kaynagi='EXCEL_IMPORT_KONTROL', updated_at=now()
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND m.sorumlu_rep IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4')
   AND m.aktif=true
   AND m.musteri_kodu IS NULL
   AND m.kayit_kaynagi='SAHA_ZIYARETI'
   AND EXISTS (SELECT 1 FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.rep_id=m.sorumlu_rep);
COMMIT;
-- doğrulama
\pset pager off
\echo '== sonuç: Eftal/Hüseyin kayit_kaynagi dağılımı =='
SELECT CASE m.sorumlu_rep WHEN 'ae0c55f9-68cc-421d-96d9-409222452f1a' THEN 'Eftal' ELSE 'Hüseyin' END rep,
       m.kayit_kaynagi, count(*)
 FROM saha_musteri m
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND m.sorumlu_rep IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4')
   AND m.aktif=true
 GROUP BY 1,2 ORDER BY 1,3 DESC;
\echo '== inceleme dışında kalan (ziyareti olmayan) erp-yok =='
SELECT CASE m.sorumlu_rep WHEN 'ae0c55f9-68cc-421d-96d9-409222452f1a' THEN 'Eftal' ELSE 'Hüseyin' END rep, count(*)
 FROM saha_musteri m
 WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND m.sorumlu_rep IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4')
   AND m.aktif=true AND m.musteri_kodu IS NULL AND m.kayit_kaynagi='SAHA_ZIYARETI'
 GROUP BY 1;
