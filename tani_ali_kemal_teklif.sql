-- TANI + FOOTPRINT — Ali Kemal teklif durumlari + TEKLIF_KAYBET_TUM_AKTIF_V1 build-log
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_ali_kemal_teklif.sql

-- 1) Ali Kemal'in tekliflerinin durum dagilimi (butonun neden cikmadigini dogrular)
SELECT t.durum, COUNT(*) n
  FROM saha_teklif t
  JOIN users u ON u.id = t.rep_id
 WHERE t.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND (u.full_name ILIKE '%Ali Kemal%' OR u.email ILIKE '%alikemal%')
 GROUP BY t.durum ORDER BY n DESC;

-- 2) build-log
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'TEKLIF_KAYBET_TUM_AKTIF_V1',
  'Teklif detayinda "✕ Kaybettik / ✓ Kazandik" butonlari artik tum aktif durumlarda gorunuyor: TASLAK, ONAY_BEKLIYOR, ONAYLANDI, SUNULDU (onceden yalniz ONAYLANDI/SUNULDU). Sunucu (PUT /api/saha/teklifler/:id action:sonuc) bu gecislere zaten izin veriyordu; yalniz client buton gorunurlugu kisitliydi.',
  'Ali Kemal 04.08: "en son guncelleme bende gozukmuyor, halen rakipte kaldi secemiyorum". Kok-neden: teklifi TASLAK/ONAY_BEKLIYOR oldugundan detayda buton cikmiyordu (TEKLIF_SONUC_ONAYLANDI_V1 yalniz ONAYLANDI/SUNULDU aciyordu).',
  '{"marker":"TEKLIF_KAYBET_TUM_AKTIF_V1","dosya":["shells/saha.js"],"durumlar":["TASLAK","ONAY_BEKLIYOR","ONAYLANDI","SUNULDU"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='TEKLIF_KAYBET_TUM_AKTIF_V1');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim IN ('TEKLIF_SONUC_ONAYLANDI_V1','TEKLIF_KAYBET_TUM_AKTIF_V1') ORDER BY adim;
