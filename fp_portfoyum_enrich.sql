-- FINGERPRINT — PORTFOYUM_ENRICH_V1 (endpoint) + PORTFOYUM_ROOM_V2 (client)
-- Tam-SKU ürün karması + çapraz-satış + aylık trend + ERP eşleşmeyen. Idempotent.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOYUM_ENRICH_V1',
       '/api/saha/portfoyum zenginleştirme: müşteri başına tam-SKU ürün karması (kalem_tanimi, AB-etiketi kırpılmış), top-level aylık trend (36 ay), ERP eşleşmeyen listesi',
       'Rep ne aldığını/benzer dükkânların aldığını tam ürün (315/80R22.5 Lassa E5500) düzeyinde görmeli; trend + ERP nudge tamamlıyor',
       '{"uc":"/api/saha/portfoyum","alanlar":["musteri.ebatlar(kalem_kodu/kalem_tanimi)","trend[]","eslesmeyen[]"],"saf_sql":true,"marker":"PORTFOYUM_ENRICH_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_ENRICH_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOYUM_ROOM_V2',
       'Portföyüm client görünümü v2: tam-SKU ürün karması + çapraz-satış (cosine lookalike) accordion + aylık ciro trend grafiği',
       'Endpoint zenginleştirmesini (ENRICH_V1) rep ekranında gösterir',
       '{"dosya":"shells/saha.js","view":"vPortfoyum","ekler":["ürün çapraz-satış accordion","aylık trend svg","tam-SKU kart karması"],"marker":"PORTFOYUM_ROOM_V2"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_ROOM_V2');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim IN ('PORTFOYUM_ENRICH_V1','PORTFOYUM_ROOM_V2') ORDER BY adim;
