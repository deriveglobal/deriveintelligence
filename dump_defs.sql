-- Derive · is-evreni tasiyan 6 view + 6 fonksiyon TANIMLARI (salt-okunur dump)
-- Cikti ~/KRB/agnostik_defs.txt'e yazilacak; asistan bridge ile okuyup donusturur.
\pset pager off
\pset format unaligned
\pset tuples_only on

\echo '========== VIEW: bi_rakip_fiyat_son =========='
SELECT pg_get_viewdef('bi_rakip_fiyat_son'::regclass, true);
\echo '========== VIEW: v_ekonomik_guncel =========='
SELECT pg_get_viewdef('v_ekonomik_guncel'::regclass, true);
\echo '========== VIEW: v_finans_ticari_sermaye =========='
SELECT pg_get_viewdef('v_finans_ticari_sermaye'::regclass, true);
\echo '========== VIEW: v_marj_cari_ay =========='
SELECT pg_get_viewdef('v_marj_cari_ay'::regclass, true);
\echo '========== VIEW: v_stok_deger_kanon =========='
SELECT pg_get_viewdef('v_stok_deger_kanon'::regclass, true);
\echo '========== VIEW: v_tedarikci_finansal =========='
SELECT pg_get_viewdef('v_tedarikci_finansal'::regclass, true);

\echo '========== FUNC: metrik_ciro =========='
SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='metrik_ciro';
\echo '========== FUNC: metrik_snapshot_al =========='
SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='metrik_snapshot_al';
\echo '========== FUNC: marka_saglik =========='
SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='marka_saglik';
\echo '========== FUNC: onsiparis_kaderi =========='
SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='onsiparis_kaderi';
\echo '========== FUNC: kategori_segment =========='
SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='kategori_segment';
\echo '========== FUNC: hesapla_rep_ozellik =========='
SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='hesapla_rep_ozellik';
\echo '========== DUMP SONU =========='
