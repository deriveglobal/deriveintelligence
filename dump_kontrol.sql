COPY (
  SELECT m.id, m.firma, COALESCE(m.il,'') il, COALESCE(m.ilce,'') ilce, m.sorumlu_rep,
         (SELECT count(*) FROM saha_ziyaret z WHERE z.musteri_id=m.id) AS ziyaret
  FROM saha_musteri m
  WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
    AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL' AND m.aktif=true
) TO STDOUT WITH CSV HEADER
