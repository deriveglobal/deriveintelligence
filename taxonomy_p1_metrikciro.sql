-- ============================================================
-- Derive · AGNOSTİK — TAKSONOMI 1/2: metrik_ciro cekirdek-is filtresi config'e.
-- 'ebat IS NOT NULL' (lastik proxy) -> evren_cekirdek(tenant): 'ebat'(default) | 'grup'.
-- KRB config yok -> 'ebat' -> predikat AYNI -> ciro_lastik BIREBIR (SQL indirgemesi).
-- Programatik (canli tanim al, guard, yeniden yarat).
-- ============================================================
\pset pager off

-- helper: cekirdek-is filtre modu (default 'ebat' = KRB mevcut)
CREATE OR REPLACE FUNCTION evren_cekirdek(p_tenant uuid) RETURNS text
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE(NULLIF((SELECT config_json->>'cekirdek_filtre' FROM platform_tenants WHERE id=p_tenant),''),'ebat')
$$;

-- KRB ONCE: metrik_ciro son kapali ay ciro_lastik (kiyas icin)
CREATE TEMP TABLE _mc_before AS
  SELECT metrik_ciro('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid,
                     date_trunc('month',CURRENT_DATE)::date - interval '1 month', true) AS v;

DO $mig$
DECLARE d text; oldp text; newp text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO d FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='metrik_ciro';
  oldp := 'AND (NOT p_lastik_only OR ebat IS NOT NULL)';
  newp := 'AND (NOT p_lastik_only OR CASE WHEN evren_cekirdek(p_tenant)=''grup'' THEN grup_adi LIKE evren_desen(p_tenant) ELSE ebat IS NOT NULL END)';
  IF position(oldp IN d)=0 THEN RAISE EXCEPTION 'ANCHOR YOK: metrik_ciro filtre'; END IF;
  EXECUTE replace(d, oldp, newp);
  RAISE NOTICE 'metrik_ciro cekirdek-is filtresi config-driven.';
END $mig$;

-- KRB SONRA + esdeger
CREATE TEMP TABLE _mc_after AS
  SELECT metrik_ciro('f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid,
                     date_trunc('month',CURRENT_DATE)::date - interval '1 month', true) AS v;

\echo '=== KRB metrik_ciro(lastik) ONCE vs SONRA (esit olmali) ==='
SELECT (SELECT v FROM _mc_before) AS once, (SELECT v FROM _mc_after) AS sonra,
       ((SELECT v FROM _mc_before) IS NOT DISTINCT FROM (SELECT v FROM _mc_after)) AS esdeger;

\echo '=== evren_cekirdek dogrulama (KRB=ebat) ==='
SELECT name, evren_cekirdek(id) FROM platform_tenants ORDER BY name;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_TAKSONOMI_CIRO_V1',
       'metrik_ciro cekirdek-is filtresi (ebat IS NOT NULL) -> evren_cekirdek(tenant): ebat|grup',
       'Non-tire tenant ebat''siz -> ciro_lastik bos kalirdi. Config default ebat -> KRB predikat AYNI (esdeger kanitli).',
       '{"fonksiyon":"metrik_ciro","helper":"evren_cekirdek","default":"ebat","KRB":"birebir"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_TAKSONOMI_CIRO_V1');
\echo '=== TAKSONOMI 1/2 SONU ==='
