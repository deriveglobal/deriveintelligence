import sys, re
F=sys.argv[1] if len(sys.argv)>1 else "shells/saha.js"
s=open(F,encoding="utf-8").read()
if "JS_NULL_GUARD_V1" in s:
    print("[skip] zaten var"); sys.exit(0)
# yalniz TEKIL querySelector/getElementById (querySelectorAll degil) + .addEventListener (zaten ?. olanlar haric)
pat_qs=re.compile(r'(querySelector\([^)]*\))\.addEventListener')
pat_id=re.compile(r'(getElementById\([^)]*\))\.addEventListener')
n1=len(pat_qs.findall(s)); n2=len(pat_id.findall(s))
assert n1+n2 > 0, "hic eslesme yok — yanlis dosya?"
s=pat_qs.sub(r'\1?.addEventListener', s)
s=pat_id.sub(r'\1?.addEventListener', s)
s="// JS_NULL_GUARD_V1 — querySelector/getElementById(...).addEventListener -> ?. (null-guard; view async yuklenirken baska ekrana geciste crash yok)\n"+s
open(F,"w",encoding="utf-8").write(s)
print(f"[ok] JS_NULL_GUARD_V1: querySelector {n1} + getElementById {n2} = {n1+n2} guard")
