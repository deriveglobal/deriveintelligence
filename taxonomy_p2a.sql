-- ============================================================
-- Derive · AGNOSTİK — TAKSONOMI 2a/2 (DB, buildless)
--  * tenant_taksonomi override tablosu (KRB bos -> tire default)
--  * kategori_segment(p,t) overload (override yoksa tenant-less tire default)
--  * evren_yuksek_marj(tenant) helper (default OTR/IND/LSR/4 MEVSIM)
--  * v_marj_cari_ay + hesapla_rep_ozellik -> per-tenant taksonomi
--  KRB override YOK -> 2-arg = 1-arg -> catal/marj BIREBIR (kanit asagida).
-- ============================================================
\pset pager off
SET lock_timeout='15s';

CREATE TABLE IF NOT EXISTS tenant_taksonomi (
  tenant_id uuid NOT NULL, kategori text NOT NULL, segment text NOT NULL,
  PRIMARY KEY (tenant_id, kategori));

-- 2-arg overload: once per-tenant override, yoksa tenant-less tire default
CREATE OR REPLACE FUNCTION kategori_segment(p text, t uuid) RETURNS text
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE((SELECT segment FROM tenant_taksonomi WHERE tenant_id=t AND kategori=p),
                    kategori_segment(p))
$$;

-- yuksek-marj kategori seti (default = KRB mevcut 4)
CREATE OR REPLACE FUNCTION evren_yuksek_marj(p_tenant uuid) RETURNS text[]
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
      (SELECT array_agg(x) FROM jsonb_array_elements_text(
        (SELECT config_json->'yuksek_marj_kategoriler' FROM platform_tenants WHERE id=p_tenant)) x),
      ARRAY['OTR','IND','LSR','4 MEVSIM'])
$$;

-- KRB KANITI: 2-arg = 1-arg tum KRB kategorilerinde (override yok -> t)
\echo '=== KANIT: kategori_segment 1-arg = 2-arg tum KRB kategorileri (t bekleriz) ==='
SELECT bool_and(kategori_segment(kategori) = kategori_segment(kategori, 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid)) AS esdeger
FROM (SELECT DISTINCT kategori FROM bi_satis_faturalari
      WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND kategori IS NOT NULL) q;

-- v_marj_cari_ay: kategori_segment(s.kategori) -> +s.tenant_id
DO $mig$
DECLARE d text; oldp text;
BEGIN
  SELECT pg_get_viewdef('v_marj_cari_ay'::regclass, true) INTO d;
  oldp := 'kategori_segment(s.kategori)';
  IF position(oldp IN d)=0 THEN RAISE EXCEPTION 'ANCHOR YOK: v_marj_cari_ay'; END IF;
  EXECUTE 'CREATE OR REPLACE VIEW public.v_marj_cari_ay AS ' || replace(d, oldp, 'kategori_segment(s.kategori, s.tenant_id)');
  RAISE NOTICE 'v_marj_cari_ay -> per-tenant taksonomi.';
END $mig$;

-- hesapla_rep_ozellik: kategori IN(4) -> = ANY(evren_yuksek_marj(p_tenant))
DO $mig$
DECLARE d text; oldp text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='hesapla_rep_ozellik';
  oldp := 'kategori IN (''OTR'',''IND'',''LSR'',''4 MEVSIM'')';
  IF position(oldp IN d)=0 THEN RAISE EXCEPTION 'ANCHOR YOK: hesapla_rep_ozellik yuksek-marj'; END IF;
  EXECUTE replace(d, oldp, 'kategori = ANY(evren_yuksek_marj(p_tenant))');
  RAISE NOTICE 'hesapla_rep_ozellik yuksek-marj -> config.';
END $mig$;

\echo '=== v_marj_cari_ay KRB satir sayisi (sanity, >0) ==='
SELECT count(*) FROM v_marj_cari_ay WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';

\echo '=== kalan kategori_segment(s.kategori) tek-arg VIEW/FONK (0 olmali) ==='
SELECT 'v_marj_cari_ay' o FROM pg_views WHERE schemaname='public' AND viewname='v_marj_cari_ay' AND definition ~ 'kategori_segment\([^,)]+\)'
  AND definition !~ 'kategori_segment\([^,)]+,';

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_TAKSONOMI_KATEGORI_V1',
       'tenant_taksonomi override + kategori_segment(p,t) + evren_yuksek_marj; v_marj_cari_ay & hesapla_rep_ozellik per-tenant',
       'Taksonomi per-tenant; KRB override yok -> tire default -> catal/marj/yuksek-marj BIREBIR (esdeger kanitli). Server call-site 2b build.',
       '{"tablo":"tenant_taksonomi","overload":"kategori_segment(text,uuid)","helper":"evren_yuksek_marj","obj":["v_marj_cari_ay","hesapla_rep_ozellik"],"server_callsite":"2b"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_TAKSONOMI_KATEGORI_V1');
\echo '=== TAKSONOMI 2a SONU ==='
