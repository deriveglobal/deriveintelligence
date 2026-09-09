-- Derive · AGNOSTİK FAZ C — evren_gruplar(tenant): is-evreni EXACT grup listesi.
-- grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI') site'lari icin. Default = o iki grup
-- (KRB birebir). Idempotent. Sifir davranis degisikligi.
\pset pager off
CREATE OR REPLACE FUNCTION evren_gruplar(p_tenant uuid) RETURNS text[]
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
      (SELECT array_agg(x) FROM jsonb_array_elements_text(
         (SELECT config_json->'evren_gruplar' FROM platform_tenants WHERE id=p_tenant)) x),
      ARRAY['LASTIK TUKETICI','LASTIK TICARI'])
$$;
CREATE OR REPLACE FUNCTION evren_gruplar(p_tenant text) RETURNS text[]
  LANGUAGE sql STABLE AS $$ SELECT evren_gruplar($1::uuid) $$;

-- config (explicit; default zaten ayni) — her iki tenant lastik
UPDATE platform_tenants
   SET config_json = COALESCE(config_json,'{}'::jsonb)
       || jsonb_build_object('evren_gruplar', '["LASTIK TUKETICI","LASTIK TICARI"]'::jsonb)
 WHERE id IN ('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa','42822870-4ea3-424d-a16f-50b91afca32c')
   AND NOT (COALESCE(config_json,'{}'::jsonb) ? 'evren_gruplar');

\echo '=== evren_gruplar dogrulama (ikisi de {LASTIK TUKETICI,LASTIK TICARI}) ==='
SELECT name, evren_gruplar(id) FROM platform_tenants ORDER BY name;

\echo '=== esdeger kontrol: IN(...) vs = ANY(evren_gruplar) KRB (esit olmali) ==='
SELECT (SELECT count(*) FROM bi_satis_faturalari WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI'))
     = (SELECT count(*) FROM bi_satis_faturalari WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND grup_adi = ANY(evren_gruplar(tenant_id::text))) AS esdeger;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_EVREN_GRUPLAR_FOUNDATION_V1',
       'evren_gruplar(tenant) text[] helper + config: grup_adi IN(LASTIK TUKETICI,LASTIK TICARI) per-tenant',
       'Faz C: exact-grup listesi per-tenant; default o iki grup (KRB birebir).',
       '{"fonksiyon":["evren_gruplar(uuid/text)"],"config_key":"evren_gruplar","default":["LASTIK TUKETICI","LASTIK TICARI"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_EVREN_GRUPLAR_FOUNDATION_V1');
\echo '=== foundation SONU ==='
