-- Derive · NABIZ çok-tenant config (idempotent). KRB alıcıları = mevcut default (davranış korunur).
\pset pager off
-- KRB: kisa_ad + nabiz_alici (mevcut hardcoded default)
UPDATE platform_tenants
   SET config_json = COALESCE(config_json,'{}'::jsonb)
       || jsonb_build_object('kisa_ad','KRB','nabiz_alici','fatih@deriveglobal.com,fbilen@krb.com.tr')
 WHERE id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND (COALESCE(config_json->>'kisa_ad','')='' OR COALESCE(config_json->>'nabiz_alici','')='');

-- Anadolu: kisa_ad (demo → nabiz_alici YOK; compute eder, e-posta göndermez)
UPDATE platform_tenants
   SET config_json = COALESCE(config_json,'{}'::jsonb) || jsonb_build_object('kisa_ad','Anadolu')
 WHERE id='42822870-4ea3-424d-a16f-50b91afca32c'
   AND COALESCE(config_json->>'kisa_ad','')='';

\echo '=== nabiz config dogrulama ==='
SELECT COALESCE(config_json->>'kisa_ad',name) kisa_ad, evren_tanim(id) tanim,
       COALESCE(config_json->>'nabiz_alici','(YOK → e-posta yok)') alici
  FROM platform_tenants ORDER BY name;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'NABIZ_MULTITENANT_V1',
       'nabiz.sh çok-tenant: verisi olan her tenant için döngü; kimlik/is-tanimi/alıcı config_json''dan; NABIZ_DRY güvenli test',
       'Onceki: tek-tenant (implicit KRB) + hardcoded alıcı + "KRB lastik toptancısı" prompt. Simdi per-tenant.',
       '{"script":"nabiz.sh","config":["kisa_ad","nabiz_alici","evren_tanim"],"KRB_alici":"degismedi","anadolu":"compute-only (alici yok)"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='NABIZ_MULTITENANT_V1');
\echo '=== config SONU ==='
