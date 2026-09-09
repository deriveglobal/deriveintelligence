-- PULL_REFRESH_OFF_V1 — footprint (build-log). Idempotent.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_pull_refresh_off.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PULL_REFRESH_OFF_V1',
  'Uygulamanin kendi pull/swipe-to-refresh ozelligi (PULL_REFRESH_V1, shells/saha.js) TAMAMEN kapatildi. IIFE basina erken return kondu; hicbir touch listener baglanmiyor, "⟳ Yenileniyor…" pill''i olusmuyor. Kod silinmedi (geri alinabilir).',
  'Fatih 04.08: pull-to-refresh + sagdan-sola swipe kazara "Yenileniyor" tetikliyordu. PULL_REFRESH_V1 yalniz dikey dy''ye bakiyor ama yatay/capraz hareketi ayirt etmiyordu → yan-swipe misfire. Karar: ozelligi tamamen kapat.',
  '{"marker":"PULL_REFRESH_OFF_V1","dosya":["shells/saha.js"],"kapatilan":"PULL_REFRESH_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PULL_REFRESH_OFF_V1');

SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='PULL_REFRESH_OFF_V1';
