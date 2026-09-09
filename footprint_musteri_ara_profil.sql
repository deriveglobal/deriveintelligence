-- MUSTERI_ARA_PROFIL_V1 — footprint (build-log). Idempotent.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_musteri_ara_profil.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MUSTERI_ARA_PROFIL_V1',
  'GET /api/saha/musteri-ara SAHA sorgusuna 10 profil kolonu eklendi (raf_markalar, bayilikler, rakip_toptancilar, kis_stok, yaz_stok, sektorler, tedarikci_markalar, kullanilan_markalar, arac_parki, yillik_potansiyel). Boylece "Musteri Sec"ten acilan ziyaret formu musterinin kayitli profilini PREFILL eder.',
  'Saha: "musteri ziyaretinde girilen rakip/raf profili her seferinde bos geliyor". TEShIS: profil saha_musteri kolonlarina yaziliyor (write-back OK, DB dolu — 185 tuketiciden 57 raf/108 bayi dolu) VE ziyaret detay saklaniyor. Kok-neden: ziyaret formu mus.raf_markalar''dan prefill ediyor ama musteri-ara bu kolonlari SELECT etmiyordu → mus''ta undefined → form bos.',
  '{"marker":"MUSTERI_ARA_PROFIL_V1","uc":["GET /api/saha/musteri-ara"],"dosya":["server_container.mjs"],"tablo":["saha_musteri"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MUSTERI_ARA_PROFIL_V1');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='MUSTERI_ARA_PROFIL_V1';
