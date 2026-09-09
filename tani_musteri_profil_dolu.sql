-- TANI — saha_musteri profil kolonlari DOLU mu (write-back calisiyor mu)? Prefill kaynagi mi sorun?
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_musteri_profil_dolu.sql
\pset pager off
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- 1) Genel: kac TUKETICI musteride profil (raf/rakip/bayi) DOLU?
SELECT COUNT(*) AS toplam_tuketici,
       COUNT(*) FILTER (WHERE raf_markalar IS NOT NULL AND array_length(raf_markalar,1) > 0)       AS raf_dolu,
       COUNT(*) FILTER (WHERE rakip_toptancilar IS NOT NULL AND array_length(rakip_toptancilar,1)>0) AS rakip_dolu,
       COUNT(*) FILTER (WHERE bayilikler IS NOT NULL AND array_length(bayilikler,1) > 0)            AS bayi_dolu
  FROM saha_musteri WHERE tenant_id=:T AND tip='TUKETICI' AND aktif;

-- 2) Bugun ziyaret edilen bu musterilerde profil kolonu dolu mu? (write-back sonucu)
SELECT LEFT(firma,24) firma, raf_markalar, rakip_toptancilar, bayilikler, kis_stok, yaz_stok
  FROM saha_musteri
 WHERE tenant_id=:T AND tip='TUKETICI'
   AND firma IN ('Kaplan Oto Lastik','Kocaeli Rot Balans','Emrah Kaya','Kalyoncular Lastik','Ser Lastik','Mürsel Seyhan','Reis Oto Lastik')
 ORDER BY firma;
