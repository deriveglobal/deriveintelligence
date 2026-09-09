import sys
F=sys.argv[1] if len(sys.argv)>1 else "/opt/krb-assessment/server_container.mjs"
s=open(F,encoding="utf-8").read()
old="FROM v_marj_cari_ay WHERE tenant_id=$1::uuid"
new="FROM v_marj_cari_ay WHERE tenant_id::text=$1"
c=s.count(old)
if c==0 and s.count(new)>=1:
    print("[hotfix] ZATEN DUZELTILMIS — atlaniyor"); sys.exit(0)
if c!=2:
    print("[hotfix] beklenen 2 eslesme, bulunan=%d — DURDU"%c); sys.exit(2)
s=s.replace(old,new)
open(F,"w",encoding="utf-8").write(s)
print("[hotfix] OK — v_marj_cari_ay okumalari tenant_id::text=$1 yapildi (2 yer)")
