#!/usr/bin/env python3
# HOTFIX: kategori_segment/sezon(kategori, $1::uuid) -> (kategori, tenant_id::uuid)
# NEDEN: ayni $1 hem 'tenant_id::text=$1' (text) hem '$1::uuid' -> Postgres $1'i uuid
#   cikarip 'text=$1' i text=uuid yapiyor (operator does not exist: text = uuid).
# COZUM: param yerine SUTUN (tenant_id::uuid) — $1 text kalir, hem uuid hem text
#   tenant_id sutununu ::uuid ile karsilar. Idempotent.
import sys, shutil
PATH = sys.argv[sys.argv.index('--path')+1] if '--path' in sys.argv else '/opt/krb-assessment/server_container.mjs'
s = open(PATH, encoding='utf-8').read()
R = [
 ('kategori_segment(kategori, $1::uuid)', 'kategori_segment(kategori, tenant_id::uuid)'),
 ('kategori_sezon(kategori, $1::uuid)',   'kategori_sezon(kategori, tenant_id::uuid)'),
]
tot = sum(s.count(o) for o,_ in R)
if tot == 0:
    print('[=] 0 eslesme — zaten duzeltilmis (idempotent).'); sys.exit(0)
bak = PATH + '.bak_katfix'; shutil.copy2(PATH, bak)
for o,n in R:
    c = s.count(o)
    if c: s = s.replace(o, n); print(f'[+] {c} x  {o[:40]}... -> tenant_id::uuid')
open(PATH,'w',encoding='utf-8').write(s)
print(f'[OK] {tot} call-site duzeltildi ($1::uuid -> tenant_id::uuid). Yedek: {bak}. node --check -> build.')
