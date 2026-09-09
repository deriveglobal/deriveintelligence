-- Üyeler ucunun SQL'i Satış için birebir çalışıyor mu?
\echo '--- satis dept id ---'
SELECT id, key, ad FROM tenant_department WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND key='satis';

\echo '--- members sorgusu (endpoint ile birebir) ---'
SELECT u.id::text id, COALESCE(u.full_name,u.email,'—') ad, u.email,
       EXISTS(SELECT 1 FROM tenant_department_membership m
              WHERE m.department_id=(SELECT id FROM tenant_department WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND key='satis')
                AND m.user_id=u.id) uye
  FROM users u
 WHERE u.id IN (SELECT user_id FROM tenant_user_modules WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa')
 ORDER BY uye DESC, ad
 LIMIT 20;

\echo '--- saha modullu kac kullanici var (liste bos mu?) ---'
SELECT count(*) saha_kullanici FROM tenant_user_modules WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND module_id='saha';
