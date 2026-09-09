-- SAHA_DEPT_BACKFILL_APPLY — role'den departments[] doldur (YALNIZ bos olanlar).
--   saha_tip (segment) ve diger permissions_json anahtarlari KORUNUR. Idempotent.
BEGIN;

WITH defaults(role, depts) AS (
  VALUES
    ('rep',     ARRAY['bugun','ziyaretler','plan','musteriler','musterikart','ebatkart','iskonto','notlarim','rep-brain','harita','duyurular','mesajlar','oneriler']),
    ('manager', ARRAY['bugun','ziyaretler','plan','musteriler','musterikart','ebatkart','iskonto','notlarim','rep-brain','harita','piyasa','rakip','oneriler','rapor','kokpit','ceo','rep-aktivite','duyurular','mesajlar']),
    ('admin',   ARRAY['bugun','ziyaretler','plan','musteriler','musterikart','ebatkart','iskonto','notlarim','rep-brain','harita','piyasa','rakip','oneriler','rapor','kokpit','ceo','rep-aktivite','duyurular','mesajlar','temsilciler','sistem'])
)
UPDATE tenant_user_modules tum
SET permissions_json = jsonb_set(COALESCE(tum.permissions_json, '{}'::jsonb), '{departments}', to_jsonb(d.depts)),
    updated_at = now()
FROM defaults d
WHERE tum.module_id = 'saha'
  AND d.role = tum.module_role
  AND COALESCE(jsonb_array_length(tum.permissions_json->'departments'), 0) = 0;

-- dogrulama: yazildiktan sonraki durum
SELECT u.email, tum.module_role AS rol,
       jsonb_array_length(tum.permissions_json->'departments') AS dept_sayi,
       tum.permissions_json->>'saha_tip' AS segment
FROM tenant_user_modules tum
JOIN users u ON u.id = tum.user_id
WHERE tum.module_id = 'saha'
ORDER BY tum.module_role, u.email;

COMMIT;
