-- Derive · SAHA VERI-DEGER RECON (SALT-OKUNUR) — data seed'i KRB semantigiyle
-- birebir kurmak icin NOT NULL kolonlar + gercek ornek satirlar + skor kaynagi.
\pset pager off
SELECT id AS kid FROM platform_tenants WHERE name ILIKE '%kardes%' OR name ILIKE '%rot balans%' LIMIT 1; \gset

\echo '=== saha_musteri: NOT NULL kolonlar (seed bunlari doldurmali) ==='
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='saha_musteri' AND is_nullable='NO' ORDER BY ordinal_position;
\echo '--- KRB saha_musteri ornek 3 satir (tip/segment/durum/kaynak gercek degerleri) ---'
SELECT tip, segment, durum, kayit_kaynagi, il, aktif FROM saha_musteri WHERE tenant_id=:'kid' LIMIT 3;
\echo '--- tip / segment / durum / kayit_kaynagi dagilimi (gecerli deger kumeleri) ---'
SELECT 'tip' k, coalesce(tip,'∅') v, count(*) FROM saha_musteri WHERE tenant_id=:'kid' GROUP BY tip
UNION ALL SELECT 'segment', coalesce(segment,'∅'), count(*) FROM saha_musteri WHERE tenant_id=:'kid' GROUP BY segment
UNION ALL SELECT 'durum', coalesce(durum,'∅'), count(*) FROM saha_musteri WHERE tenant_id=:'kid' GROUP BY durum
UNION ALL SELECT 'kayit_kaynagi', coalesce(kayit_kaynagi,'∅'), count(*) FROM saha_musteri WHERE tenant_id=:'kid' GROUP BY kayit_kaynagi
ORDER BY 1,3 DESC;

\echo ''
\echo '=== saha_ziyaret: NOT NULL kolonlar + KRB ornek ==='
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='saha_ziyaret' AND is_nullable='NO' ORDER BY ordinal_position;
SELECT tip, durum, kaynak, (ziyaret_tarihi IS NOT NULL) zt_var, (planlanan_tarih IS NOT NULL) pt_var FROM saha_ziyaret WHERE tenant_id=:'kid' LIMIT 3;
SELECT 'tip' k, coalesce(tip,'∅') v, count(*) FROM saha_ziyaret WHERE tenant_id=:'kid' GROUP BY tip
UNION ALL SELECT 'durum', coalesce(durum,'∅'), count(*) FROM saha_ziyaret WHERE tenant_id=:'kid' GROUP BY durum
UNION ALL SELECT 'kaynak', coalesce(kaynak,'∅'), count(*) FROM saha_ziyaret WHERE tenant_id=:'kid' GROUP BY kaynak
ORDER BY 1,3 DESC;

\echo ''
\echo '=== sap_musteri_sahiplik: NOT NULL kolonlar ==='
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='sap_musteri_sahiplik' AND is_nullable='NO' ORDER BY ordinal_position;

\echo ''
\echo '=== saha_satis_skor: NASIL uretiliyor (fonksiyon mu, cron mu)? ==='
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='saha_satis_skor' ORDER BY ordinal_position;
SELECT proname FROM pg_proc WHERE proname ILIKE '%satis_skor%' OR proname ILIKE '%portfoy%skor%' OR proname ILIKE '%saha%skor%';
\echo '--- KRB saha_satis_skor satir sayisi (referans) ---'
SELECT count(*) FROM saha_satis_skor WHERE tenant_id=:'kid';

\echo ''
\echo '=== ANADOLU musteri->rep eslesme kaynagi (satis_temsilcisi bazinda musteri) ==='
SELECT satis_temsilcisi, count(DISTINCT musteri_kodu) musteri, count(DISTINCT musteri_adi) FILTER (WHERE coalesce(musteri_adi,'')<>'') adli
FROM bi_satis_faturalari WHERE tenant_id='42822870-4ea3-424d-a16f-50b91afca32c' AND coalesce(satis_temsilcisi,'')<>''
GROUP BY 1 ORDER BY 2 DESC;
\echo '--- ANADOLU musteri ornek (firma/sehir kolon adlari) ---'
SELECT musteri_kodu, musteri_adi, sehir, satis_kanali, satis_temsilcisi FROM bi_satis_faturalari
WHERE tenant_id='42822870-4ea3-424d-a16f-50b91afca32c' AND coalesce(musteri_kodu,'')<>'' LIMIT 5;

\echo ''
\echo '=== RECON SONU (yazma yok) ==='
