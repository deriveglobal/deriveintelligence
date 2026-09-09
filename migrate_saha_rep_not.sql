-- saha_fix_3 (omurga_78) — notlara/hatirlatmalara musteri baglantisi. Idempotent. Deploy'dan ONCE calistir.
-- docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < migrate_saha_rep_not.sql
ALTER TABLE saha_rep_not ADD COLUMN IF NOT EXISTS musteri_id uuid;
CREATE INDEX IF NOT EXISTS ix_saha_rep_not_musteri ON saha_rep_not(musteri_id);
SELECT 'saha_rep_not.musteri_id hazir' AS durum;
