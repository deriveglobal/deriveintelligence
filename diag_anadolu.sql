-- ============================================================
-- Derive · ANADOLU TANI (SALT-OKUNUR — hicbir sey yazmaz/degistirmez)
-- Iki blokeri teshis eder:
--   (A) metrik_marj_atom_uret => 0  (bi_marj_atom Anadolu icin dolmuyor)
--   (B) metrik_snapshot_al DSO NULL => bi_metrik_gecmis.deger NOT NULL ihlali
-- Anadolu tenant_id ADLA cozulur (uuid hardcode yok).
-- ============================================================
\pset pager off
\timing off

-- Anadolu id'yi degiskene al
SELECT id AS aid, name FROM platform_tenants WHERE name ILIKE '%anadolu%' ORDER BY 1 LIMIT 1;
\gset
\echo '>>> ANADOLU tenant_id =' :'aid'

\echo ''
\echo '=== 0. KRB kiyas id (bozulmadigini dogrulamak icin) ==='
SELECT id, name FROM platform_tenants ORDER BY name;

\echo ''
\echo '=== 1. Anadolu veri tablolari satir sayilari (marj_atom girdi zinciri) ==='
SELECT 'bi_satis_faturalari' t, count(*) n FROM bi_satis_faturalari WHERE tenant_id = :'aid'::text
UNION ALL SELECT 'bi_marj_fact',        count(*) FROM bi_marj_fact        WHERE tenant_id = :'aid'::text
UNION ALL SELECT 'bi_marj_atom',        count(*) FROM bi_marj_atom        WHERE tenant_id = :'aid'::text
UNION ALL SELECT 'bi_maliteti_sku?',    0
ORDER BY 1;

\echo ''
\echo '=== 1b. Ayni tablolar KRB (kiyas) — Anadolu neyi eksik gormek icin ==='
SELECT 'bi_marj_fact' t, count(*) n FROM bi_marj_fact
UNION ALL SELECT 'bi_marj_atom', count(*) FROM bi_marj_atom;

\echo ''
\echo '=== 2. metrik_marj_atom_uret FONKSIYON KAYNAGI (join sartlarini gormek icin) ==='
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname = 'metrik_marj_atom_uret';

\echo ''
\echo '=== 3. bi_marj_atom kolonlari (yapisal) ==='
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name='bi_marj_atom' ORDER BY ordinal_position;

\echo ''
\echo '=== 4. bi_marj_fact Anadolu ornek satirlar (deger var mi?) ==='
SELECT * FROM bi_marj_fact WHERE tenant_id = :'aid'::text LIMIT 5;

\echo ''
\echo '=== 5. v_finans_ticari_sermaye Anadolu satiri — HANGI KOLON NULL? ==='
SELECT * FROM v_finans_ticari_sermaye WHERE tenant_id = :'aid'::text;

\echo ''
\echo '=== 6. v_finans_ticari_sermaye TANIM (dso hangi bilesenden turuyor) ==='
SELECT pg_get_viewdef('v_finans_ticari_sermaye'::regclass, true);

\echo ''
\echo '=== 7. metrik_snapshot_al FONKSIYON KAYNAGI (dso INSERT satiri) ==='
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.proname = 'metrik_snapshot_al';

\echo ''
\echo '=== 8. Anadolu finans girdi tablolari (dso/dio/dpo bilesenleri icin) ==='
SELECT 'bi_alacak_yaslandirma' t, count(*) n FROM bi_alacak_yaslandirma WHERE tenant_id = :'aid'::text
UNION ALL SELECT 'bi_cari_bakiye',     count(*) FROM bi_cari_bakiye      WHERE tenant_id = :'aid'::text
UNION ALL SELECT 'bi_stok_anlik',      count(*) FROM bi_stok_anlik       WHERE tenant_id = :'aid'::text
UNION ALL SELECT 'bi_tedarikci_fatura',count(*) FROM bi_tedarikci_faturalari WHERE tenant_id = :'aid'::text
UNION ALL SELECT 'bi_tahsilat',        count(*) FROM bi_tahsilat         WHERE tenant_id = :'aid'::text
ORDER BY 1;

\echo ''
\echo '=== TANI SONU (hicbir sey yazilmadi) ==='
