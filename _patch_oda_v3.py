import sys
F="/opt/krb-assessment/server_container.mjs"; B="/opt/krb-assessment/_oda_endpoint.js"
s=open(F,encoding="utf-8").read()
if "FINANS_ODA_LIVE_V3" in s:
    print("[oda-v3] ZATEN V3 — atlaniyor"); sys.exit(0)
new=open(B,encoding="utf-8").read().rstrip("\n")
if "FINANS_ODA_LIVE_V3" not in new:
    print("[oda-v3] endpoint dosyasi V3 degil — DURDU"); sys.exit(2)

route_sig='if (request.method === "GET" && url.pathname === "/api/bi/finans/oda")'

if ("FINANS_ODA_LIVE_V1" in s) or ("FINANS_ODA_LIVE_V2" in s):
    # V1 mevcut -> V1 blogunu (yorum satiri + route if{}) yerinde V3 ile degistir
    m=s.find("// === FINANS_ODA_LIVE_V1");
    if m==-1: m=s.find("// === FINANS_ODA_LIVE_V2")
    ifpos=s.find(route_sig, m)
    if ifpos==-1: print("[oda-v3] V1 route bulunamadi — DURDU"); sys.exit(2)
    brace=s.find("{", ifpos)
    depth=0; i=brace; end=-1
    while i<len(s):
        c=s[i]
        if c=="{": depth+=1
        elif c=="}":
            depth-=1
            if depth==0: end=i+1; break
        i+=1
    if end==-1: print("[oda-v3] brace eslesmedi — DURDU"); sys.exit(2)
    linestart=s.rfind("\n",0,m)+1
    out=s[:linestart]+new+"\n"+s[end:]
    open(F,"w",encoding="utf-8").write(out)
    print("[oda-v3] OK — V1 blogu V3 ile degistirildi")
else:
    # V1 yok -> anchor'dan once ekle (ilk kurulum yolu)
    anchor='  // KOKPIT2_PREVIEW_ROUTE — yeni kokpit onizleme (canliya dokunmaz)'
    if s.count(anchor)!=1: print("[oda-v3] ANCHOR sayisi=%d — DURDU"%s.count(anchor)); sys.exit(2)
    open(F,"w",encoding="utf-8").write(s.replace(anchor, new+"\n"+anchor, 1))
    print("[oda-v3] OK — V3 ucu eklendi (V1 yoktu)")
