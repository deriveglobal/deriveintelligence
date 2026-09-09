import sys
F="/opt/krb-assessment/server_container.mjs"; B="/opt/krb-assessment/_oda_endpoint.js"
s=open(F,encoding="utf-8").read()
if "FINANS_ODA_LIVE_V4" in s:
    print("[oda-v4] ZATEN V4 — atlaniyor"); sys.exit(0)
new=open(B,encoding="utf-8").read().rstrip("\n")
if "FINANS_ODA_LIVE_V4" not in new:
    print("[oda-v4] endpoint dosyasi V4 degil — DURDU"); sys.exit(2)

route_sig='if (request.method === "GET" && url.pathname === "/api/bi/finans/oda")'

if ("FINANS_ODA_LIVE_V1" in s) or ("FINANS_ODA_LIVE_V2" in s) or ("FINANS_ODA_LIVE_V3" in s):
    # V1 mevcut -> V1 blogunu (yorum satiri + route if{}) yerinde V4 ile degistir
    m=s.find("// === FINANS_ODA_LIVE_V1")
    if m==-1: m=s.find("// === FINANS_ODA_LIVE_V2")
    if m==-1: m=s.find("// === FINANS_ODA_LIVE_V3")
    ifpos=s.find(route_sig, m)
    if ifpos==-1: print("[oda-v4] V1 route bulunamadi — DURDU"); sys.exit(2)
    brace=s.find("{", ifpos)
    depth=0; i=brace; end=-1
    while i<len(s):
        c=s[i]
        if c=="{": depth+=1
        elif c=="}":
            depth-=1
            if depth==0: end=i+1; break
        i+=1
    if end==-1: print("[oda-v4] brace eslesmedi — DURDU"); sys.exit(2)
    linestart=s.rfind("\n",0,m)+1
    out=s[:linestart]+new+"\n"+s[end:]
    open(F,"w",encoding="utf-8").write(out)
    print("[oda-v4] OK — V1 blogu V4 ile degistirildi")
else:
    # V1 yok -> anchor'dan once ekle (ilk kurulum yolu)
    anchor='  // KOKPIT2_PREVIEW_ROUTE — yeni kokpit onizleme (canliya dokunmaz)'
    if s.count(anchor)!=1: print("[oda-v4] ANCHOR sayisi=%d — DURDU"%s.count(anchor)); sys.exit(2)
    open(F,"w",encoding="utf-8").write(s.replace(anchor, new+"\n"+anchor, 1))
    print("[oda-v4] OK — V4 ucu eklendi (V1 yoktu)")
