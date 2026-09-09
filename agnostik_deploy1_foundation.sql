-- ============================================================
-- Derive · AGNOSTİK FAZ C — DEPLOY 1: TEMEL (sifir davranis degisikligi)
-- Per-tenant is-evreni config + STABLE helper'lar. Henuz kimse cagirmiyor.
-- KRB company_profile eksikti -> backfill (kimlik-sizinti backstop).
-- Idempotent. KRB davranisi DEGISMEZ (helper'lar 'LASTIK%' doner).
-- ============================================================
\pset pager off

-- 1) evren_desen(tenant) — is-evreni grup LIKE deseni; config yoksa 'LASTIK%' (KRB geriye-uyum)
CREATE OR REPLACE FUNCTION evren_desen(p_tenant uuid) RETURNS text
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE(NULLIF(config_json->>'evren_desen',''), 'LASTIK%')
      FROM platform_tenants WHERE id = p_tenant
$$;
-- text overload (cagrilarin cogu tenant'i ::text tutuyor)
CREATE OR REPLACE FUNCTION evren_desen(p_tenant text) RETURNS text
  LANGUAGE sql STABLE AS $$ SELECT evren_desen($1::uuid) $$;

-- 2) evren_tanim(tenant) — AI prompt is-tanimi ("lastik toptancisi"); config yoksa varsayilan
CREATE OR REPLACE FUNCTION evren_tanim(p_tenant uuid) RETURNS text
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE(NULLIF(config_json->>'is_tanimi',''), 'lastik toptancısı')
      FROM platform_tenants WHERE id = p_tenant
$$;
CREATE OR REPLACE FUNCTION evren_tanim(p_tenant text) RETURNS text
  LANGUAGE sql STABLE AS $$ SELECT evren_tanim($1::uuid) $$;

-- 3) Config backfill (idempotent): her tenant evren_desen + is_tanimi (ikisi de lastik)
UPDATE platform_tenants
   SET config_json = COALESCE(config_json,'{}'::jsonb)
       || jsonb_build_object('evren_desen','LASTIK%','is_tanimi','lastik toptancısı')
 WHERE id IN ('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa','42822870-4ea3-424d-a16f-50b91afca32c')
   AND NOT (COALESCE(config_json,'{}'::jsonb) ? 'evren_desen');

-- 4) KRB company_profile eksik -> factual backfill (kimlik-sizinti backstop; prompt agnostiklesince gerekli)
UPDATE platform_tenants
   SET config_json = COALESCE(config_json,'{}'::jsonb)
       || jsonb_build_object('company_profile',
            'Kardeşler Rot Balans — lastik toptan ticareti ve dağıtımı. İş kolları: binek/tüketici (PSR) ve ticari/filo (TBR, OTR). Satış kanalları: perakende, e-ticaret, filo, toptan. Bölge: Kocaeli/Marmara. Markalar SAP verisinden gelir (Petlas, Lassa, Michelin, Continental, Brisa vb.).')
 WHERE id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND NOT (COALESCE(config_json,'{}'::jsonb) ? 'company_profile');

-- === DOGRULAMA (helper'lar dogru donuyor mu + config yerinde mi) ===
\echo '=== helper + config dogrulama (ikisi de LASTIK% / lastik toptancisi olmali) ==='
SELECT name,
       evren_desen(id) AS desen,
       evren_tanim(id) AS is_tanimi,
       (config_json ? 'company_profile') AS profil_var,
       left(config_json->>'company_profile',48) AS profil_bas
  FROM platform_tenants ORDER BY name;

-- === FINGERPRINT ===
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_EVREN_FOUNDATION_V1',
       'Per-tenant is-evreni config + STABLE helper: evren_desen()/evren_tanim(); KRB company_profile backfill',
       'Faz C temeli: LASTIK% ve "lastik toptancisi" literallerini per-tenant config''e baglamak icin altyapi (sifir davranis degisikligi)',
       '{"fonksiyon":["evren_desen(uuid/text)","evren_tanim(uuid/text)"],"config_key":["evren_desen","is_tanimi","company_profile"],"varsayilan":"LASTIK%","not":"henuz cagrilmiyor; KRB davranisi degismedi"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_EVREN_FOUNDATION_V1');

\echo '=== DEPLOY 1 SONU (davranis degismedi) ==='
