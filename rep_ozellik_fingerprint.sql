-- ============================================================
-- Derive · ANADOLU rep-karakter motoru tetikle + SAHA milestone fingerprint
-- hesapla_rep_ozellik(+ek/+ek2) Anadolu icin -> saha_rep_ozellik doldurur.
-- Sonra bi_insa_gunlugu (idempotent) saha seed + rep-login kaydi.
-- ============================================================
\pset pager off
SELECT id AS aid FROM platform_tenants WHERE name ILIKE '%anadolu%' LIMIT 1; \gset
\echo '>>> ANADOLU =' :'aid'

\echo '=== 1. rep karakter ozellikleri hesapla (3 aile fonksiyonu) ==='
SELECT 'hesapla_rep_ozellik='     ||coalesce(hesapla_rep_ozellik(:'aid'::uuid, CURRENT_DATE)::text,'void');
SELECT 'hesapla_rep_ozellik_ek='  ||coalesce(hesapla_rep_ozellik_ek(:'aid'::uuid, CURRENT_DATE)::text,'void');
SELECT 'hesapla_rep_ozellik_ek2=' ||coalesce(hesapla_rep_ozellik_ek2(:'aid'::uuid, CURRENT_DATE)::text,'void');

\echo '=== 2. saha_rep_ozellik sonuc (rep basina kac ozellik + kapsam) ==='
SELECT (SELECT sap_temsilci FROM rep_kimlik_koprusu k WHERE k.tenant_id::text=:'aid' AND k.user_id=o.user_id LIMIT 1) rep,
       count(*) ozellik, count(DISTINCT alan) aile, round(avg(kapsam),2) ort_kapsam
FROM saha_rep_ozellik o WHERE o.tenant_id::text=:'aid' GROUP BY o.user_id ORDER BY 2 DESC;
SELECT 'ANADOLU saha_rep_ozellik toplam' t, count(*) n FROM saha_rep_ozellik WHERE tenant_id::text=:'aid';

\echo '=== 3. FINGERPRINT (idempotent) ==='
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'ANADOLU_REP_LOGIN_V1',
       'Anadolu 6 saha rep login (users->tenant_users->tenant_user_modules saha:rep->rep_kimlik_koprusu), app hashPassword (scrypt) ile',
       'Demo tenant saha modulu icin rep-facing giris; yetki YAPISI degismedi, provisioner admin kalibiyla veri eklendi',
       '{"repler":["Emre Sahin","Burak Ozturk","Mehmet Aydin","Ayse Kaya","Can Yilmaz","Zeynep Demir"],"domain":"anadolu-demo.com","yol":"provision_reps.mjs (container node)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='ANADOLU_REP_LOGIN_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'ANADOLU_SAHA_SEED_V1',
       'Anadolu saha veri seed: 48 musteri->6 rep (dominant satis_temsilcisi), sap_musteri_sahiplik 48, saha_ziyaret 144, saha_satis_skor 48 (gercek scorer)',
       'Demo tenant saha modulu ucdan uca; yonetici/CEO saha yuzeyleri + rep karakter motoru icin veri zemini',
       '{"saha_musteri":48,"sahiplik":48,"ziyaret":144,"satis_skor":48,"izolasyon":{"KRB_saha_musteri":1687},"kaynak":"bi_satis_faturalari+rep_kimlik_koprusu"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='ANADOLU_SAHA_SEED_V1');

SELECT adim, ts::date, ne FROM bi_insa_gunlugu ORDER BY ts DESC LIMIT 4;
\echo '=== BITTI ==='
