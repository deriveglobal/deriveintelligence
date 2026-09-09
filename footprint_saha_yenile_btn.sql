-- SAHA_YENILE_BTN_V1 — footprint (build-log). Idempotent.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_saha_yenile_btn.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SAHA_YENILE_BTN_V1',
  'Saha ust barina (.saha-user, ad/rol yaninda, cikis ikonundan once) acik "⟳ Yenile" butonu eklendi. Tiklaninca aktif oda (roombar .saha-rtab.on) veya aktif alt sekme (.saha-tab.on) yeniden yuklenir (eski PTR refresh() mantigi; tam reload DEGIL). Kisa donme animasyonu.',
  'PULL_REFRESH_OFF_V1 ile pull/swipe-to-refresh kapatildi; kullaniciya acik bir yenileme yolu gerekiyordu (Fatih 04.08: "add a refresh button somewhere proper").',
  '{"marker":"SAHA_YENILE_BTN_V1","dosya":["shells/saha.js"],"yer":"saha-head/.saha-user"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SAHA_YENILE_BTN_V1');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='SAHA_YENILE_BTN_V1';
