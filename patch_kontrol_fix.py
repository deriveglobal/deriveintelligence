import sys
F=sys.argv[1] if len(sys.argv)>1 else "server_container.mjs"
s=open(F,encoding="utf-8").read()
if "KONTROL_FIX_V1" in s: print("[skip] zaten var"); sys.exit(0)
def rep(old,new,tag):
    global s
    assert s.count(old)==1, "anchor %s count=%d"%(tag,s.count(old))
    s=s.replace(old,new,1); print("[ok]",tag)

# FIX 1: ana müşteri listesinden KONTROL bekleyenleri çıkar (panelde görünüyorlar; listede tekrar etmesin)
rep(
'''        WHERE m.tenant_id = $1 AND m.aktif = true`;''',
'''        WHERE m.tenant_id = $1 AND m.aktif = true AND COALESCE(m.kayit_kaynagi,'') <> 'EXCEL_IMPORT_KONTROL'`; /* KONTROL_FIX_V1 */''',
"liste-exclude")

# FIX 2: kontrol öneri LATERAL — kardeş (aynı isim, başka şube) birbirini görsün + 0.4 altı çöp öneriyi gösterme
rep(
'''              WHERE x.tenant_id=m.tenant_id AND x.aktif=true AND x.id<>m.id
                AND x.kayit_kaynagi<>'EXCEL_IMPORT_KONTROL'
              ORDER BY similarity(m.firma, x.firma) DESC''',
'''              WHERE x.tenant_id=m.tenant_id AND x.aktif=true AND x.id<>m.id
                AND similarity(m.firma, x.firma) >= 0.4 /* KONTROL_FIX_V1: çöp eşik + kardeş şube görünür */
              ORDER BY similarity(m.firma, x.firma) DESC''',
"oneri-threshold")

open(F,"w",encoding="utf-8").write(s)
print("[done] KONTROL_FIX_V1")
