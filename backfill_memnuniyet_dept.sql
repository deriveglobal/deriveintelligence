-- backfill_memnuniyet_dept.sql — MEMNUNIYET_DEPT_BACKFILL_V1
-- Mevcut saha manager+admin kullanicilarina departments[] += "memnuniyet" (deploy ONCESI).
-- admin _enforceSahaDept'te zaten bypass; manager gating acilinca nabiz-ozet'i kaybetmesin.
-- Yalnizca EKLER (idempotent @>). Calistir (Fatih, DEPLOY ONCESI):
--   docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < backfill_memnuniyet_dept.sql
BEGIN;
SELECT user_id, module_role, COALESCE(permissions_json->'departments','[]'::jsonb) AS mevcut
FROM tenant_user_modules
WHERE module_id='saha' AND module_role IN ('manager','admin') AND active=true
  AND NOT COALESCE(permissions_json->'departments','[]'::jsonb) @> '["memnuniyet"]'::jsonb;

UPDATE tenant_user_modules
SET permissions_json = jsonb_set(COALESCE(permissions_json,'{}'::jsonb),'{departments}',
      COALESCE(permissions_json->'departments','[]'::jsonb) || '["memnuniyet"]'::jsonb),
    updated_at = now()
WHERE module_id='saha' AND module_role IN ('manager','admin') AND active=true
  AND NOT COALESCE(permissions_json->'departments','[]'::jsonb) @> '["memnuniyet"]'::jsonb;
COMMIT;

SELECT module_role, count(*) AS memnuniyet_olan
FROM tenant_user_modules
WHERE module_id='saha' AND active=true
  AND COALESCE(permissions_json->'departments','[]'::jsonb) @> '["memnuniyet"]'::jsonb
GROUP BY module_role ORDER BY module_role;
