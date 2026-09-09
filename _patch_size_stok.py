import sys
F=sys.argv[1] if len(sys.argv)>1 else "/opt/krb-assessment/server_container.mjs"
s=open(F,encoding="utf-8").read()
old="""        WHERE sd.tenant_id = $1::uuid
          AND sd.export_date = (SELECT MAX(export_date) FROM bi_stok_durumu WHERE tenant_id = $1::uuid)
        GROUP BY 1"""
new="""        WHERE sd.tenant_id = $1::uuid
          AND sd.grup_adi ILIKE 'LASTIK%'
          AND sd.export_date = (SELECT MAX(export_date) FROM bi_stok_durumu WHERE tenant_id = $1::uuid)
        GROUP BY 1"""
if new in s:
    print("[size-stok] ZATEN filtreli — atlaniyor"); sys.exit(0)
c=s.count(old)
if c!=1:
    print("[size-stok] eslesme=%d (1 olmali) — DURDU"%c); sys.exit(2)
s=s.replace(old,new,1)
open(F,"w",encoding="utf-8").write(s)
print("[size-stok] OK — size-opportunities stok CTE LASTIK% filtrelendi")
