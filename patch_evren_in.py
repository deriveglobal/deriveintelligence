#!/usr/bin/env python3
# ============================================================
# Derive · server_container.mjs: grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI')
#   -> grup_adi = ANY(evren_gruplar(<alias>tenant_id))   (exact-semantik korunur)
# 'LASTIK TICARI TAMIR'/'VERILEN SERVIS HIZMET' varyanti (tamir+servis) AYRI kural
#   -> DOKUNULMAZ. Self-verify: kapsamda uygun tenant_id yoksa FLAG.
# DRY varsayilan; --apply uygular. evren_gruplar default = o iki grup (KRB birebir).
# ============================================================
import re, sys, shutil

PATH = sys.argv[sys.argv.index('--path')+1] if '--path' in sys.argv else '/opt/krb-assessment/server_container.mjs'
APPLY = '--apply' in sys.argv
s = open(PATH, encoding='utf-8').read()

# yalniz TAM 'LASTIK TUKETICI','LASTIK TICARI' cifti (tamir/servis DISI)
pat = re.compile(r"(?P<a>\b[A-Za-z_]\w*\.)?grup_adi\s+IN\s*\(\s*'LASTIK TUKETICI'\s*,\s*'LASTIK TICARI'\s*\)")
WB, WA = 750, 160

def tenant_in_scope(win, alias):
    return (alias + 'tenant_id') in win if alias else re.search(r"(?<![\w.])tenant_id", win) is not None

safe, flagged = [], []
for m in pat.finditer(s):
    a = m.group('a') or ''
    win = s[max(0, m.start()-WB): m.end()+WA]
    ln = s.count('\n', 0, m.start()) + 1
    (safe if tenant_in_scope(win, a) else flagged).append((ln, a or '(bare)'))

print(f"[i] IN('LASTIK TUKETICI','LASTIK TICARI') site: {len(safe)+len(flagged)} | GUVENLI {len(safe)} | FLAG {len(flagged)}")
for ln,a in flagged: print(f"  FLAG satir {ln} alias={a}")
for ln,a in safe:    print(f"  ok   satir {ln} alias={a}")

tamir = list(re.finditer(r"grup_adi\s+IN\s*\(\s*'LASTIK TICARI TAMIR'", s))
print(f"[i] tamir/servis IN varyanti (DOKUNULMAZ): {len(tamir)}")

if not APPLY:
    print("[=] DRY — dosya DEGISMEDI. FLAG=0 ise --apply"); sys.exit(0)
if flagged:
    print("[!] FLAG var — dosya DEGISMEDI."); sys.exit(2)

def repl(m):
    a = m.group('a') or ''
    return f"{a}grup_adi = ANY(evren_gruplar({a}tenant_id))"

if len(pat.findall(s))==0:
    print("[=] 0 eslesme — idempotent."); sys.exit(0)
bak = PATH + '.bak_evrenin'; shutil.copy2(PATH, bak)
open(PATH,'w',encoding='utf-8').write(pat.sub(repl, s))
print(f"[OK] donusturuldu. Yedek: {bak}. node --check -> build.")
