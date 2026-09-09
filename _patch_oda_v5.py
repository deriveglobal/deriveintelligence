import sys
F="/opt/krb-assessment/server_container.mjs"; B="/opt/krb-assessment/_oda_endpoint.js"
s=open(F,encoding="utf-8").read()
if "FINANS_ODA_LIVE_V5" in s:
    print("[oda-v5] ZATEN V5 — atlaniyor"); sys.exit(0)
new=open(B,encoding="utf-8").read().rstrip("\n")
if "FINANS_ODA_LIVE_V5" not in new:
    print("[oda-v5] endpoint dosyasi V5 degil — DURDU"); sys.exit(2)

route_sig='if (request.method === "GET" && url.pathname === "/api/bi/finans/oda")'

if any(("FINANS_ODA_LIVE_V"+v) in s for v in ["1","2","3","4"]):
    # V1 mevcut -> V1 blogunu (yorum satiri + route if{}) yerinde V5 ile degistir
    m=-1
    for v in ["1","2","3","4"]:
        m=s.find("// === FINANS_ODA_LIVE_V"+v)
        if m!=-1: break
    ifpos=s.find(route_sig, m)
    if ifpos==-1: print("[oda-v5] V1 route bulunamadi — DURDU"); sys.exit(2)
    brace=s.find("{", ifpos)
    depth=0; i=brace; end=-1
    while i<len(s):
        c=s[i]
        if c=="{": depth+=1
        elif c=="}":
            depth-=1
            if depth==0: end=i+1; break
        i+=1
    if end==-1: print("[oda-v5] brace eslesmedi — DURDU"); sys.exit(2)
    linestart=s.rfind("\n",0,m)+1
    out=s[:linestart]+new+"\n"+s[end:]
    open(F,"w",encoding="utf-8").write(out)
    print("[oda-v5] OK — V1 blogu V5 ile degistirildi")
else:
    # V1 yok -> anchor'dan once ekle (ilk kurulum yolu)
    anchor='  // KOKPIT2_PREVIEW_ROUTE — yeni kokpit onizleme (canliya dokunmaz)'
    if s.count(anchor)!=1: print("[oda-v5] ANCHOR sayisi=%d — DURDU"%s.count(anchor)); sys.exit(2)
    open(F,"w",encoding="utf-8").write(s.replace(anchor, new+"\n"+anchor, 1))
    print("[oda-v5] OK — V5 ucu eklendi (V1 yoktu)")
