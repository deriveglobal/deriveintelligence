-- TANI: HAREKETLER'de ziyaret listesi neden bos? (foto_sayisi kolon mu, alt-sorgu mu?)
-- Calistir:
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_olaylar_ziyaret.sql

-- 1) foto_sayisi saha_ziyaret'te FIZIKSEL kolon mu? (bos donerse kolon YOK = sorgu hata atar)
SELECT 'foto_sayisi kolon?' AS test, column_name
  FROM information_schema.columns
 WHERE table_schema='public' AND table_name='saha_ziyaret' AND column_name='foto_sayisi';

-- 2) /olaylar ziyaret alt-sorgusunun BIREBIR AYNISI — hata atarsa kok-neden budur
SELECT ziyaret_tarihi ts, LEFT(COALESCE(notlar,''),30) notlar, rep_id::text rid, lokasyon_adi, foto_sayisi
  FROM saha_ziyaret
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND durum='TAMAMLANDI'
 ORDER BY ziyaret_tarihi DESC LIMIT 3;
