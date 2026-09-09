-- TANI — Sistemde LASSA Ticari/Commercial fiyat listesi var mi? Aktif LASSA listeleri 22.5 iceriyor mu?
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_lassa_ticari_liste.sql
\pset pager off
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- 1) LASSA iceren TUM yuklemeler (aktif+pasif) — ayri Ticari/Commercial liste var mi + 22.5 satir sayisi
SELECT fu.id, fu.marka, fu.aktif, fu.liste_tarihi,
       COUNT(fk.upload_id) AS satir,
       COUNT(*) FILTER (WHERE regexp_replace(COALESCE(fk.ebat,''),'\s','','g') ~ '22\.?5') AS ebat_225_satir
  FROM bi_fiyat_listesi_uploads fu
  LEFT JOIN bi_fiyat_listesi_kalemler fk ON fk.upload_id = fu.id
 WHERE fu.tenant_id = :T AND UPPER(fu.marka) LIKE '%LASSA%'
 GROUP BY fu.id, fu.marka, fu.aktif, fu.liste_tarihi
 ORDER BY fu.aktif DESC, fu.liste_tarihi DESC;

-- 2) Aktif LASSA listelerinde 22.5 iceren ornek ebatlar (varsa hangi gosterimle: 13R22.5 / 315/80R22.5 ...)
SELECT DISTINCT UPPER(regexp_replace(fk.ebat,'\s','','g')) AS ebat_norm
  FROM bi_fiyat_listesi_kalemler fk JOIN bi_fiyat_listesi_uploads fu ON fu.id = fk.upload_id
 WHERE fk.tenant_id = :T AND fu.aktif AND UPPER(fu.marka) LIKE '%LASSA%'
   AND regexp_replace(COALESCE(fk.ebat,''),'\s','','g') ~ '22\.?5'
 ORDER BY 1 LIMIT 50;

-- 3) TUM markalarda "ticari/commercial/ticr" etiketli ya da 22.5 agirlikli aktif yuklemeler (genel resim)
SELECT UPPER(fu.marka) marka, fu.aktif, fu.liste_tarihi,
       COUNT(*) FILTER (WHERE regexp_replace(COALESCE(fk.ebat,''),'\s','','g') ~ '22\.?5') AS ebat_225
  FROM bi_fiyat_listesi_uploads fu
  JOIN bi_fiyat_listesi_kalemler fk ON fk.upload_id = fu.id
 WHERE fu.tenant_id = :T AND fu.aktif
 GROUP BY 1,2,3 HAVING COUNT(*) FILTER (WHERE regexp_replace(COALESCE(fk.ebat,''),'\s','','g') ~ '22\.?5') > 0
 ORDER BY 1;
