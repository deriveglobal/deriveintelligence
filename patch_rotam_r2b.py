import sys, shutil, time
F="/opt/krb-assessment/server_container.mjs"; MARK="RAPOR_R2B_ROTAM"
s=open(F,encoding="utf-8").read()
if MARK in s: print("SKIP: marker zaten var (idempotent)"); sys.exit(0)
edits=[
 ("e1_mgr_ciro_son_cte",
  "ciro AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_kodu),\n               son AS (SELECT musteri_id, MAX(ziyaret_tarihi) mx FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' GROUP BY musteri_id),",
  "ciro AS (SELECT musteri_id, ciro_12ay yil FROM saha_musteri_kanon WHERE tenant_id::text=$1::text),  /* RAPOR_R2B_ROTAM: kanon ciro_12ay */\n               son AS (SELECT musteri_id, son_ziyaret mx FROM saha_musteri_kanon WHERE tenant_id::text=$1::text),  /* RAPOR_R2B_ROTAM: kanon son_ziyaret */",1),
 ("e2_mgr_ciro_join_block",
  "LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu\n            LEFT JOIN son s ON s.musteri_id=m.id\n            LEFT JOIN tek t ON t.musteri_id=m.id\n            LEFT JOIN plani p ON p.musteri_id=m.id",
  "LEFT JOIN ciro c ON c.musteri_id=m.id  /* RAPOR_R2B_ROTAM */\n            LEFT JOIN son s ON s.musteri_id=m.id\n            LEFT JOIN tek t ON t.musteri_id=m.id\n            LEFT JOIN plani p ON p.musteri_id=m.id",1),
 ("e3_rep_son",
  "(SELECT MAX(z.ziyaret_tarihi) FROM saha_ziyaret z WHERE z.tenant_id::text=$1::text AND z.musteri_id=m.id AND z.durum='TAMAMLANDI') AS son_ziyaret,",
  "(SELECT k.son_ziyaret FROM saha_musteri_kanon k WHERE k.tenant_id::text=$1::text AND k.musteri_id=m.id) AS son_ziyaret,  /* RAPOR_R2B_ROTAM */",1),
 ("e4_rep_ciro",
  "COALESCE((SELECT SUM(f.satir_tutar) FROM bi_satis_faturalari f WHERE f.tenant_id::text=$1::text AND f.musteri_kodu=m.musteri_kodu AND f.fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days')), 0)::numeric AS ciro,",
  "COALESCE((SELECT k.ciro_12ay FROM saha_musteri_kanon k WHERE k.tenant_id::text=$1::text AND k.musteri_id=m.id), 0)::numeric AS ciro,  /* RAPOR_R2B_ROTAM */",1),
]
for name,old,new,exp in edits:
    c=s.count(old)
    if c!=exp: print("ABORT:",name,"eslesme=",c,"beklenen=",exp,"(dosya degismedi)"); sys.exit(4)
bak=F+".bak_r2brotam_"+str(int(time.time())); shutil.copy2(F,bak); print("BACKUP:",bak)
for name,old,new,exp in edits: s=s.replace(old,new); print("OK:",name)
open(F,"w",encoding="utf-8").write(s)
print("YAZILDI. marker adedi (5 bekleniyor):", s.count(MARK))
