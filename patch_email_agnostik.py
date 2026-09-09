#!/usr/bin/env python3
# ============================================================
# Derive · AGNOSTİK — 5 hardcoded KRB e-posta -> rol/config
#  29119 pilot_reps config · 29785 ozel_karsilama_email config ·
#  30728 tenant_admin rol · 38820 cap-only · 38889 platform_owner-only
# Her replace count-guard'li (uyusmazsa HICBIR SEY yazilmaz). Idempotent (marker).
# KRB config degerleri = mevcut -> KRB davranisi birebir.
# ============================================================
import sys, shutil
PATH = sys.argv[sys.argv.index('--path')+1] if '--path' in sys.argv else '/opt/krb-assessment/server_container.mjs'
MARK = 'EMAIL_AGNOSTIK_V1'
s = open(PATH, encoding='utf-8').read()
if MARK in s:
    print('[=] zaten uygulanmis (idempotent).'); sys.exit(0)

R = []
# 29119 pilot: IN(2 email) -> config pilot_reps ($1=tenantId)
R.append((
 "WHERE u.email IN ('eyildiz@krb.com.tr','hbilgi@krb.com.tr')",
 "WHERE lower(u.email::text) = ANY( COALESCE((SELECT array_agg(lower(x)) FROM jsonb_array_elements_text((SELECT config_json->'pilot_reps' FROM platform_tenants WHERE id=$1)) x), ARRAY[]::text[]) ) /* " + MARK + " */"))
# 29785 greeting: hardcoded fbilen -> config ozel_karsilama_email
R.append((
 "const _mail = (_who.rows[0] || {}).email || '';\n            if (_mail === 'fbilen@krb.com.tr') {",
 "const _mail = (_who.rows[0] || {}).email || '';\n            let _ozelMail=''; try{ _ozelMail=String(((await query(\"SELECT config_json->>'ozel_karsilama_email' e FROM platform_tenants WHERE id=$1\",[tenantId])).rows[0]||{}).e||''); }catch(_e){} /* " + MARK + " */\n            if (_ozelMail && _mail && _mail.toLowerCase() === _ozelMail.toLowerCase()) {"))
# 30728 provisioning: yonetim@ -> tenant_admin rol
R.append((
 "      WHERE u.email = 'yonetim@krb.com.tr'\n      ON CONFLICT (tenant_id, user_id, module_id) DO NOTHING",
 "      WHERE tu.tenant_role = 'tenant_admin'  /* " + MARK + " — her tenant kendi admini */\n      ON CONFLICT (tenant_id, user_id, module_id) DO NOTHING"))
# 38820 rep-aktivite: yonetim@ gecici safety net kaldir -> cap-only
R.append((
 'const _raOk = _sahaCapRole(session, "rep-aktivite", []) || (who.rows.length && who.rows[0].e === "yonetim@krb.com.tr");',
 'const _raOk = _sahaCapRole(session, "rep-aktivite", []);  /* ' + MARK + ' — yonetim@ email fallback kaldirildi, cap-based */'))
# 38889 hata-raporu: platform telemetri -> yalniz platform_owner
R.append((
 'if (normalizeRole(session.role) !== "platform_owner" && String(session.email || "").toLowerCase() !== "yonetim@krb.com.tr") {',
 'if (normalizeRole(session.role) !== "platform_owner") {  /* ' + MARK + ' — platform telemetri yalniz platform_owner */'))

for i,(old,new) in enumerate(R,1):
    c = s.count(old)
    if c != 1:
        print(f'[!] R{i} anchor {c} bulundu (1 olmali). IPTAL — dosya DEGISMEDI.')
        print(f'    bas: {old[:70]!r}'); sys.exit(1)

bak = PATH + '.bak_emailagn'; shutil.copy2(PATH, bak)
for i,(old,new) in enumerate(R,1):
    s = s.replace(old, new); print(f'[+] R{i} uygulandi.')
open(PATH,'w',encoding='utf-8').write(s)
print(f'[OK] {MARK}. Yedek: {bak}. Kalan krb.com.tr:')
print('    node --check server_container.mjs -> build.')
