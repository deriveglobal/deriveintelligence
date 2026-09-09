-- LOGOUT kök-neden teşhis (READ-ONLY). Ali Kemal uzun ziyarette atılıyor — TTL-expiry mi, revoke mu?
\echo '===== 1) Ali Kemal user ====='
SELECT id, email, name, role FROM users WHERE name ILIKE '%kemal%' OR name ILIKE '%pıçakc%' OR name ILIKE '%picakc%' OR email ILIKE '%kemal%';

\echo '===== 2) Onun module rolleri — admin/manager varsa STAFF 24s sınıflanır (rep 7g yerine) ====='
SELECT tum.user_id, tum.module_role, tum.active, u.name
  FROM tenant_user_modules tum JOIN users u ON u.id=tum.user_id
 WHERE (u.name ILIKE '%kemal%' OR u.email ILIKE '%kemal%');

\echo '===== 3) Son 12 oturumu: TTL ne kadardı, expire mi oldu revoke mu? ====='
SELECT to_char(created_at,'MM-DD HH24:MI') giris,
       to_char(expires_at,'MM-DD HH24:MI') biter,
       round(EXTRACT(EPOCH FROM (expires_at-created_at))/3600) ttl_saat,
       CASE WHEN revoked_at IS NOT NULL THEN 'REVOKE ('||to_char(revoked_at,'MM-DD HH24:MI')||')'
            WHEN expires_at <= now() THEN 'EXPIRED'
            ELSE 'aktif' END durum,
       metadata->>'userAgent' ua
  FROM user_sessions
 WHERE user_id = (SELECT id FROM users WHERE name ILIKE '%kemal%' OR email ILIKE '%kemal%' LIMIT 1)
 ORDER BY created_at DESC LIMIT 12;
