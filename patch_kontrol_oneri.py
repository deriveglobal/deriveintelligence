import sys
F=sys.argv[1] if len(sys.argv)>1 else "server_container.mjs"
s=open(F,encoding="utf-8").read()
if "KONTROL_ONERI_ID_V1" in s: print("[skip] zaten var"); sys.exit(0)
def rep(old,new,tag):
    global s
    assert s.count(old)==1, "anchor %s count=%d"%(tag,s.count(old))
    s=s.replace(old,new,1); print("[ok]",tag)
# LATERAL inner select: id + kayit_kaynagi ekle
rep(
'''             SELECT x.firma, x.il
               FROM saha_musteri x''',
'''             SELECT x.id, x.firma, x.il, x.kayit_kaynagi
               FROM saha_musteri x''',
"lateral-select")
# outer select: oneri_id + oneri_kaynak ekle
rep(
'''                c.firma AS oneri_firma, c.il AS oneri_il,''',
'''                c.id AS oneri_id, c.kayit_kaynagi AS oneri_kaynak, c.firma AS oneri_firma, c.il AS oneri_il, /* KONTROL_ONERI_ID_V1 */''',
"outer-select")
open(F,"w",encoding="utf-8").write(s); print("[done] KONTROL_ONERI_ID_V1")
