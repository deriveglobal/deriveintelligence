-- Shared vs private data split (tire-vertical product).
-- SHARED industry/market data -> globally readable by all tenants: drop strict tenant RLS.
-- (Safe now: the app still runs as superuser, which bypassed RLS anyway. This makes the
--  model correct for when Phase B puts reads on the scoped app_tenant role.)
BEGIN;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'bi_rakip_fiyat','bi_rakip_fiyat_son','bi_rakip_fiyat_gecmis',
    'bi_pazar_fiyat','bi_pazar_talep','bi_arac_kategorileri',
    'bi_fiyat_listesi_kalemler','bi_fiyat_listesi_uploads',
    'bi_ekonomik_parametreler'
  ]
  LOOP
    IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
               WHERE n.nspname='public' AND c.relname=t AND c.relkind='r') THEN
      EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', t);
      EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON public.%I', t);
      RAISE NOTICE 'SHARED (RLS off): %', t;
    END IF;
  END LOOP;
END $$;
COMMIT;

-- verify: shared tables should now be relrowsecurity=false
SELECT relname AS shared_table, relrowsecurity AS rls_on
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND relname IN
  ('bi_rakip_fiyat','bi_rakip_fiyat_son','bi_rakip_fiyat_gecmis','bi_pazar_fiyat','bi_pazar_talep',
   'bi_arac_kategorileri','bi_fiyat_listesi_kalemler','bi_fiyat_listesi_uploads','bi_ekonomik_parametreler')
ORDER BY 1;
