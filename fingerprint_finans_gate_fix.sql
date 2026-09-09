-- fingerprint_finans_gate_fix.sql — nav sizan yorum duzeltmesi build-log'u. Idempotent.
-- Calistir (Fatih, deploy sonrasi):
--   docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform < fingerprint_finans_gate_fix.sql
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_GATE_FIX_V1',
       'bi.js nav: sizan "/* FINANS_GATE_V1 */" yorumu kaldirildi (template literal icinde, ${} disinda kalmis, sekme cubugunda duz metin render oluyordu)',
       'FINANS_GATE_V1 yamasinda yorum HTML template''ine sizmisti; gate mantigi degismedi, yalnizca kozmetik sizinti',
       '{"marker":"FINANS_GATE_FIX_V1","shell":"shells/bi.js","satir":82,"onceki":"FINANS_GATE_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_GATE_FIX_V1');
SELECT adim, ts::date FROM bi_insa_gunlugu WHERE adim='FINANS_GATE_FIX_V1';
