-- SAHA_DEPT_BACKFILL_DRYRUN — P2 hazirligi. DEGISIKLIK YOK (sadece SELECT).
-- Her saha kullanicisi icin: mevcut departments[] vs role'den turetilecek varsayilan set.
-- Amac: nav gating (P2) acilmadan ONCE herkesin dogru alt-arac setine sahip olmasi.
WITH defaults(role, depts) AS (
  VALUES
    ('rep',     ARRAY['bugun','ziyaretler','plan','musteriler','musterikart','ebatkart','iskonto','notlarim','rep-brain','harita','duyurular','mesajlar','oneriler']),
    ('manager', ARRAY['bugun','ziyaretler','plan','musteriler','musterikart','ebatkart','iskonto','notlarim','rep-brain','harita','piyasa','rakip','oneriler','rapor','kokpit','ceo','rep-aktivite','duyurular','mesajlar']),
    ('admin',   ARRAY['bugun','ziyaretler','plan','musteriler','musterikart','ebatkart','iskonto','notlarim','rep-brain','harita','piyasa','rakip','oneriler','rapor','kokpit','ceo','rep-aktivite','duyurular','mesajlar','temsilciler','sistem'])
)
SELECT u.email,
       tum.module_role                                                    AS rol,
       tum.active                                                         AS aktif,
       COALESCE(jsonb_array_length(tum.permissions_json->'departments'),0) AS mevcut_dept_sayi,
       (tum.permissions_json->>'saha_tip')                                AS segment,
       COALESCE(array_length(d.depts,1),0)                               AS yeni_dept_sayi,
       CASE WHEN COALESCE(jsonb_array_length(tum.permissions_json->'departments'),0) > 0
            THEN 'ATLA (zaten dolu)' ELSE 'YAZ' END                       AS aksiyon
FROM tenant_user_modules tum
JOIN users u ON u.id = tum.user_id
LEFT JOIN defaults d ON d.role = tum.module_role
WHERE tum.module_id = 'saha'
ORDER BY tum.module_role, u.email;
