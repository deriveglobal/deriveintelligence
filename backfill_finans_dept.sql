-- ============================================================================
-- backfill_finans_dept.sql — FINANS_DEPT_BACKFILL_V1
-- 'finansodasi' dept'ini MEVCUT intelligence manager+admin kullanicilarina ekler,
--   boylece gating acildiginda kimse Finans Odasi'ni KAYBETMEZ (yalnizca EKLER, silmez).
-- Admin sunucuda requireBiDept ile zaten bypass; ama bi.js dept'e bakip sekmeyi gosterdigi
--   icin admin'in departments'ine de eklemek CLIENT gorunurlugu icin sart.
-- Idempotent (@> kontrolu). KRB tenant tek; genel calisir.
-- Calistir (Fatih, Hetzner'da, DEPLOY DOGRULANDIKTAN SONRA):
--   docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform \
--     < backfill_finans_dept.sql
-- ============================================================================

BEGIN;

-- Once kimler etkilenecek (gorunur log):
SELECT tu_mod.user_id, tu_mod.module_role,
       COALESCE(tu_mod.permissions_json->'departments','[]'::jsonb) AS mevcut_departments
FROM tenant_user_modules tu_mod
WHERE tu_mod.module_id = 'intelligence'
  AND tu_mod.module_role IN ('manager','admin')
  AND tu_mod.active = true
  AND NOT COALESCE(tu_mod.permissions_json->'departments','[]'::jsonb) @> '["finansodasi"]'::jsonb;

UPDATE tenant_user_modules
SET permissions_json = jsonb_set(
      COALESCE(permissions_json, '{}'::jsonb),
      '{departments}',
      COALESCE(permissions_json->'departments', '[]'::jsonb) || '["finansodasi"]'::jsonb
    ),
    updated_at = now()
WHERE module_id = 'intelligence'
  AND module_role IN ('manager','admin')
  AND active = true
  AND NOT COALESCE(permissions_json->'departments','[]'::jsonb) @> '["finansodasi"]'::jsonb;

COMMIT;

-- Dogrulama: artik hepsinde finansodasi olmali
SELECT module_role, count(*) AS finansodasi_olan
FROM tenant_user_modules
WHERE module_id='intelligence' AND active=true
  AND COALESCE(permissions_json->'departments','[]'::jsonb) @> '["finansodasi"]'::jsonb
GROUP BY module_role ORDER BY module_role;
