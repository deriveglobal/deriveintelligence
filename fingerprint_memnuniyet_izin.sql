-- fingerprint_memnuniyet_izin.sql — Memnuniyet paneli yetkilendirme fingerprint'i. Idempotent.
-- Calistir (Fatih, deploy+backfill sonrasi):
--   docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < fingerprint_memnuniyet_izin.sql
BEGIN;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MEMNUNIYET_IZIN_V1',
       'Izinler matrisine "Memnuniyet" alt-araci (saha/Yönetim & Analiz, dept memnuniyet)',
       'Memnuniyet paneli (Yönetim konsolu Denetim) yetki-yonetilebilir olsun',
       '{"marker":"MEMNUNIYET_IZIN_V1","shell":"tenant-admin.js","modul":"saha","dept":"memnuniyet"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MEMNUNIYET_IZIN_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MEMNUNIYET_GATE_SRV_V1',
       'SAHA_DEPT_MAP += /api/saha/nabiz-ozet -> ["memnuniyet"] (_enforceSahaDept)',
       'Matris toggle manager erisimini gercekten yonetsin (admin bypass; nabiz-ozet zaten manager/admin-kapili)',
       '{"marker":"MEMNUNIYET_GATE_SRV_V1","uc":["GET /api/saha/nabiz-ozet"],"dept":"memnuniyet"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MEMNUNIYET_GATE_SRV_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MEMNUNIYET_DEPT_BACKFILL_V1',
       'saha manager+admin departments[] += memnuniyet (deploy oncesi)',
       'Gating acilinca mevcut manager nabiz-ozet erisimini kaybetmesin',
       '{"marker":"MEMNUNIYET_DEPT_BACKFILL_V1","tur":"data","dept":"memnuniyet","hedef":"saha manager+admin"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MEMNUNIYET_DEPT_BACKFILL_V1');

-- Panel + veri ucu yetenegi (builder eklemediyse ekle; ekediyse dokunma)
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'saha_nabiz_ozet','uc',
       'Saha memnuniyet nabzi ozeti: deger capasi (0-10) dagilimi, temsilci basina son cevap, Mod-3 asistan cevaplari. Yönetim konsolu Denetim > Memnuniyet paneli bunu okur.',
       'GET /api/saha/nabiz-ozet — requireSahaAccess(["manager","admin"]) + SAHA_DEPT_MAP dept "memnuniyet"; kaynak bi_geri_bildirim (hedef_tur=nabiz_capa)',
       'memnuniyet','canli','taslak',
       '{"uc":["GET /api/saha/nabiz-ozet"],"panel":"MEMNUNIYET_PANEL_V1","dept":"memnuniyet"}'::jsonb,
       true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='saha_nabiz_ozet');

COMMIT;

SELECT adim, ts::date FROM bi_insa_gunlugu
WHERE adim IN ('MEMNUNIYET_IZIN_V1','MEMNUNIYET_GATE_SRV_V1','MEMNUNIYET_DEPT_BACKFILL_V1') ORDER BY adim;
SELECT ad, tur, durum, cekmece FROM bi_yetenek WHERE ad='saha_nabiz_ozet';
