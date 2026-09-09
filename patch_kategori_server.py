#!/usr/bin/env python3
# ============================================================
# Derive · AGNOSTİK — server kategori taksonomi call-site'lari per-tenant:
#   kategori_segment(kategori) / kategori_sezon(kategori) -> (kategori, $1::uuid)
#   Self-verify: kapsamda 'tenant_id::text=$1' (ya da =$1) VAR MI -> yoksa FLAG.
#   + 2 e-posta YORUM satiri temizligi (krb.com.tr yorumdan cikar).
# Idempotent (2-arg zaten -> eslesmez). DRY varsayilan; --apply.
# KRB override yok -> 2-arg = 1-arg -> sifir davranis degisikligi.
# ============================================================
import re, sys, shutil
PATH = sys.argv[sys.argv.index('--path')+1] if '--path' in sys.argv else '/opt/krb-assessment/server_container.mjs'
APPLY = '--apply' in sys.argv
s = open(PATH, encoding='utf-8').read()

pat = re.compile(r"(?P<fn>kategori_segment|kategori_sezon)\(kategori\)")
WB, WA = 700, 120
def tenant_in_scope(win):
    return re.search(r"tenant_id(::text)?\s*=\s*\$1", win) is not None

safe, flagged = [], []
for m in pat.finditer(s):
    win = s[max(0,m.start()-WB): m.end()+WA]
    ln = s.count('\n',0,m.start())+1
    (safe if tenant_in_scope(win) else flagged).append((ln, m.group('fn')))
print(f"[i] kategori_segment/sezon(kategori) site: {len(safe)+len(flagged)} | GUVENLI {len(safe)} | FLAG {len(flagged)}")
for ln,fn in flagged: print(f"  FLAG satir {ln} {fn}")
for ln,fn in safe:    print(f"  ok   satir {ln} {fn}")

# e-posta yorumlari (guard: varsa)
C = [
 ('// Sadece: (a) karsilama isteginde, (b) fbilen@krb.com.tr icin, (c) bugun',
  '// Sadece: (a) karsilama isteginde, (b) yapilandirilmis ozel-karsilama sahibi icin, (c) bugun'),
 ('// ---- RAPOR: yalniz yonetim@krb.com.tr ----',
  '// ---- RAPOR: yalniz platform yonetimi ----'),
]
print("\n[i] e-posta yorum temizligi:")
for i,(o,n) in enumerate(C,1): print(f"  C{i}: mevcut={s.count(o)}")

print("\n[not] FLAG'li site (prompt METNI, SQL degil) DOKUNULMAZ; yalniz GUVENLI SQL site'lari cevrilir.")
if not APPLY:
    print("\n[=] DRY — dosya DEGISMEDI. --apply ile GUVENLI'leri uygula (flag'liler atlanir).")
    sys.exit(0)

# yalniz kapsamda tenant_id=$1 olan SQL site'larini cevir; flag'li (prose) atla
cev = {'n': 0}
def repl(m):
    win = s[max(0, m.start()-WB): m.end()+WA]
    if tenant_in_scope(win):
        cev['n'] += 1
        return f"{m.group('fn')}(kategori, $1::uuid)"
    return m.group(0)  # FLAG (prompt metni) — dokunma
s2 = pat.sub(repl, s)
for o,n in C:
    if s2.count(o)==1: s2 = s2.replace(o,n)
bak = PATH + '.bak_katserver'; shutil.copy2(PATH, bak)
open(PATH,'w',encoding='utf-8').write(s2)
print(f"\n[OK] {cev['n']} GUVENLI SQL call-site cevrildi ({len(flagged)} prose atlandi) + e-posta yorumlari. Yedek: {bak}.")
print("    node --check -> build.")
