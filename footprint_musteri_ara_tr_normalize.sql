-- MUSTERI_ARA_TR_NORMALIZE_V1 — footprint (build-log) + hizli dogrulama. Idempotent.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_musteri_ara_tr_normalize.sql

-- build-log
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_ARA_TR_NORMALIZE_V1',
  'GET /api/saha/musteri-ara (Musteri Sec) eslesmesi TR harf + buyuk/kucuk duyarsiz yapildi: firma ve master_musteri.musteri_adi icin lower(translate(X,''İIıŞşÇçÖöÜüĞğ'',''iiissccoouugg'')) LIKE normalize(q). ORDER BY prefix de normalize. Vergi_no exact kaldi. Normalize LIKE, ILIKE eslesmelerinin ust-kumesi (yalniz sonuc ekler).',
  'Ali Kemal 04.08: kucuk harfle yazilmis cariler aktivite/ziyaret olustururken aramada bulunamiyordu. Kok-neden: ILIKE ASCII-duyarsiz ama Turkce harflerde (İ/ı, ş, ç...) Postgres harf-katlamasi Turkce-uyumlu degil.',
  '{"marker":"MUSTERI_ARA_TR_NORMALIZE_V1","uc":["GET /api/saha/musteri-ara"],"dosya":["server_container.mjs"],"tablo":["saha_musteri","master_musteri"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_ARA_TR_NORMALIZE_V1');

-- hizli dogrulama: normalize gercekten TR-case koruyor mu?
SELECT 'İSBIR' AS girdi, lower(translate('İSBIR','İIıŞşÇçÖöÜüĞğ','iiissccoouugg')) AS normalize_1,
       lower(translate('ışbir lastik','İIıŞşÇçÖöÜüĞğ','iiissccoouugg')) AS normalize_veri,
       lower(translate('ışbir lastik','İIıŞşÇçÖöÜüĞğ','iiissccoouugg'))
         LIKE '%'||lower(translate('İSBIR','İIıŞşÇçÖöÜüĞğ','iiissccoouugg'))||'%' AS eslesir_mi;

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='MUSTERI_ARA_TR_NORMALIZE_V1';
