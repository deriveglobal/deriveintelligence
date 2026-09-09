-- ============================================================================
-- fingerprint_finans_izin.sql — Finans Odasi yetkilendirme (matris+gate+backfill) fingerprint'i.
-- Idempotent. Calistir (Fatih, Hetzner'da, deploy+backfill sonrasi):
--   docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform \
--     < fingerprint_finans_izin.sql
-- ============================================================================

BEGIN;

-- build-log
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_IZIN_V1',
       'Yonetim konsolu Izinler matrisine "Finans Odasi" alt-araci (intelligence modulu, Odalar grubu)',
       'Finans Odasi kullanici-bazli yetki-yonetilebilir olsun (Kapsam precedenti); manager+admin varsayilan',
       '{"marker":"FINANS_IZIN_V1","shell":"tenant-admin.js","dept":"finansodasi","modul":"intelligence"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_IZIN_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_GATE_V1',
       'BI shell: Finans Odasi sekme+oda enjeksiyonu dept-gated (allowedDepts.includes finansodasi)',
       'Sekme onceden HERKESE hardcoded gorunuyordu; matris toggle anlamli olsun diye client kapi eklendi (price-list/rakip ile ayni)',
       '{"marker":"FINANS_GATE_V1","shell":"shells/bi.js","dept":"finansodasi"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_GATE_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_GATE_SRV_V1',
       'Sunucu: /api/bi/finans/ticari-sermaye + /api/bi/finans-odasi uclarina requireBiDept("finansodasi") zorlamasi (saha mgr/admin fallback korundu)',
       'Client==server kurali; ayrica shell ucu ONCEDEN AUTHSIZ finans.html (son-bilinen sayilar gomulu) servis ediyordu -> sizinti kapatildi',
       '{"marker":"FINANS_GATE_SRV_V1","uc":["GET /api/bi/finans/ticari-sermaye","GET /api/bi/finans-odasi"],"dept":"finansodasi"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_GATE_SRV_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_DEPT_BACKFILL_V1',
       'Veri gocu: mevcut intelligence manager+admin kullanicilarina departments[]+= "finansodasi"',
       'Gating acilinca kimse Finans Odasi''ni kaybetmesin (yalnizca ekler)',
       '{"marker":"FINANS_DEPT_BACKFILL_V1","tur":"data","dept":"finansodasi","hedef":"intelligence manager+admin"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_DEPT_BACKFILL_V1');

-- yetenek defteri: mevcut finans uclarini "artik dept-gated" olarak zenginlestir
UPDATE bi_yetenek
SET nasil = 'GET /api/bi/finans/ticari-sermaye — requireBiDept("finansodasi") (owner+modul-admin bypass; manager dept ister) + saha mgr/admin fallback',
    guncellendi_at = now()
WHERE ad = 'finans_ticari_sermaye';

UPDATE bi_yetenek
SET nasil = 'GET /api/bi/finans-odasi — dept-gated (finansodasi) + saha mgr/admin fallback; shells/finans.html servis eder',
    guncellendi_at = now()
WHERE ad = 'finans_odasi_shell';

COMMIT;

-- dogrulama
SELECT adim, ts::date FROM bi_insa_gunlugu
WHERE adim IN ('FINANS_IZIN_V1','FINANS_GATE_V1','FINANS_GATE_SRV_V1','FINANS_DEPT_BACKFILL_V1')
ORDER BY adim;
SELECT ad, tur, durum FROM bi_yetenek WHERE ad IN ('finans_ticari_sermaye','finans_odasi_shell') ORDER BY ad;
