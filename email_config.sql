-- Derive · e-posta hardcode'larini config'e tasi (KRB degerleri = mevcut davranis).
\pset pager off
UPDATE platform_tenants
   SET config_json = COALESCE(config_json,'{}'::jsonb)
       || jsonb_build_object(
            'pilot_reps', '["eyildiz@krb.com.tr","hbilgi@krb.com.tr"]'::jsonb,
            'ozel_karsilama_email', 'fbilen@krb.com.tr')
 WHERE id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND NOT (COALESCE(config_json,'{}'::jsonb) ? 'pilot_reps');

\echo '=== KRB e-posta config dogrulama ==='
SELECT config_json->'pilot_reps' pilot, config_json->>'ozel_karsilama_email' karsilama
  FROM platform_tenants WHERE id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'EMAIL_AGNOSTIK_CONFIG_V1',
       'Hardcoded KRB e-postalar config_json''a: pilot_reps + ozel_karsilama_email (KRB=mevcut)',
       'Runtime e-posta literallerini rol/config''e cevirmek icin config zemini; KRB davranisi birebir.',
       '{"config_key":["pilot_reps","ozel_karsilama_email"],"rol_tabanli":["30728 tenant_admin","38820 cap","38889 platform_owner"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='EMAIL_AGNOSTIK_CONFIG_V1');
\echo '=== config SONU ==='
