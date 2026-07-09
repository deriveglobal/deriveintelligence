-- migrate_rakip_tenant_uuid.sql
-- Fixes tenant_id type in rakip tables: INTEGER → TEXT (UUID-compatible)
-- Root cause: requireModuleAccess returns UUID string, tables had INTEGER columns
-- Safe to run multiple times (checks column type first)

DO $$
DECLARE
  v_tid TEXT;
  v_col_type TEXT;
BEGIN
  -- Get the real tenant UUID from platform_tenants
  SELECT id::text INTO v_tid FROM platform_tenants ORDER BY created_at LIMIT 1;
  IF v_tid IS NULL THEN
    RAISE EXCEPTION 'platform_tenants tablosu boş — migration çalıştırılamaz';
  END IF;
  RAISE NOTICE 'Tenant UUID: %', v_tid;

  -- ── bi_rakip_fiyat ──────────────────────────────────────────────────────────
  SELECT data_type INTO v_col_type
    FROM information_schema.columns
   WHERE table_name = 'bi_rakip_fiyat' AND column_name = 'tenant_id';

  IF v_col_type = 'integer' THEN
    ALTER TABLE bi_rakip_fiyat ALTER COLUMN tenant_id TYPE TEXT USING tenant_id::TEXT;
    EXECUTE format('ALTER TABLE bi_rakip_fiyat ALTER COLUMN tenant_id SET DEFAULT %L', v_tid);
    EXECUTE format('UPDATE bi_rakip_fiyat SET tenant_id = %L WHERE tenant_id = %L', v_tid, '1');
    RAISE NOTICE 'bi_rakip_fiyat.tenant_id: INTEGER → TEXT, % satır güncellendi', found;
  ELSE
    RAISE NOTICE 'bi_rakip_fiyat.tenant_id zaten TEXT — atlanıyor';
  END IF;

  -- ── bi_rakip_izle ───────────────────────────────────────────────────────────
  SELECT data_type INTO v_col_type
    FROM information_schema.columns
   WHERE table_name = 'bi_rakip_izle' AND column_name = 'tenant_id';

  IF v_col_type = 'integer' THEN
    ALTER TABLE bi_rakip_izle ALTER COLUMN tenant_id TYPE TEXT USING tenant_id::TEXT;
    EXECUTE format('ALTER TABLE bi_rakip_izle ALTER COLUMN tenant_id SET DEFAULT %L', v_tid);
    EXECUTE format('UPDATE bi_rakip_izle SET tenant_id = %L WHERE tenant_id = %L', v_tid, '1');
    RAISE NOTICE 'bi_rakip_izle.tenant_id: INTEGER → TEXT';
  ELSE
    RAISE NOTICE 'bi_rakip_izle.tenant_id zaten TEXT — atlanıyor';
  END IF;

  -- ── bi_rakip_fiyat_alarm ────────────────────────────────────────────────────
  SELECT data_type INTO v_col_type
    FROM information_schema.columns
   WHERE table_name = 'bi_rakip_fiyat_alarm' AND column_name = 'tenant_id';

  IF v_col_type = 'integer' THEN
    ALTER TABLE bi_rakip_fiyat_alarm ALTER COLUMN tenant_id TYPE TEXT USING tenant_id::TEXT;
    EXECUTE format('ALTER TABLE bi_rakip_fiyat_alarm ALTER COLUMN tenant_id SET DEFAULT %L', v_tid);
    EXECUTE format('UPDATE bi_rakip_fiyat_alarm SET tenant_id = %L WHERE tenant_id = %L', v_tid, '1');
    RAISE NOTICE 'bi_rakip_fiyat_alarm.tenant_id: INTEGER → TEXT';
  ELSE
    RAISE NOTICE 'bi_rakip_fiyat_alarm.tenant_id zaten TEXT — atlanıyor';
  END IF;

  -- ── bi_rakip_izle_ayar: add tenant_id column (global settings → per-tenant) ─
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'bi_rakip_izle_ayar' AND column_name = 'tenant_id'
  ) THEN
    EXECUTE format('ALTER TABLE bi_rakip_izle_ayar ADD COLUMN tenant_id TEXT NOT NULL DEFAULT %L', v_tid);
    -- Make PK composite (key + tenant_id)
    ALTER TABLE bi_rakip_izle_ayar DROP CONSTRAINT IF EXISTS bi_rakip_izle_ayar_pkey;
    ALTER TABLE bi_rakip_izle_ayar ADD PRIMARY KEY (key, tenant_id);
    -- Add scraping_schedule + scraping_brands keys for new Settings tab
    EXECUTE format(
      'INSERT INTO bi_rakip_izle_ayar (key, value, tenant_id) VALUES
        (''alarm_esigi_varsayilan'', ''10.0'', %1$L),
        (''max_izle_sayisi'',        ''50'',   %1$L),
        (''scraping_aktif'',         ''true'', %1$L),
        (''scraping_sikligi'',       ''3'',    %1$L),
        (''scraping_saatleri'',      ''08:00,13:00,18:00'', %1$L),
        (''scraping_markalar'',      ''Continental,Bridgestone,Michelin,Lassa,Pirelli'', %1$L),
        (''scraping_kaynaklar'',     ''lastikborsasi,lastiksepeti,n11'', %1$L)
       ON CONFLICT (key, tenant_id) DO NOTHING', v_tid
    );
    RAISE NOTICE 'bi_rakip_izle_ayar: tenant_id kolonu eklendi, varsayılan ayarlar eklendi';
  ELSE
    RAISE NOTICE 'bi_rakip_izle_ayar.tenant_id zaten mevcut — atlanıyor';
  END IF;

  RAISE NOTICE '✓ Migration tamamlandı. Tenant: %', v_tid;
END $$;
