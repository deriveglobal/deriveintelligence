#!/usr/bin/env python3
# sl_connector.py: SL_TENANT KRB default'unu kaldir -> zorunlu (per-tenant cron zaten
# SL_TENANT gecirir). Idempotent. Host kopyada calisir (imaja build'de girer).
import sys, shutil, re
PATH = sys.argv[sys.argv.index('--path')+1] if '--path' in sys.argv else '/opt/krb-assessment/sl_connector.py'
s = open(PATH, encoding='utf-8').read()
OLD = 'TENANT   = os.getenv("SL_TENANT", "f8a5d20f-ecf8-4ce2-a492-69268fbb03fa")'
NEW = 'TENANT   = os.getenv("SL_TENANT", "")  # AGNOSTIK: KRB default kaldirildi; cron per-tenant gecirir'
if 'AGNOSTIK: KRB default kaldirildi' in s:
    print('[=] zaten uygulanmis (idempotent).'); sys.exit(0)
if s.count(OLD) != 1:
    print(f'[!] anchor {s.count(OLD)} kez (1 olmali). Iptal.'); sys.exit(1)
s = s.replace(OLD, NEW)
# run() guard'ina SL_TENANT ekle
G_OLD = 'if not SL_USER or not SL_PASS:\n        raise SystemExit("⚠ SL_USER / SL_PASS ortam değişkenleri gerekli (CO1 Basic-auth).")'
G_NEW = ('if not SL_USER or not SL_PASS:\n        raise SystemExit("⚠ SL_USER / SL_PASS ortam değişkenleri gerekli (CO1 Basic-auth).")\n'
         '    if not TENANT:\n        raise SystemExit("⚠ SL_TENANT gerekli (per-tenant; sl.d/<t>.env).")')
if s.count(G_OLD) == 1:
    s = s.replace(G_OLD, G_NEW)
    print('[+] run() guard: SL_TENANT zorunlu eklendi.')
else:
    print(f'[!] run() guard anchor {s.count(G_OLD)} kez — guard ATLANDI (default="" yeterli).')
shutil.copy2(PATH, PATH + '.bak_agnostik')
open(PATH, 'w', encoding='utf-8').write(s)
print('[OK] sl_connector.py agnostik. python3 -m py_compile ile dogrula, build''e dahil et.')
