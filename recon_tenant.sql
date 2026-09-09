-- =====================================================================
-- Derive/KRB  ·  TENANT KICK-OFF RECON  ·  READ-ONLY  (marker: TENANT_KICKOFF_RECON_V1)
-- Amac: yeni-tenant provisioner + demo-veri tohumu + QA harness'ini GERCEK
--       semaya gore yazabilmek. Hicbir sey YAZMAZ (yalniz SELECT/bilgi_semasi).
-- Calistir (Fatih, sunucuda /opt/krb-assessment icinde):
--   docker compose exec -T postgres psql -U assessment_app -d assessment_platform \
--     -v ON_ERROR_STOP=0 < recon_tenant.sql > recon_out.txt 2>&1
-- Sonra recon_out.txt'i bana geri ver (yapistir ya da klasore koy).
-- =====================================================================
\set ON_ERROR_STOP 0
\pset pager off
\pset footer off
\timing off
\set krb 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

\echo ''
\echo '################ SECTION A — TABLE INVENTORY (ad + tahmini satir) ################'
SELECT relname AS table_name, n_live_tup AS approx_rows
FROM pg_stat_user_tables
ORDER BY relname;

\echo ''
\echo '################ SECTION B — COLUMN DEFINITIONS ################'
\echo '# platform_*, tenant_*, users/user_invitations + kurate BI/saha tablolari'
SELECT table_name, ordinal_position AS pos, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public'
  AND (
        table_name LIKE 'platform_%'
     OR table_name LIKE 'tenant_%'
     OR table_name IN (
        'users','user_invitations','plans','modules','subscriptions',
        'bi_satis_faturalari','bi_marj_atom','bi_marj_fact','bi_metrik_gecmis','bi_musteri_risk',
        'bi_stok_durumu','bi_tedarikci_faturalari','bi_tahsilat','bi_tahsilat_fact',
        'bi_sinyal_aday','bi_icgoru','bi_yetenek','bi_insa_gunlugu',
        'saha_musteri','saha_ziyaret','saha_rep_not','saha_rep_ozellik','saha_rep_gelisim',
        'saha_rota_log','saha_teklif','rep_kimlik_koprusu','sap_musteri_sahiplik'
     )
  )
ORDER BY table_name, ordinal_position;

\echo ''
\echo '################ SECTION C — NOT NULL, DEFAULTSIZ kolonlar (seed zorunlu alanlari) ################'
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='public'
  AND is_nullable='NO' AND column_default IS NULL
  AND (table_name LIKE 'platform_%' OR table_name LIKE 'tenant_%'
       OR table_name IN ('users','user_invitations',
        'bi_satis_faturalari','bi_marj_atom','bi_marj_fact','bi_metrik_gecmis','bi_musteri_risk',
        'bi_stok_durumu','bi_tedarikci_faturalari','bi_tahsilat','saha_musteri','saha_ziyaret',
        'saha_rep_not','rep_kimlik_koprusu','sap_musteri_sahiplik'))
ORDER BY table_name, column_name;

\echo ''
\echo '################ SECTION D — MEVCUT TENANTLAR ################'
SELECT id, name, slug, timezone, currency,
       (config_json ? 'alias')           AS has_alias,
       (config_json ? 'company_profile') AS has_profile,
       left(config_json::text, 300)       AS config_preview
FROM platform_tenants
ORDER BY name;

\echo ''
\echo '################ SECTION E — ABONELIK / PLAN / MODUL tablolari (spekulatif, yoksa hata verip devam) ################'
\echo '# --- platform_subscriptions'
SELECT * FROM platform_subscriptions LIMIT 30;
\echo '# --- platform_plans'
SELECT * FROM platform_plans LIMIT 30;
\echo '# --- platform_modules'
SELECT * FROM platform_modules LIMIT 30;
\echo '# --- tenant_subscriptions'
SELECT * FROM tenant_subscriptions LIMIT 30;
\echo '# --- subscriptions'
SELECT * FROM subscriptions LIMIT 30;
\echo '# --- plans'
SELECT * FROM plans LIMIT 30;
\echo '# --- modules'
SELECT * FROM modules LIMIT 30;
\echo '# --- distinct module_id gorunen yerler'
SELECT DISTINCT module_id FROM tenant_user_modules ORDER BY 1;

\echo ''
\echo '################ SECTION F — KRB kullanici/rol kablolamasi (demo admin sablonu) ################'
SELECT tu.tenant_id, tu.user_id, tu.tenant_role, u.email
FROM tenant_users tu JOIN users u ON u.id = tu.user_id
WHERE tu.tenant_id::text = :'krb'
ORDER BY tu.tenant_role;

