#!/usr/bin/env python3
import sys, shutil
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/rep_gelisim_uret.mjs"
MARK = "CRON_MULTITENANT_REPGELISIM_V1"
s = open(PATH, encoding="utf-8").read()
if MARK in s:
    print("[=] Marker var — uygulanmis, cikiliyor (idempotent)."); sys.exit(0)
R = [
 ("const T = 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';",
  "const _tenants = (await pool.query(\"SELECT DISTINCT tenant_id AS t FROM rep_kimlik_koprusu WHERE durum='saha' AND user_id IS NOT NULL\")).rows; /* " + MARK + " */"),
 ("const reps = (await pool.query(\"SELECT user_id, sap_temsilci FROM rep_kimlik_koprusu WHERE tenant_id=$1 AND durum='saha' AND user_id IS NOT NULL AND sap_temsilci<>'Fatih Bilen'\",[T])).rows;\nlet uretilen=0, atlanan=0;\nfor (const r of reps) {",
  "let uretilen=0, atlanan=0;\nfor (const _tr of _tenants) { const T = _tr.t;\nconst reps = (await pool.query(\"SELECT user_id, sap_temsilci FROM rep_kimlik_koprusu WHERE tenant_id=$1 AND durum='saha' AND user_id IS NOT NULL AND sap_temsilci<>'Fatih Bilen'\",[T])).rows;\nfor (const r of reps) {"),
 ("}\nawait pool.end(); console.log('bitti. uretilen='+uretilen+' atlanan='+atlanan);",
  "}\n}\nawait pool.end(); console.log('bitti. uretilen='+uretilen+' atlanan='+atlanan);"),
]
for i,(o,n) in enumerate(R,1):
    c = s.count(o)
    if c != 1:
        print(f"[!] HATA R{i}: {c} eslesme (1 olmali). Iptal, dosya DEGISMEDI."); sys.exit(1)
bak = PATH + ".bak_mt"; shutil.copy2(PATH, bak); print("[+] Yedek:", bak)
for o,n in R: s = s.replace(o, n, 1)
open(PATH, "w", encoding="utf-8").write(s)
print("[OK] " + MARK + " uygulandi.")
