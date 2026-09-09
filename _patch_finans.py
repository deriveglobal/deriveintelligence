import sys
F="/opt/krb-assessment/server_container.mjs"
B="/opt/krb-assessment/_endpoint_block.js"
MARK="FINANS_TICARI_SERMAYE_V1"
s=open(F,encoding="utf-8").read()
if MARK in s:
    print("[patch] ZATEN YAMALI (marker mevcut) — atlaniyor"); sys.exit(0)
anchor='  // KOKPIT2_PREVIEW_ROUTE — yeni kokpit onizleme (canliya dokunmaz)'
n=s.count(anchor)
if n!=1:
    print("[patch] ANCHOR sayisi=%d (tam 1 olmali) — DURDURULDU, dosyaya dokunulmadi"%n); sys.exit(2)
ins=open(B,encoding="utf-8").read()
if not ins.endswith("\n"): ins+="\n"
s=s.replace(anchor, ins+anchor, 1)
open(F,"w",encoding="utf-8").write(s)
print("[patch] OK — uc+route blogu KOKPIT2 anchoru oncesine eklendi")
