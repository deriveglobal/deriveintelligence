-- ============================================================
-- FINGERPRINT — Adım-2 segment motoru: saha_satis_skor + gecelik BG/NBD + endpoint JOIN
-- Idempotent. Fatih çalıştırır (psql). saha_satis_skor.sql DDL'inden SONRA.
-- ============================================================

-- 1) build-log: segment motoru (tablo + gecelik iş)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOYUM_SKOR_V1',
       'Rep Portföyüm segment motoru: saha_satis_skor tablosu + gecelik BG/NBD işi (portfoyum_skor.py)',
       'Segment sabit gün eşiğiyle değil, her müşterinin kendi kadansı + BG/NBD p_alive ile atanmalı (Fatih ilkesi)',
       '{"tablo":"saha_satis_skor","is":"portfoyum_skor.py","model":"BG/NBD (lifetimes)","kural":"x<2/medyan yok=seyrek; p_alive<0.30 => son_gun>365?dormant:slip; ratio<=1.5=ok; aksi=due","cron":"30 3 * * *","marker":"PORTFOYUM_SKOR_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_SKOR_V1');

-- 2) build-log: endpoint JOIN (segment=null → gerçek segment)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOYUM_SKOR_JOIN_V1',
       '/api/saha/portfoyum ucuna saha_satis_skor LEFT JOIN — segment/p_alive/exp30/son_gun/medyan_gun/siparis döner',
       'Client segment tahtası + akordeon + model satırı bu alanlar dolunca otomatik açılır',
       '{"uc":"/api/saha/portfoyum","tablo":"saha_satis_skor","dosya":"server_container.mjs","marker":"PORTFOYUM_SKOR_JOIN_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_SKOR_JOIN_V1');

-- 3) yetenek: tablo (footprint kör kaydedebilir → anlamlandır; yoksa ekle)
INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, kanit, aktif, eklendi_at, guncellendi_at, son_gorulme)
SELECT 'saha_satis_skor', 'tablo',
       'Rep müşteri segment skoru (BG/NBD): segment + p_alive + exp30 + kendi kadansı (son_gun/medyan_gun/siparis)',
       'Gecelik portfoyum_skor.py doldurur; /api/saha/portfoyum LEFT JOIN okur',
       'saha', 'canli', 'taslak',
       '{"is":"portfoyum_skor.py","uc":"/api/saha/portfoyum","marker":"PORTFOYUM_SKOR_V1"}'::jsonb,
       true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_satis_skor');
UPDATE bi_yetenek
   SET ne_ise_yarar='Rep müşteri segment skoru (BG/NBD): segment + p_alive + exp30 + kendi kadansı (son_gun/medyan_gun/siparis)',
       cekmece='saha', durum='canli', guncellendi_at=now()
 WHERE ad='saha_satis_skor' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='' OR durum='tanimsiz' OR durum IS NULL);

-- 4) yetenek: gecelik iş (fonksiyon/süreç)
INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, kanit, aktif, eklendi_at, guncellendi_at, son_gorulme)
SELECT 'portfoyum_skor', 'fonksiyon',
       'Gecelik BG/NBD segment işi: tenant başına fit → her müşteriye p_alive/exp30 + segment (sabit gün eşiği yok)',
       'Host cron 30 3 * * * python3 portfoyum_skor.py → saha_satis_skor upsert',
       'saha', 'canli', 'taslak',
       '{"cikti":"saha_satis_skor","model":"BG/NBD","marker":"PORTFOYUM_SKOR_V1"}'::jsonb,
       true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='portfoyum_skor');

-- doğrula
SELECT 'insa' AS t, adim FROM bi_insa_gunlugu WHERE adim IN ('PORTFOYUM_SKOR_V1','PORTFOYUM_SKOR_JOIN_V1')
UNION ALL SELECT 'yetenek', ad FROM bi_yetenek WHERE ad IN ('saha_satis_skor','portfoyum_skor')
UNION ALL SELECT 'skor_satir', count(*)::text FROM saha_satis_skor;
