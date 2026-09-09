-- MUSTERI_ARA_REP_ERP_V1 — footprint (build-log). Idempotent.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_musteri_ara_rep_erp.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_ARA_REP_ERP_V1',
  'GET /api/saha/musteri-ara: rep''ler artik ERP (master_musteri / SAP) carilerini de arama sonucunda gorur. Onceden `const cari = isRep ? {rows:[]} : ...` ile rep''e ERP carileri HIC donmuyordu; rep yalniz sorumlu_rep=kendisi saha musterilerini goruyordu. isRep guard kaldirildi — SAHA sonuclari yine rep-scoped, ERP arama tenant genelinde. Rep ERP cariyi bulup "ERP cariyi sahaya ekle" ile musteri_kodu''na bagli ekleyip aktivite girebilir.',
  'Yildiray Bilen 04.08: "Sirayhan Hafriyat SAP''ta var ama aktivite girmek icin bulamiyorum". Sirayhan ERP''de (M4134926) var, saha''da yok, Yildiray=rep → arama ERP''yi rep''e gostermedigi icin bulunamiyordu. Fatih karari: ERP carileri rep aramasina acilsin.',
  '{"marker":"MUSTERI_ARA_REP_ERP_V1","uc":["GET /api/saha/musteri-ara"],"dosya":["server_container.mjs"],"tablo":["master_musteri"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_ARA_REP_ERP_V1');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='MUSTERI_ARA_REP_ERP_V1';
