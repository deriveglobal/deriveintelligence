import sys
F="/opt/krb-assessment/server_container.mjs"; B="/opt/krb-assessment/_endpoint_block_v2.js"; MARK="FINANS_ODASI_V2"
s=open(F,encoding="utf-8").read()
if MARK in s: print("[srv] ZATEN YAMALI — atlaniyor"); sys.exit(0)
anchor='  // KOKPIT2_PREVIEW_ROUTE — yeni kokpit onizleme (canliya dokunmaz)'
n=s.count(anchor)
if n!=1: print("[srv] ANCHOR sayisi=%d (1 olmali) — DURDU"%n); sys.exit(2)
ins=open(B,encoding="utf-8").read()
if not ins.endswith("\n"): ins+="\n"
open(F,"w",encoding="utf-8").write(s.replace(anchor, ins+anchor, 1))
print("[srv] OK — v2 uc+shell (benzersiz yol + guard) eklendi")
