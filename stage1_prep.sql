-- ============================================================================
-- Stage 1 prep — scoped role + full RLS coverage.
-- NON-DESTRUCTIVE: the live app connects as assessment_app (superuser + BYPASSRLS),
-- which ignores RLS entirely, so enabling policies here does NOT change its behaviour.
-- Enforcement only begins when the app is switched to app_tenant (a later, deliberate step).
-- All operations below are metadata-only (no table rewrites) or tiny backfills.
-- ============================================================================
BEGIN;

-- 1) Scoped application role: NOT superuser, does NOT bypass RLS. This is the role
--    the app will use after the flip, so policies actually apply to it.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_tenant') THEN
    CREATE ROLE app_tenant LOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
END $$;

GRANT CONNECT ON DATABASE assessment_platform TO app_tenant;
GRANT USAGE  ON SCHEMA public TO app_tenant;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA public TO app_tenant;
GRANT USAGE, SELECT                  ON ALL SEQUENCES IN SCHEMA public TO app_tenant;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES    TO app_tenant;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT                  ON SEQUENCES TO app_tenant;

-- 2) Must-scope table with no tenant_id and no FK: saha_teklif_log.
--    Add the column (nullable, metadata-only) and backfill from its parent quote.
ALTER TABLE saha_teklif_log ADD COLUMN IF NOT EXISTS tenant_id uuid;
UPDATE saha_teklif_log l
   SET tenant_id = t.tenant_id
  FROM saha_teklif t
 WHERE t.id = l.teklif_id AND l.tenant_id IS NULL;

-- 3) Enable RLS + FORCE + the standard tenant_isolation policy on EVERY table that
--    has a tenant_id column but no RLS yet. Mirrors the 13 existing policies exactly.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relrowsecurity = false
      AND EXISTS (
        SELECT 1 FROM information_schema.columns col
        WHERE col.table_schema = 'public'
          AND col.table_name   = c.relname
          AND col.column_name  = 'tenant_id')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.relname);
    EXECUTE format('ALTER TABLE public.%I FORCE  ROW LEVEL SECURITY', r.relname);
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON public.%I', r.relname);
    -- text comparison so it works whether tenant_id is uuid OR text
    EXECUTE format(
      'CREATE POLICY tenant_isolation ON public.%I USING (tenant_id::text = current_setting(''app.current_tenant_id'', true))',
      r.relname);
    RAISE NOTICE 'RLS enabled + policy created on %', r.relname;
  END LOOP;
END $$;

COMMIT;

-- Post-check: how many tenant tables now have RLS
SELECT count(*) AS rls_tables_total FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE c.relrowsecurity=true AND n.nspname='public';
