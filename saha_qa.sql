-- ============================================================
-- Derive · ANADOLU SAHA QA PROBE (SALT-OKUNUR)
-- Yonetici/CEO saha yuzeylerinin arka-verisi Anadolu icin PASS/FAIL +
-- izolasyon + turetilmis katman (master/cache/rep-ozellik) hazir mi.
-- ============================================================
\pset pager off
SELECT id AS aid FROM platform_tenants WHERE name ILIKE '%anadolu%' LIMIT 1; \gset
\echo '=================== ANADOLU SAHA QA ==================='

WITH probe(surface, n) AS (
  SELECT 'saha rep roster (kopru)', (SELECT count(*) FROM rep_kimlik_koprusu WHERE tenant_id::text=:'aid' AND durum='saha')
  UNION ALL SELECT 'rep login (saha:rep modul)', (SELECT count(*) FROM tenant_user_modules WHERE tenant_id::text=:'aid' AND module_id='saha' AND module_role='rep' AND active)
  UNION ALL SELECT 'saha_musteri', (SELECT count(*) FROM saha_musteri WHERE tenant_id::text=:'aid')
  UNION ALL SELECT 'sap_musteri_sahiplik', (SELECT count(*) FROM sap_musteri_sahiplik WHERE tenant_id::text=:'aid')
  UNION ALL SELECT 'saha_satis_skor (BG/NBD)', (SELECT count(*) FROM saha_satis_skor WHERE tenant_id::text=:'aid')
  UNION ALL SELECT 'saha_ziyaret (gecmis)', (SELECT count(*) FROM saha_ziyaret WHERE tenant_id::text=:'aid')
  UNION ALL SELECT 'musteri->rep bagli (sorumlu_rep dolu)', (SELECT count(*) FROM saha_musteri WHERE tenant_id::text=:'aid' AND sorumlu_rep IS NOT NULL)
)
SELECT CASE WHEN n>0 THEN '✅ PASS' ELSE '❌ FAIL' END sonuc, surface, n FROM probe ORDER BY (n>0), surface;

\echo ''
\echo '=== saha_satis_skor SEGMENT dagilimi (gercek BG/NBD mi, etiketler ne?) ==='
SELECT segment, count(*), round(avg(p_alive),2) ort_p_alive, round(avg(exp30),2) ort_exp30
FROM saha_satis_skor WHERE tenant_id::text=:'aid' GROUP BY segment ORDER BY 2 DESC;

\echo ''
\echo '=== TURETILMIS KATMAN: manager view + rep karakter icin gerekenler ==='
SELECT 'master_musteri' t, (SELECT count(*) FROM master_musteri WHERE tenant_id::text=:'aid') anadolu
UNION ALL SELECT 'saha_cari_cache', (SELECT count(*) FROM saha_cari_cache WHERE tenant_id::text=:'aid')
UNION ALL SELECT 'saha_rep_ozellik (karakter)', (SELECT count(*) FROM saha_rep_ozellik WHERE tenant_id::text=:'aid')
UNION ALL SELECT 'saha_rep_gelisim (portre)', (SELECT count(*) FROM saha_rep_gelisim WHERE tenant_id::text=:'aid')
ORDER BY 1;

\echo ''
\echo '=== rep karakter motoru fonksiyon imzasi (tetiklemek icin) ==='
SELECT p.proname, pg_get_function_identity_arguments(p.oid) args
FROM pg_proc p WHERE p.proname IN ('hesapla_rep_ozellik','refresh_saha_masters','refreshSahaMasters')
   OR p.proname ILIKE '%rep_ozellik%' OR p.proname ILIKE '%saha_master%';

\echo ''
\echo '=== IZOLASYON: saha yuzeyleri Anadolu vs diger tenant (karismamali) ==='
SELECT 'saha_musteri' t, count(*) FILTER (WHERE tenant_id::text=:'aid') anadolu, count(*) FILTER (WHERE tenant_id::text<>:'aid') diger FROM saha_musteri
UNION ALL SELECT 'saha_ziyaret', count(*) FILTER (WHERE tenant_id::text=:'aid'), count(*) FILTER (WHERE tenant_id::text<>:'aid') FROM saha_ziyaret
UNION ALL SELECT 'saha_satis_skor', count(*) FILTER (WHERE tenant_id::text=:'aid'), count(*) FILTER (WHERE tenant_id::text<>:'aid') FROM saha_satis_skor
UNION ALL SELECT 'rep_kimlik_koprusu', count(*) FILTER (WHERE tenant_id::text=:'aid'), count(*) FILTER (WHERE tenant_id::text<>:'aid') FROM rep_kimlik_koprusu
ORDER BY 1;

\echo ''
\echo '=== QA SONU (yazma yok) ==='
