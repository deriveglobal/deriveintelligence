import sys
F="/opt/krb-assessment/server_container.mjs"; B="/opt/krb-assessment/_oda_endpoint.js"; MARK="FINANS_ODA_LIVE_V1"
s=open(F,encoding="utf-8").read()
if MARK in s: print("[oda] ZATEN YAMALI — atlaniyor"); sys.exit(0)
anchor='  // KOKPIT2_PREVIEW_ROUTE — yeni kokpit onizleme (canliya dokunmaz)'
if s.count(anchor)!=1: print("[oda] ANCHOR sayisi=%d (1 olmali) — DURDU"%s.count(anchor)); sys.exit(2)
ins=open(B,encoding="utf-8").read()
if not ins.endswith("\n"): ins+="\n"
open(F,"w",encoding="utf-8").write(s.replace(anchor, ins+anchor, 1))
print("[oda] OK — FINANS_ODA_LIVE_V1 ucu eklendi")
