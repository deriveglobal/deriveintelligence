-- ============================================================
-- Derive · SAHA MODULU RECON (SALT-OKUNUR) — Anadolu saha seed'ini
-- DOGRU tasarlamak icin KRB'nin saha yapisini haritalar. Yazma yok.
-- Ozellikle: rep KIMLIK/KULLANICI nasil kuruluyor (yetki modulune
-- dokunmadan seed edebilmek icin), saha_musteri/ziyaret/sahiplik semasi.
-- ============================================================
\pset pager off
SELECT id AS kid FROM platform_tenants WHERE name ILIKE '%kardes%' OR name ILIKE '%rot balans%' LIMIT 1;
\gset
SELECT id AS aid FROM platform_tenants WHERE name ILIKE '%anadolu%' LIMIT 1;
\gset
\echo '>>> KRB=' :'kid' '  ANADOLU=' :'aid'

\echo ''
\echo '=== 1. Saha ile ilgili tablolar (public) ==='
SELECT tablename FROM pg_tables WHERE schemaname='public'
  AND (tablename LIKE 'saha_%' OR tablename LIKE '%rep_kimlik%' OR tablename LIKE 'sap_musteri%' OR tablename='tenant_users' OR tablename='rep_kimlik_koprusu')
ORDER BY 1;

\echo ''
\echo '=== 2. rep_kimlik_koprusu — SEMA + KRB ornek (rep uuid <-> sap isim) ==='
SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='rep_kimlik_koprusu' ORDER BY ordinal_position;
\echo '--- KRB koprusu (durum + kolonlar) ---'
SELECT * FROM rep_kimlik_koprusu WHERE tenant_id::text=:'kid' LIMIT 10;
\echo '--- rep_kimlik_koprusu tenant kirilim (var mi tenant_id kolonu?) ---'
SELECT tenant_id::text t, count(*) FROM rep_kimlik_koprusu GROUP BY 1 ORDER BY 2 DESC;

\echo ''
\echo '=== 3. tenant_users — SEMA + KRB saha rep ornegi (rol/kimlik nasil) ==='
SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='tenant_users' ORDER BY ordinal_position;
\echo '--- KRB tenant_users rol dagilim ---'
SELECT role, count(*) FROM tenant_users WHERE tenant_id::text=:'kid' GROUP BY 1 ORDER BY 2 DESC;
\echo '--- ANADOLU tenant_users (su an kim var?) ---'
SELECT id, email, role FROM tenant_users WHERE tenant_id::text=:'aid';

\echo ''
\echo '=== 4. saha_musteri — SEMA + KRB satir + rep bag kolonu ==='
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='saha_musteri' ORDER BY ordinal_position;
SELECT 'KRB saha_musteri' t, count(*) FROM saha_musteri WHERE tenant_id::text=:'kid'
UNION ALL SELECT 'ANADOLU saha_musteri', count(*) FROM saha_musteri WHERE tenant_id::text=:'aid';

\echo ''
\echo '=== 5. saha_ziyaret — SEMA + KRB satir ==='
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='saha_ziyaret' ORDER BY ordinal_position;
SELECT 'KRB saha_ziyaret' t, count(*) FROM saha_ziyaret WHERE tenant_id::text=:'kid'
UNION ALL SELECT 'ANADOLU saha_ziyaret', count(*) FROM saha_ziyaret WHERE tenant_id::text=:'aid';

\echo ''
\echo '=== 6. sap_musteri_sahiplik — SEMA + KRB (musteri->rep defteri) ==='
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='sap_musteri_sahiplik' ORDER BY ordinal_position;
SELECT 'KRB sahiplik' t, count(*) FROM sap_musteri_sahiplik WHERE tenant_id::text=:'kid'
UNION ALL SELECT 'ANADOLU sahiplik', count(*) FROM sap_musteri_sahiplik WHERE tenant_id::text=:'aid';

\echo ''
\echo '=== 7. ANADOLU ERP satis_temsilcisi isimleri (saha rep bunlara eslenecek) ==='
SELECT satis_temsilcisi, count(*) satir, count(DISTINCT musteri_kodu) musteri
FROM bi_satis_faturalari WHERE tenant_id::text=:'aid' AND coalesce(satis_temsilcisi,'')<>''
GROUP BY 1 ORDER BY 2 DESC;

\echo ''
\echo '=== 8. ANADOLU musteri evreni (saha_musteri seed kaynagi) ==='
SELECT count(DISTINCT musteri_kodu) musteri_sayisi FROM bi_satis_faturalari WHERE tenant_id::text=:'aid';

\echo ''
\echo '=== RECON SONU (yazma yok) ==='