\echo '# --- tenant_user_modules (KRB) ornek'
SELECT tenant_id, user_id, module_id, module_role, permissions_json
FROM tenant_user_modules
WHERE tenant_id::text = :'krb'
LIMIT 40;

\echo '# --- users tablosu: auth kolon adlari (1 ornek, sifre HASH gizli degil-onemli degil ama yine de kirp)'
SELECT id, email,
       (SELECT string_agg(column_name, ', ') FROM information_schema.columns
         WHERE table_schema='public' AND table_name='users') AS users_columns
FROM users
WHERE id IN (SELECT user_id FROM tenant_users WHERE tenant_id::text = :'krb')
LIMIT 1;

\echo ''
\echo '################ SECTION G — KRB VERI HACMI + TARIH ARALIGI (demo hacmini gercekci olcmek icin) ################'
SELECT 'bi_satis_faturalari' AS tbl, count(*) AS n FROM bi_satis_faturalari WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'bi_marj_atom',          count(*) FROM bi_marj_atom          WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'bi_marj_fact',          count(*) FROM bi_marj_fact          WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'bi_metrik_gecmis',      count(*) FROM bi_metrik_gecmis      WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'bi_musteri_risk',       count(*) FROM bi_musteri_risk       WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'bi_stok_durumu',        count(*) FROM bi_stok_durumu        WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'bi_tedarikci_faturalari',count(*) FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'bi_tahsilat',           count(*) FROM bi_tahsilat           WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'saha_musteri',          count(*) FROM saha_musteri          WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'saha_ziyaret',          count(*) FROM saha_ziyaret          WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'saha_rep_not',          count(*) FROM saha_rep_not          WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'rep_kimlik_koprusu',    count(*) FROM rep_kimlik_koprusu    WHERE tenant_id::text=:'krb'
UNION ALL SELECT 'sap_musteri_sahiplik',  count(*) FROM sap_musteri_sahiplik  WHERE tenant_id::text=:'krb'
ORDER BY tbl;

\echo ''
\echo '################ SECTION H — ORNEK SATIRLAR (deger sekli/format; demo verisini gercekci kurmak icin) ################'
\echo '# bi_satis_faturalari (2 satir)'
SELECT * FROM bi_satis_faturalari WHERE tenant_id::text=:'krb' LIMIT 2;
\echo '# bi_marj_atom (2 satir)'
SELECT * FROM bi_marj_atom WHERE tenant_id::text=:'krb' LIMIT 2;
\echo '# bi_musteri_risk (2 satir)'
SELECT * FROM bi_musteri_risk WHERE tenant_id::text=:'krb' LIMIT 2;
\echo '# bi_metrik_gecmis (3 satir)'
SELECT * FROM bi_metrik_gecmis WHERE tenant_id::text=:'krb' LIMIT 3;
\echo '# bi_tahsilat (2 satir)'
SELECT * FROM bi_tahsilat WHERE tenant_id::text=:'krb' LIMIT 2;
\echo '# bi_stok_durumu (2 satir)'
SELECT * FROM bi_stok_durumu WHERE tenant_id::text=:'krb' LIMIT 2;
\echo '# saha_musteri (2 satir)'
SELECT * FROM saha_musteri WHERE tenant_id::text=:'krb' LIMIT 2;
\echo '# saha_ziyaret (2 satir)'
SELECT * FROM saha_ziyaret WHERE tenant_id::text=:'krb' LIMIT 2;
\echo '# rep_kimlik_koprusu (3 satir)'
SELECT * FROM rep_kimlik_koprusu WHERE tenant_id::text=:'krb' LIMIT 3;
\echo '# sap_musteri_sahiplik (2 satir)'
SELECT * FROM sap_musteri_sahiplik WHERE tenant_id::text=:'krb' LIMIT 2;

\echo ''
\echo '################ SECTION I — company_profile / kimlik prompt izleri (KRB sizinti denetimi icin) ################'
\echo '# KRB config_json.company_profile var mi, uzunlugu ne'
SELECT slug, (config_json ? 'company_profile') AS has_profile,
       length(coalesce(config_json->>'company_profile','')) AS profile_len,
       coalesce(config_json->>'alias','(bos)') AS alias
FROM platform_tenants ORDER BY slug;

\echo ''
\echo '################ RECON SONU — recon_out.txt olarak geri gonder ################'
