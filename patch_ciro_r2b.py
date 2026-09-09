import sys, shutil, time
F="/opt/krb-assessment/server_container.mjs"; MARK="RAPOR_R2B_CIRO"
s=open(F,encoding="utf-8").read()
if MARK in s: print("SKIP: marker zaten var (idempotent)"); sys.exit(0)
old="SELECT sorumlu_rep rep_id, COUNT(*) portfoy FROM saha_musteri\n           WHERE tenant_id=$1 AND aktif=true${portTip} GROUP BY sorumlu_rep"
new="SELECT sorumlu_rep rep_id, COUNT(*) portfoy FROM saha_musteri_kanon\n           WHERE tenant_id::text=$1::text${portTip} GROUP BY sorumlu_rep  /* RAPOR_R2B_CIRO: kanon aktif portfoy (Kural 3) */"
c=s.count(old)
if c!=1: print("ABORT: port CTE eslesme=",c,"beklenen=1 (dosya degismedi)"); sys.exit(4)
bak=F+".bak_r2bciro_"+str(int(time.time())); shutil.copy2(F,bak); print("BACKUP:",bak)
s=s.replace(old,new)
open(F,"w",encoding="utf-8").write(s)
print("YAZILDI. marker adedi (1 bekleniyor):", s.count(MARK))
