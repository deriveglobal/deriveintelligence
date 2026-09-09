-- diag3_hesaplar.sql — READ-ONLY. 8 rep hesabinin durumu + saha modul baglantisi + saha_tip.
\set ON_ERROR_STOP off
\pset pager off
\echo '==================== HESAPLAR (8 email) ===================='
SELECT u.email::text AS email, u.id, u.full_name, u.role, u.status,
       (u.password_hash IS NOT NULL) AS parola_var, u.password_reset_required AS reset,
       (SELECT count(*) FROM saha_ziyaret z WHERE z.rep_id=u.id) AS ziyaret
 FROM users u
 WHERE u.email::text IN ('eyildiz@krb.com.tr','hbilgi@krb.com.tr','oyilmaz@krb.com.tr',
                         'myener@krb.com.tr','kpicakci@krb.com.tr','akarakaya@krb.com.tr',
                         'uyildiz@krb.com.tr','ybilen@krb.com.tr')
 ORDER BY u.email::text;

\echo '==================== SAHA MODUL ROLU + saha_tip (bu hesaplar) ===================='
SELECT u.email::text AS email, m.module_id, m.module_role, m.permissions_json, m.active
 FROM users u
 JOIN tenant_user_modules m ON m.user_id=u.id
 WHERE u.email::text IN ('oyilmaz@krb.com.tr','myener@krb.com.tr','kpicakci@krb.com.tr','ybilen@krb.com.tr')
 ORDER BY u.email::text, m.module_id;

\echo '==================== TENANT UYELIGI (bu hesaplar) ===================='
SELECT u.email::text AS email, tu.tenant_role, tu.active
 FROM users u JOIN tenant_users tu ON tu.user_id=u.id
 WHERE u.email::text IN ('oyilmaz@krb.com.tr','myener@krb.com.tr','kpicakci@krb.com.tr','ybilen@krb.com.tr')
 ORDER BY u.email::text;
\echo '==================== BITTI ===================='
