-- MUSTERI_HATIRLATMA_DUZENLE_V1 — footprint (bi_insa_gunlugu + bi_yetenek). Idempotent.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_mk_hatirlatma_duzenle.sql

-- (a) build-log (bi_insa_gunlugu: adim, ne, neden, detay jsonb)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT
  'MUSTERI_HATIRLATMA_DUZENLE_V1',
  'Musteri Karti "Hareketler" listesindeki hatirlatmalar (saha_sinyal not/takip) artik tiklanabilir. Tiklaninca modal aciliyor: metin + takip tarihi guncellenebilir, "Tamamlandi" ile kapatilabilir (detay.kapandi=true), tekrar "Geri Ac" edilebilir. Server: /olaylar sinyal sorgusuna id + push extra (sid/sozet/stakip/skapandi) + yeni uc PUT /api/saha/sinyal/:id (ozet + detay.takip_tarihi + detay.kapandi). Client: _mkYukle draw() mk-ev satirlarina data-sid + _mkHatDuzenle modal.',
  'Ozellik (Eftal Yildiz 03.08): musteri kartinda gorunen hatirlatmaya tiklayip hizli guncelleme/tamamlama. Kok-eksik: saha_sinyal not/takip kayitlarinin duzenleme/kapatma ucu HIC yoktu; detay.kapandi sadece okunuyordu, hicbir yerde set edilmiyordu; timeline satiri id tasimiyordu.',
  '{"marker":"MUSTERI_HATIRLATMA_DUZENLE_V1","uc":["PUT /api/saha/sinyal/:id"],"dosya":["server_container.mjs","shells/saha.js"],"tablo":"saha_sinyal","ozellik":"Eftal Yildiz 03.08"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_HATIRLATMA_DUZENLE_V1');

-- (b) yetenek defteri — yeni endpoint (footprint yalniz tablo getirir; uc elle)
INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, kanit, aktif, eklendi_at, guncellendi_at, son_gorulme)
SELECT
  'PUT /api/saha/sinyal/:id', 'uc',
  'Bir saha_sinyal (not/takip) kaydini duzenler: ozet (metin), detay.takip_tarihi (takip tarihi ekle/kaldir; tip not<->takip otomatik gecer), detay.kapandi (tamamla / geri ac). Tenant + saha scope guard (musteri_id uzerinden); saha_musteri_aksiyon log birakir. Musteri Kartindaki hatirlatmalarin dogrudan guncellenmesini saglar.',
  'PUT /api/saha/sinyal/<uuid>  body: {metin?, takip_tarihi?:"YYYY-MM-DD"|"", tamamla?:bool}',
  'sinyal', 'canli', 'taslak',
  '{"marker":"MUSTERI_HATIRLATMA_DUZENLE_V1","uc":["PUT /api/saha/sinyal/:id"],"tablo":"saha_sinyal","govde":{"metin":"string?","takip_tarihi":"YYYY-MM-DD|\"\"?","tamamla":"bool?"},"ozellik":"Eftal Yildiz 03.08"}'::jsonb,
  true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='PUT /api/saha/sinyal/:id');

-- dogrula
SELECT 'insa_gunlugu' k, adim ad, ts::date FROM bi_insa_gunlugu WHERE adim='MUSTERI_HATIRLATMA_DUZENLE_V1'
UNION ALL
SELECT 'yetenek' k, ad, eklendi_at::date FROM bi_yetenek WHERE ad='PUT /api/saha/sinyal/:id';
