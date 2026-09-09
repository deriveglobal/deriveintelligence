-- diag2_saha_model.sql — READ-ONLY. Musteri-paylasim modeli + hesap baglanti semasi.
\set ON_ERROR_STOP off
\pset pager off
\set T 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\echo '==================== A) REP ISIMLERI (ziyaret rep_id -> users) ===================='
SELECT u.id, u.full_name, u.name, u.email::text, u.role, u.status,
       (SELECT count(*) FROM saha_ziyaret z WHERE z.rep_id=u.id) AS ziyaret
 FROM users u
 WHERE u.id IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4',
                '0c5e2e6e-64a8-4c9b-9c45-81060ce6b042','44ec101f-9797-407c-8a29-1d0bb1317339',
                '08c5ed19-7e4f-41d2-8502-9dd01777906d','bd1787e9-2eb8-415b-9423-af3766f0fab4');

\echo '==================== B) MUSTERI PAYLASIM MODELI: ayni firma birden fazla sorumlu_rep? ===================='
SELECT count(*) AS toplam, count(DISTINCT firma) AS tekil_firma,
       count(*) FILTER (WHERE musteri_kodu IS NOT NULL AND musteri_kodu<>'') AS erp_bagli,
       count(*) FILTER (WHERE musteri_kodu IS NULL OR musteri_kodu='') AS erp_bagsiz
 FROM saha_musteri WHERE tenant_id=:'T';
\echo '-- ayni firma-adini birden cok sorumlu_rep tutuyor mu (per-rep vs paylasimli)?'
SELECT firma, count(*) AS satir, count(DISTINCT sorumlu_rep) AS rep_sayisi
 FROM saha_musteri WHERE tenant_id=:'T'
 GROUP BY firma HAVING count(*)>1 ORDER BY satir DESC LIMIT 15;
\echo '-- ayni musteri_kodu birden cok saha_musteri satirinda mi?'
SELECT musteri_kodu, count(*) FROM saha_musteri
 WHERE tenant_id=:'T' AND musteri_kodu IS NOT NULL AND musteri_kodu<>''
 GROUP BY musteri_kodu HAVING count(*)>1 ORDER BY count DESC LIMIT 10;
\echo '-- bir musteriye birden cok repin ziyareti var mi (paylasim kaniti)?'
SELECT musteri_id, count(DISTINCT rep_id) AS rep, count(*) AS ziyaret
 FROM saha_ziyaret WHERE tenant_id=:'T'
 GROUP BY musteri_id HAVING count(DISTINCT rep_id)>1 ORDER BY rep DESC, ziyaret DESC LIMIT 10;

\echo '==================== C) ESLESTIRME ONERI TABLOSU (onceki eslestirme araci) ===================='
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='saha_eslestirme_oneri' ORDER BY ordinal_position;
SELECT count(*) AS oneri_adet FROM saha_eslestirme_oneri;

\echo '==================== D) HESAP BAGLANTI SEMASI (Eftal ornek uzerinden) ===================='
\echo '-- tenant_users'
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='tenant_users' ORDER BY ordinal_position;
SELECT * FROM tenant_users WHERE user_id='ae0c55f9-68cc-421d-96d9-409222452f1a';
\echo '-- tenant_user_modules'
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='tenant_user_modules' ORDER BY ordinal_position;
SELECT * FROM tenant_user_modules WHERE user_id='ae0c55f9-68cc-421d-96d9-409222452f1a';
\echo '-- company_user_assignments'
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='company_user_assignments' ORDER BY ordinal_position;
SELECT * FROM company_user_assignments WHERE user_id='ae0c55f9-68cc-421d-96d9-409222452f1a';
\echo '-- users tam satir (Eftal) — sema/parola alanlarini gor'
SELECT id, email::text, full_name, name, role, status, auth_provider,
       (password_hash IS NOT NULL) AS parola_var, password_reset_required, telefon, created_at
 FROM users WHERE id='ae0c55f9-68cc-421d-96d9-409222452f1a';
\echo '-- saha_rep_profil / saha_rep_sehir var mi (rep bolgesi)?'
SELECT 'saha_rep_profil' t, count(*) FROM saha_rep_profil WHERE rep_id='ae0c55f9-68cc-421d-96d9-409222452f1a'
 UNION ALL SELECT 'saha_rep_sehir', count(*) FROM saha_rep_sehir WHERE rep_id='ae0c55f9-68cc-421d-96d9-409222452f1a';
\echo '==================== BITTI (dump ayri komutta) ===================='
