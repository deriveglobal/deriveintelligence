-- ============ HARİTA FAZ 1 (yeni tasarım) fingerprint — idempotent ============
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'HARITA_ILSAHA_V1','Harita: il basina musteri/ziyaret/kapsam ucu','Firsat Indeksi + Kapsam Acigi mercekleri icin il-bazli saha verisi gerekiyordu.','{"marker":"HARITA_ILSAHA_V1","uc":["/api/saha/harita-il-saha"],"cap":["harita"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='HARITA_ILSAHA_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'HARITA_YENI_V1','Harita yeniden tasarim (saha.js rpHarita SECTION 1): Leaflet choropleth + mercekler (Firsat/Kapsam) + Metrikler (segment x metrik) + hassas pin + ⓘ kilavuz + donem secici + kesirli-zoom fit; mobil-oncelikli responsive. Saha Sesi (SECTION 2) dokunulmadi.','Eski harita cekici degildi, il sinirlari belirsizdi, renklendirme bozuktu (client regresyon). Fatih: cok daha yaratici/gorsel.','{"marker":"HARITA_YENI_V1","shell":["saha.js"],"uc":["/api/saha/tr-geo","/api/saha/harita-il-metrikler","/api/saha/harita-il-saha","/api/saha/harita-musteriler"],"not":"masaustu (saha_desktop.js) paritesi Faz1b; Rakip/Sahanin Sesi mercekleri Faz3"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='HARITA_YENI_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'HARITA_GEO_BAKE_V1','Dockerfile: COPY tr-cities.json ./tr-cities.json — il geojson imaja gomuldu','KOK NEDEN: /api/saha/tr-geo /app/tr-cities.json okuyor ama dosya imajda yoktu + compose mount calismiyordu -> tr-geo 404 -> harita bos. Ayni zamanda ESKI renklendirmenin de kok nedeniydi. Artik mount-bagimsiz.','{"marker":"HARITA_GEO_BAKE_V1","dosya":"Dockerfile","yol":"/app/tr-cities.json (~241KB)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='HARITA_GEO_BAKE_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT '/api/saha/harita-il-saha','uc',
 'Harita mercekleri icin il-bazli saha agregati: musteri (tum/tuketici/ticari), donem ziyaret sayisi, ziyaret edilen musteri, kapsam_pct. Firsat Indeksi + Kapsam Acigi bunu kullanir.',
 'GET /api/saha/harita-il-saha?from=&to=&tip= — cap ["harita"]; manager/admin.',
 'saha','canli','taslak',
 '{"marker":"HARITA_ILSAHA_V1","kaynak":["saha_musteri","saha_ziyaret"]}'::jsonb, true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='/api/saha/harita-il-saha');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim IN ('HARITA_ILSAHA_V1','HARITA_YENI_V1','HARITA_GEO_BAKE_V1') ORDER BY adim;
SELECT ad, tur, durum FROM bi_yetenek WHERE ad='/api/saha/harita-il-saha';
