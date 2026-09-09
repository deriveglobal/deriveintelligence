-- SAHA_DEPT_BACKFILL_V2 — DUZELTME. Set'ler her rolun IKI shell'de (desktop+mobil)
--   gorunen araclarinin BIRLESIMI olacak sekilde duzeltildi (additive gating icin neutral).
--   ebatkart/musterikart HARIC (araclar grant'i ile yonetilir). saha_tip KORUNUR.
--   Not: manuel matris duzenlemesi henuz yok -> guvenli overwrite.
BEGIN;

WITH defaults(role, depts) AS (
  VALUES
    ('rep',     ARRAY['bugun','ziyaretler','plan','musteriler','teklif','notlarim','rep-brain','piyasa','rakip','rapor','duyurular','mesajlar','oneriler']),
    ('manager', ARRAY['bugun','ziyaretler','plan','musteriler','teklif','notlarim','rep-brain','piyasa','rakip','rapor','duyurular','mesajlar','oneriler','harita','kokpit','ceo']),
    ('admin',   ARRAY['bugun','ziyaretler','plan','musteriler','teklif','notlarim','rep-brain','piyasa','rakip','rapor','duyurular','mesajlar','oneriler','harita','kokpit','ceo','rep-aktivite','sistem','temsilciler'])
)
UPDATE tenant_user_modules tum
SET permissions_json = jsonb_set(COALESCE(tum.permissions_json, '{}'::jsonb), '{departments}', to_jsonb(d.depts)),
    updated_at = now()
FROM defaults d
WHERE tum.module_id = 'saha' AND d.role = tum.module_role;

SELECT u.email, tum.module_role AS rol,
       jsonb_array_length(tum.permissions_json->'departments') AS dept_sayi,
       tum.permissions_json->>'saha_tip' AS segment
FROM tenant_user_modules tum JOIN users u ON u.id = tum.user_id
WHERE tum.module_id = 'saha' ORDER BY tum.module_role, u.email;

COMMIT;
