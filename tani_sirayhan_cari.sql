-- TANI — Sirayhan Hafriyat: ERP'de var, aktivite icin bulunamiyor (Yildiray). ERP mi / saha mi / rep-scope mu?
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_sirayhan_cari.sql
\pset pager off
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- 1) ERP (master_musteri) — Sirayhan var mi? (TR-normalize eslesme)
SELECT musteri_kodu, musteri_adi, vergi_no, tc_no, son_fatura, fatura_sayisi, toplam_ciro
  FROM master_musteri
 WHERE tenant_id = :T
   AND lower(translate(musteri_adi,'İIıŞşÇçÖöÜüĞğ','iiissccoouugg')) LIKE '%sirayhan%'
 ORDER BY toplam_ciro DESC NULLS LAST LIMIT 20;

-- 2) SAHA (saha_musteri) — Sirayhan saha'ya girilmis mi? kime atali, aktif mi?
SELECT sm.id, sm.firma, sm.aktif, sm.musteri_kodu, sm.il, sm.sorumlu_rep::text AS sorumlu_rep_id,
       u.full_name AS sorumlu_adi
  FROM saha_musteri sm
  LEFT JOIN users u ON u.id = sm.sorumlu_rep
 WHERE sm.tenant_id = :T
   AND lower(translate(sm.firma,'İIıŞşÇçÖöÜüĞğ','iiissccoouugg')) LIKE '%sirayhan%'
 ORDER BY sm.aktif DESC LIMIT 20;

-- 3) Yildiray'in saha rolu (rep ise musteri-ara ERP carilerini gostermiyor)
SELECT u.id::text AS user_id, u.full_name, u.email, tum.module_role, tum.active
  FROM users u
  LEFT JOIN tenant_user_modules tum
    ON tum.user_id = u.id AND tum.tenant_id = :T AND tum.module_id = 'saha'
 WHERE u.full_name ILIKE '%yıldıray%' OR u.full_name ILIKE '%yildiray%' OR u.email ILIKE '%yildiray%';
