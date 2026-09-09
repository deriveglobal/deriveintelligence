#!/usr/bin/env python3
# AI_TENANT_KANON_V1 — AI text-to-SQL prompt'larindaki gomulu KRB tenant literalini kaldirir.
# execute_query zaten $1'i session tenant'iyla degistiriyor (executeQueryTool); prompt literal yazdirmasin.
# 3 replace, count==1. KRB davranisi DEGISMEZ (session.tenantId zaten KRB). Cok-tenant guvenli.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
changes = []
def apply(name, new, old):
    global src
    if new in src:
        changes.append(f"SKIP (zaten var): {name}"); return
    c = src.count(old)
    assert c == 1, f"ANCHOR COUNT != 1 ({c}) : {name}"
    src = src.replace(old, new)
    changes.append(f"OK: {name}")

# 1) execute_query tool description: literal tenant -> $1 talimati
apply(
  "IT_AGENT execute_query desc",
  '      "Always filter EVERY table by the session tenant using the $1 placeholder: WHERE tenant_id = $1 (bi_satis_faturalari has TEXT tenant_id: WHERE tenant_id::text = $1). NEVER write a literal tenant UUID; $1 is auto-replaced with the caller\'s tenant. " +  /* AI_TENANT_KANON_V1 */',
  '      "Always filter by tenant: WHERE tenant_id = \'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa\'. " +',
)

# 2) input_schema sql description: literal -> $1
apply(
  "IT_AGENT sql schema desc",
  '          description: "SELECT SQL query. Filter EVERY table by the session tenant with the $1 placeholder (WHERE tenant_id = $1); $1 is auto-replaced with the caller\'s tenant UUID. Never embed a literal tenant UUID."  /* AI_TENANT_KANON_V1 */',
  '          description: "SELECT SQL query using literal tenant UUID in WHERE clauses. $1 placeholder is auto-replaced with tenant UUID."',
)

# 3) deptExtra.it context: literal tenant -> session.tenantId (buildDeptSystemPrompt scope'unda session VAR)
apply(
  "IT dept context Tenant satiri",
  "      'Tenant: ' + ((session && session.tenantId) || '$1 (oturum tenant — otomatik enjekte)') + '\\n\\n' +  /* AI_TENANT_KANON_V1 */",
  "      'Tenant: f8a5d20f-ecf8-4ce2-a492-69268fbb03fa\\n\\n' +",
)

if src == orig:
    print("DEGISIKLIK YOK")
else:
    bak = PATH + ".bak_aitenant_" + time.strftime("%Y%m%d_%H%M%S")
    shutil.copyfile(PATH, bak); print("YEDEK:", bak)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(src)
for c in changes: print(" ", c)
print("AI_TENANT_KANON_V1 marker:", src.count("AI_TENANT_KANON_V1"))
print("KRB uuid literal KALAN (0 olmali):", src.count("f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"))
