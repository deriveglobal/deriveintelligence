import sys
F="/opt/krb-assessment/server_container.mjs"; MARK="KOKPIT_BUAY_FIX_V1"
D="/opt/krb-assessment/"
s=open(F,encoding="utf-8").read()
if MARK in s: print("[kok] ZATEN YAMALI — atlaniyor"); sys.exit(0)
def rd(p): return open(D+p,encoding="utf-8").read()
oldF,newF,oldC,newC = rd("_kok_oldF.txt"),rd("_kok_newF.txt"),rd("_kok_oldC.txt"),rd("_kok_newC.txt")
nF=s.count(oldF); nC=s.count(oldC)
if nF!=1: print("[kok] _fWin anchor sayisi=%d (1 olmali) — DURDU, dokunulmadi"%nF); sys.exit(2)
if nC!=1: print("[kok] canli anchor sayisi=%d (1 olmali) — DURDU, dokunulmadi"%nC); sys.exit(3)
s=s.replace(oldF,newF,1).replace(oldC,newC,1)
open(F,"w",encoding="utf-8").write(s)
print("[kok] OK — _fWin ust-sinir + canli bos-ay guard eklendi (marker x2)")
