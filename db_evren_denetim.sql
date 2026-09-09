-- DB tarafi is-evreni/tenant hardcode denetimi (SALT-OKUNUR, duzeltilmis sorgular)
\pset pager off
\echo '=== VIEW: taniminda LASTIK gecen (is-evreni hardcode) ==='
SELECT viewname FROM pg_views WHERE schemaname='public' AND definition ILIKE '%LASTIK%' ORDER BY 1;

\echo ''
\echo '=== VIEW: taniminda KRB uuid gecen ==='
SELECT viewname FROM pg_views WHERE schemaname='public' AND definition ILIKE '%f8a5d20f-ecf8-4ce2-a492-69268fbb03fa%' ORDER BY 1;

\echo ''
\echo '=== FONKSIYON: taniminda LASTIK gecen (aggregate haric) ==='
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f' AND pg_get_functiondef(p.oid) ILIKE '%LASTIK%' ORDER BY 1;

\echo ''
\echo '=== FONKSIYON: taniminda KRB uuid gecen ==='
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f' AND pg_get_functiondef(p.oid) ILIKE '%f8a5d20f-ecf8-4ce2-a492-69268fbb03fa%' ORDER BY 1;

\echo ''
\echo '=== FONKSIYON: kategori taksonomisi (PSR/TBR/OTR) gomulu ==='
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prokind='f' AND pg_get_functiondef(p.oid) ~ '\yPSR\y|\yTBR\y|\yOTR\y' ORDER BY 1;

\echo ''
\echo '=== company_profile / evren konfig alani platform_tenants.config_json''da VAR MI? ==='
SELECT id, name, (config_json ? 'company_profile') has_profile,
       (config_json ? 'universe') has_universe,
       left(coalesce(config_json->>'company_profile',''),60) profil_bas
FROM platform_tenants ORDER BY name;

\echo ''
\echo '=== DENETIM SONU ==='
