-- diag_saha_onboarding.sql — READ-ONLY. Mevcut 2 rep'in kurulumunu ortaya cikarir.
-- Yeni 4 rep'i AYNEN onlar gibi kurmak icin sema + veri durumu. Hicbir sey yazmaz.
\set ON_ERROR_STOP off
\pset pager off
\echo '==================== 1) ILGILI TABLOLAR ===================='
SELECT table_name FROM information_schema.tables
 WHERE table_schema='public'
   AND (table_name ILIKE '%saha%' OR table_name ILIKE '%ziyaret%'
        OR table_name ILIKE '%musteri%' OR table_name ILIKE '%kullan%'
        OR table_name ILIKE '%user%' OR table_name ILIKE '%rep%')
 ORDER BY table_name;

\echo '==================== 2) saha_ziyaret KOLONLARI ===================='
SELECT column_name, data_type, is_nullable, column_default
 FROM information_schema.columns
 WHERE table_schema='public' AND table_name='saha_ziyaret' ORDER BY ordinal_position;

\echo '==================== 3) saha_musteri KOLONLARI ===================='
SELECT column_name, data_type, is_nullable
 FROM information_schema.columns
 WHERE table_schema='public' AND table_name='saha_musteri' ORDER BY ordinal_position;

\echo '==================== 4) master_musteri KOLONLARI ===================='
SELECT column_name, data_type
 FROM information_schema.columns
 WHERE table_schema='public' AND table_name='master_musteri' ORDER BY ordinal_position;

\echo '==================== 5) KULLANICI/REP TABLOSU KOLONLARI (aday adlar) ===================='
SELECT table_name, column_name, data_type
 FROM information_schema.columns
 WHERE table_schema='public'
   AND table_name IN ('users','kullanicilar','saha_kullanici','saha_users','platform_users','app_users')
 ORDER BY table_name, ordinal_position;

\echo '==================== 6) SAHA ROL DAGILIMI (rep kim, hangi tabloda) ===================='
-- olası rol kolonlarını dener; hangisi çalışırsa o
SELECT 'users.module_role' AS kaynak, module_role AS rol, count(*) FROM users GROUP BY module_role;
SELECT 'kullanicilar.module_role' AS kaynak, module_role AS rol, count(*) FROM kullanicilar GROUP BY module_role;
SELECT 'saha_kullanici.rol' AS kaynak, rol, count(*) FROM saha_kullanici GROUP BY rol;

\echo '==================== 7) TENANT + REP LISTESI (id, ad, rol, olusturma) ===================='
SELECT id, full_name, email, module_role, tenant_id, created_at
 FROM users WHERE module_role IS NOT NULL ORDER BY created_at NULLS LAST;
-- alternatif tablo
SELECT id, full_name, email, module_role, tenant_id, created_at
 FROM kullanicilar WHERE module_role IS NOT NULL ORDER BY created_at NULLS LAST;

\echo '==================== 8) ZIYARET DURUMU: rep basina say/durum/tarih araligi ===================='
SELECT rep_id,
       count(*) AS ziyaret,
       count(*) FILTER (WHERE durum='TAMAMLANDI') AS tamamlandi,
       count(*) FILTER (WHERE durum='PLANLANDI')  AS planlandi,
       min(ziyaret_tarihi)  AS ilk_ziyaret,
       max(ziyaret_tarihi)  AS son_ziyaret,
       min(planlanan_tarih) AS ilk_plan,
       max(planlanan_tarih) AS son_plan
 FROM saha_ziyaret GROUP BY rep_id ORDER BY ziyaret DESC;

\echo '==================== 9) TIP DAGILIMI + created_by (nasil yuklendi ipucu) ===================='
SELECT tip, durum, count(*) FROM saha_ziyaret GROUP BY tip, durum ORDER BY count DESC;
SELECT rep_id, created_by, count(*) FROM saha_ziyaret GROUP BY rep_id, created_by ORDER BY count DESC LIMIT 20;

\echo '==================== 10) ORNEK ZIYARET SATIRLARI (tam alanlar) ===================='
SELECT * FROM saha_ziyaret ORDER BY id DESC LIMIT 3;

\echo '==================== 11) saha_musteri: rep basina + master baglantisi ===================='
SELECT count(*) AS toplam_saha_musteri FROM saha_musteri;
SELECT * FROM saha_musteri ORDER BY id DESC LIMIT 3;

\echo '==================== 12) master_musteri boyut + ornek ===================='
SELECT count(*) AS master_musteri_adet FROM master_musteri;
SELECT musteri_kodu, musteri_adi, sehir, satis_kanali, vergi_no FROM master_musteri LIMIT 5;
\echo '==================== BITTI ===================='
