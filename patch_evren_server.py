#!/usr/bin/env python3
# ============================================================
# Derive · AGNOSTİK FAZ C — server_container.mjs: grup_adi (I)LIKE 'LASTIK%'
#   -> grup_adi (I)LIKE evren_desen(<alias>tenant_id)
# GÜVENLİK: her site icin, ayni sorgu penceresinde uygun tenant_id referansi
#   (bare match -> bare 'tenant_id'; 'f.' match -> 'f.tenant_id') VAR MI diye
#   dogrular. Yoksa -> FLAG (DEGISTIRMEZ). Belirsiz-JOIN riskini mekanik eler.
# Mod: (varsayilan) DRY rapor; --apply uygular (.bak). Idempotent.
# evren_desen tire tenant'ta 'LASTIK%' -> SIFIR davranis degisikligi.
# ============================================================
import re, sys, shutil

PATH = sys.argv[sys.argv.index('--path')+1] if '--path' in sys.argv else '/opt/krb-assessment/server_container.mjs'
APPLY = '--apply' in sys.argv
s = open(PATH, encoding='utf-8').read()

pat = re.compile(r"(?P<a>\b[A-Za-z_]\w*\.)?grup_adi(?P<sp>\s+)(?P<op>I?LIKE)\s+'LASTIK%'")
WB, WA = 750, 160  # sorgu penceresi (once/sonra)

def tenant_in_scope(win, alias):
    if alias:  # 'f.' -> 'f.tenant_id'
        return (alias + 'tenant_id') in win
    # bare: nokta/kelime ile bitisik OLMAYAN tenant_id
    return re.search(r"(?<![\w.])tenant_id", win) is not None

safe, flagged = [], []
for m in pat.finditer(s):
    a = m.group('a') or ''
    win = s[max(0, m.start()-WB): m.end()+WA]
    ln = s.count('\n', 0, m.start()) + 1
    (safe if tenant_in_scope(win, a) else flagged).append((ln, a or '(bare)', m.group(0)))

print(f"[i] toplam site: {len(safe)+len(flagged)}  | GUVENLI: {len(safe)}  | FLAG (degistirilmez): {len(flagged)}")
print("\n=== FLAG (kapsamda uygun tenant_id BULUNAMADI — elle bakilacak) ===")
for ln,a,txt in flagged: print(f"  satir {ln:>6} alias={a:<8} {txt}")
if not flagged: print("  (yok — hepsi guvenli)")

print("\n=== GUVENLI ornek (ilk 6) ===")
for ln,a,txt in safe[:6]: print(f"  satir {ln:>6} alias={a:<8} {txt}")

insite = list(re.finditer(r"grup_adi\s+IN\s*\(\s*'LASTIK[^)]*\)", s))
print(f"\n[i] 'grup_adi IN (...LASTIK...)' (bu patch DOKUNMAZ): {len(insite)}")

if not APPLY:
    print("\n[=] DRY — dosya DEGISMEDI. FLAG=0 ise: --apply")
    sys.exit(0)

if flagged:
    print("\n[!] FLAG'li site VAR — GUVENLI degil. Once onlari coz. Dosya DEGISMEDI.")
    sys.exit(2)

# yalniz GUVENLI olanlari donustur (flagged zaten yok bu noktada)
def repl(m):
    a = m.group('a') or ''
    win = s[max(0, m.start()-WB): m.end()+WA]
    if not tenant_in_scope(win, a):
        return m.group(0)  # dokunma
    return f"{a}grup_adi{m.group('sp')}{m.group('op')} evren_desen({a}tenant_id)"

n_before = len(pat.findall(s))
if n_before == 0:
    print("\n[=] 0 eslesme — zaten uygulanmis (idempotent)."); sys.exit(0)
bak = PATH + '.bak_evren'; shutil.copy2(PATH, bak)
s2 = pat.sub(repl, s)
open(PATH, 'w', encoding='utf-8').write(s2)
kalan = len(pat.findall(s2))
print(f"\n[OK] donusturuldu. Yedek: {bak}. Kalan 'LASTIK%' grup_adi literal: {kalan} (0 olmali).")
print("    SIMDI: node --check (client .mjs kopya) -> docker build -> up -> smoke test.")
