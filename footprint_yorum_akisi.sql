-- YORUM_AKISI_V1 — footprint (build-log + bi_yetenek uc). BIRLESIK (ziyaret + duyuru). Idempotent.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_yorum_akisi.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YORUM_AKISI_V1',
  'Bugun ekranina "🗨️ Yorumlar" karti (Mesajlar altina). Yeni uc GET /api/saha/yorum-akisi → BIRLESIK akis (saha_ziyaret_yorum UNION saha_duyuru_yorum). Her satir: tur (ziyaret/duyuru), ref_id, user_adi, icerik, created_at, baslik (firma/duyuru basligi), goruldu (yalniz ziyaret). Satira dokun: ziyaret→data-zid (ziyaretDetayModal), duyuru→data-did (duyuruDetayModal). Kapsam: ziyaret yorumlari rol-bazli (manager/admin tum ekip, rep z.rep_id=uid OR y.user_id=uid); DUYURU yorumlari herkese acik (duyuru yayin). Okunmamis rozeti = bi_bildirim "💬 Ziyaret yorumu"/"💬 Duyuru yorumu" okunmamis.',
  'Fatih: yorumlar ziyaret+duyuru icinde gomulu; merkezi akis yoktu → farkindalik dusuktu. Bugun ekraninda tek yerde tum yorum trafigi.',
  '{"marker":"YORUM_AKISI_V1","uc":["GET /api/saha/yorum-akisi"],"dosya":["server_container.mjs","shells/saha.js"],"tablo":["saha_ziyaret_yorum","saha_duyuru_yorum","saha_ziyaret","saha_duyuru","saha_musteri","bi_bildirim"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YORUM_AKISI_V1');

INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, cekmece, durum, guven, kanit, aktif, eklendi_at, guncellendi_at, son_gorulme)
SELECT 'GET /api/saha/yorum-akisi', 'uc',
  'Birlesik yorum akisi (Bugun ekrani Yorumlar karti): ziyaret + duyuru yorumlari. Ziyaret rol-bazli (manager tum ekip, rep kendi), duyuru herkese acik. Satir tur ile ilgili ekrana yonlendirir. Okunmamis sayaci.',
  'GET /api/saha/yorum-akisi → {yorumlar:[{tur,ref_id,user_adi,rol,icerik,created_at,baslik,goruldu}], okunmamis}',
  'saha', 'canli', 'taslak',
  '{"marker":"YORUM_AKISI_V1","tablo":["saha_ziyaret_yorum","saha_duyuru_yorum","saha_ziyaret_gorulme","bi_bildirim"]}'::jsonb,
  true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='GET /api/saha/yorum-akisi');

SELECT 'insa' k, adim ad FROM bi_insa_gunlugu WHERE adim='YORUM_AKISI_V1'
UNION ALL SELECT 'yetenek' k, ad FROM bi_yetenek WHERE ad='GET /api/saha/yorum-akisi';
