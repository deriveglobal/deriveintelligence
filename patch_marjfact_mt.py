#!/usr/bin/env python3
import sys, shutil
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/erp_ingest.py"
MARK = "MARJFACT_MULTITENANT_V1"
s = open(PATH, encoding="utf-8").read()
if MARK in s:
    print("[=] Marker var — uygulanmis, cikiliyor."); sys.exit(0)
R = [
 ('''                cur.execute("""
                    SELECT round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0), 1)
                      FROM bi_marj_fact
                     WHERE ay >= CURRENT_DATE-365 AND maliyet_kaynak <> 'yok'""")
                _e = cur.fetchone()''',
  '''                cur.execute("""
                    SELECT round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0), 1)
                      FROM bi_marj_fact
                     WHERE ay >= CURRENT_DATE-365 AND maliyet_kaynak <> 'yok'
                       AND tenant_id=%(t)s::text""", {"t": tenant_id})  # MARJFACT_MULTITENANT_V1
                _e = cur.fetchone()'''),
 ('''                    cur.execute("DROP TABLE IF EXISTS bi_marj_fact")
                    cur.execute("ALTER TABLE bi_marj_fact_yeni RENAME TO bi_marj_fact")
                    cur.execute("CREATE INDEX ON bi_marj_fact(tenant_id, ay DESC)")
                    cur.execute("CREATE INDEX ON bi_marj_fact(tenant_id, ebat_norm, marka)")
                    cur.execute("CREATE INDEX ON bi_marj_fact(tenant_id, sube, satis_kanali)")
                    cur.execute("CREATE INDEX ON bi_marj_fact(tenant_id, satis_temsilcisi)")
                    sonuc.append(f"marj_fact (%{m})")''',
  '''                    # MARJFACT_MULTITENANT_V1 — global DROP/RENAME yerine per-tenant DELETE+INSERT
                    cur.execute("CREATE TABLE IF NOT EXISTS bi_marj_fact (LIKE bi_marj_fact_yeni INCLUDING DEFAULTS)")
                    cur.execute("DELETE FROM bi_marj_fact WHERE tenant_id=%(t)s::text", {"t": tenant_id})
                    cur.execute("INSERT INTO bi_marj_fact SELECT * FROM bi_marj_fact_yeni")
                    cur.execute("DROP TABLE IF EXISTS bi_marj_fact_yeni")
                    sonuc.append(f"marj_fact (%{m}) [per-tenant]")'''),
]
for i,(o,n) in enumerate(R,1):
    if s.count(o)!=1:
        print(f"[!] HATA R{i}: {s.count(o)} eslesme. Iptal."); sys.exit(1)
bak=PATH+".bak_marjfact_mt"; shutil.copy2(PATH,bak); print("[+] Yedek:",bak)
for o,n in R: s=s.replace(o,n,1)
open(PATH,"w",encoding="utf-8").write(s); print("[OK]",MARK,"uygulandi.")
