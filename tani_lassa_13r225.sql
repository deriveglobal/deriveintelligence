-- TANI — LASSA 13R22.5 aktif fiyat listesinde var mi, kac fiyat noktasi? (ebat eslesme guvenli mi)
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_lassa_13r225.sql
\pset pager off
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- 1) LASSA aktif listede 13R22.5 (ve yakin varyasyon) satirlari — desen + fiyat + kod
SELECT fu.liste_tarihi,
       UPPER(regexp_replace(fk.ebat,'\s','','g')) AS ebat_norm,
       fk.desen, fk.urun_kodu, fk.liste_fiyati
  FROM bi_fiyat_listesi_kalemler fk
  JOIN bi_fiyat_listesi_uploads fu ON fu.id = fk.upload_id
 WHERE fk.tenant_id = :T AND fu.aktif = true AND UPPER(fu.marka) = 'LASSA'
   AND UPPER(regexp_replace(fk.ebat,'\s','','g')) LIKE '13R22%'
 ORDER BY fu.liste_tarihi DESC, fk.liste_fiyati;

-- 2) En guncel LASSA listesinde bu ebatta KAC farkli fiyat var (belirsizlik olcusu)
SELECT UPPER(regexp_replace(fk.ebat,'\s','','g')) AS ebat_norm,
       COUNT(*) AS satir, COUNT(DISTINCT fk.liste_fiyati) AS farkli_fiyat,
       MIN(fk.liste_fiyati) AS min_fiyat, MAX(fk.liste_fiyati) AS max_fiyat
  FROM bi_fiyat_listesi_kalemler fk
  JOIN bi_fiyat_listesi_uploads fu ON fu.id = fk.upload_id
 WHERE fk.tenant_id = :T AND fu.aktif = true AND UPPER(fu.marka) = 'LASSA'
   AND UPPER(regexp_replace(fk.ebat,'\s','','g')) LIKE '13R22%'
   AND fu.liste_tarihi = (SELECT MAX(liste_tarihi) FROM bi_fiyat_listesi_uploads WHERE tenant_id=:T AND aktif AND UPPER(marka)='LASSA')
 GROUP BY 1 ORDER BY 1;

-- 3) Genel: kac YOK urunun ebat'i aktif listede TEK fiyatla mevcut (ebat-fallback ne kadar kurtarir)
SELECT COUNT(*) AS yok_urun,
       COUNT(*) FILTER (WHERE ef.tek_fiyat = 1) AS ebat_tek_fiyatla_kurtarilabilir
  FROM master_urun mu
  LEFT JOIN LATERAL (
    SELECT COUNT(DISTINCT fk.liste_fiyati) AS tek_fiyat
      FROM bi_fiyat_listesi_kalemler fk
      JOIN bi_fiyat_listesi_uploads fu ON fu.id = fk.upload_id
     WHERE fu.tenant_id = mu.tenant_id AND fu.aktif AND UPPER(fu.marka) = UPPER(mu.marka)
       AND UPPER(regexp_replace(fk.ebat,'\s','','g')) = mu.ebat_norm
  ) ef ON true
 WHERE mu.tenant_id = :T AND mu.eslesme_durumu = 'YOK' AND mu.ebat_norm IS NOT NULL;
