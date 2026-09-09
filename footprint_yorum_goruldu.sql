-- YORUM_GORULDU_V1 — footprint (build-log). Idempotent.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_yorum_goruldu.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YORUM_GORULDU_V1',
  'Ziyaret yorumlarina "✓ görüldü" okundu-isareti. Server: POST /gordum artik saha_ziyaret_gorulme.gorulme_at''i SON görme olacak sekilde gunceller (ON CONFLICT DO UPDATE, onceden DO NOTHING=ilk görme); GET /ziyaretler/:id/yorumlar her yoruma goruldu bayragi ekliyor = yorumdan SONRA yazan-disi biri (ör. rep) ziyareti gordu mu (EXISTS gorulme g WHERE g.user_id<>y.user_id AND g.gorulme_at>=y.created_at). Client: renderYorumlar yorum balonu altina yesil "✓ görüldü".',
  'Fatih 07.08: yorum yazinca rep''in farkinda oldugunu goremiyordu ("kimse farkinda degil" hissi). Bildirim zaten calisiyordu (rep''ler yorumlari aliyor/okuyor) ama yazan tarafa geri-bildirim yoktu. Bu isaret landing''i yazana gorunur kilar.',
  '{"marker":"YORUM_GORULDU_V1","uc":["POST /api/saha/ziyaretler/:id/gordum","GET /api/saha/ziyaretler/:id/yorumlar"],"dosya":["server_container.mjs","shells/saha.js"],"tablo":["saha_ziyaret_gorulme","saha_ziyaret_yorum"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YORUM_GORULDU_V1');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='YORUM_GORULDU_V1';
