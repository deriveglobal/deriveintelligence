COPY (
  WITH g AS (
    SELECT upper(firma) f FROM saha_musteri
    WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND aktif AND kayit_kaynagi='EXCEL_IMPORT_KONTROL'
    GROUP BY 1 HAVING count(*)>1
  )
  SELECT m.id, m.firma, COALESCE(m.il,'') il, COALESCE(m.ilce,'') ilce, m.sorumlu_rep,
         (SELECT count(*) FROM saha_ziyaret z WHERE z.musteri_id=m.id) ziyaret
  FROM saha_musteri m
  WHERE m.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND m.aktif AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL'
    AND upper(m.firma) IN (SELECT f FROM g)
  ORDER BY upper(m.firma), ziyaret DESC
) TO STDOUT WITH CSV HEADER
