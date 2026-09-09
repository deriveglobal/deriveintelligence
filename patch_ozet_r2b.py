import sys, shutil, time
F="/opt/krb-assessment/server_container.mjs"; MARK="RAPOR_R2B_OZET"
s=open(F,encoding="utf-8").read()
if MARK in s: print("SKIP: marker zaten var (idempotent)"); sys.exit(0)
edits=[
 ("c1_tip_z_to_m",
  "if (tip) { params.push(tip); tipSql = ` AND z.tip = $${params.length}`; }",
  "if (tip) { params.push(tip); tipSql = ` AND m.tip = $${params.length}`; }  /* RAPOR_R2B_OZET: Kural 2 musteri segmenti m.tip */",1),
 ("c2_pay_aktif",
  "COUNT(DISTINCT z.musteri_id) FILTER (WHERE z.durum = 'TAMAMLANDI') AS benzersiz_nokta,",
  "COUNT(DISTINCT z.musteri_id) FILTER (WHERE z.durum = 'TAMAMLANDI' AND m.aktif = true) AS benzersiz_nokta,  /* RAPOR_R2B_OZET: kapsam payi aktif ile sinirli (>100% engeli) */",1),
 ("c3_gunluk_join",
  "FROM saha_ziyaret z\n        WHERE z.tenant_id = $1 AND COALESCE(z.ziyaret_tarihi, z.planlanan_tarih) BETWEEN $2 AND $3",
  "FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id = z.musteri_id  /* RAPOR_R2B_OZET */\n        WHERE z.tenant_id = $1 AND COALESCE(z.ziyaret_tarihi, z.planlanan_tarih) BETWEEN $2 AND $3",1),
 ("c4a_payda_view",
  "let pfSql = `SELECT count(*)::int AS n FROM saha_musteri m WHERE m.tenant_id=$1`;",
  "let pfSql = `SELECT count(*)::int AS n FROM saha_musteri_kanon m WHERE m.tenant_id::text=$1::text`;  /* RAPOR_R2B_OZET: Kural 3 payda kanon view (aktif=true) */",1),
 ("c4b_payda_rep",
  "if (session.sahaRole === \"rep\") { pfP.push(session.userId); pfSql += ` AND m.sorumlu_rep=$${pfP.length}`; }",
  "if (session.sahaRole === \"rep\") { pfP.push(session.userId); pfSql += ` AND m.sorumlu_rep::text=$${pfP.length}::text`; }  /* RAPOR_R2B_OZET */",1),
]
for name,old,new,exp in edits:
    c=s.count(old)
    if c!=exp: print("ABORT:",name,"eslesme=",c,"beklenen=",exp,"(dosya degismedi)"); sys.exit(4)
bak=F+".bak_r2bozet_"+str(int(time.time())); shutil.copy2(F,bak); print("BACKUP:",bak)
for name,old,new,exp in edits: s=s.replace(old,new); print("OK:",name)
open(F,"w",encoding="utf-8").write(s)
print("YAZILDI. marker adedi (5 bekleniyor):", s.count(MARK))
