#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# tenant_isolation_test.py — proves whether RLS actually isolates tenants.
#
# For each RLS-protected table: open a session, set a WRONG tenant context,
# then count rows. If data still shows, RLS is being bypassed (a leak).
#   wrong-tenant rows == 0 (while total > 0) -> PASS (RLS enforced)
#   wrong-tenant rows  > 0                    -> FAIL (leak / RLS bypassed)
#
# Usage:  python3 tenant_isolation_test.py [db_role]
#   default role = assessment_app (the app's current role -> should FAIL now).
#   After Stage 1, re-run as the new scoped role -> should PASS.
import subprocess, sys

ROLE = sys.argv[1] if len(sys.argv) > 1 else "assessment_app"
WRONG = "00000000-0000-0000-0000-000000000000"

def psql(sql, role=ROLE):
    r = subprocess.run(
        ["docker", "exec", "-i", "krb-assessment-postgres", "psql",
         "-U", role, "-d", "assessment_platform", "-tA", "-c", sql],
        capture_output=True, text=True)
    return r.stdout.strip(), r.stderr.strip(), r.returncode

def one_int(sql, role=ROLE):
    out, err, rc = psql(sql, role)
    for ln in out.splitlines():
        ln = ln.strip()
        if ln.lstrip("-").isdigit():
            return int(ln), err
    return None, err

print("=== Tenant Isolation Test — role: %s ===" % ROLE)
rl, _, _ = psql("SELECT rolname||'|'||rolsuper||'|'||rolbypassrls FROM pg_roles WHERE rolname='%s'" % ROLE)
parts = (rl.split("|") + ["", "", ""])[:3]
TRUE = ("t", "true", "on", "yes", "1")
bypass = (parts[1] in TRUE or parts[2] in TRUE)
print("role super=%s bypassrls=%s -> %s\n" % (parts[1], parts[2],
      "BYPASSES RLS (policies inert)" if bypass else "subject to RLS"))

out, _, _ = psql("SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
                 "WHERE c.relrowsecurity=true AND n.nspname='public' ORDER BY 1")
tables = [t for t in out.splitlines() if t]

pas = fail = skip = 0
for t in tables:
    total, _ = one_int("SELECT count(*) FROM %s" % t)
    if total is None:
        print("  ?    %-26s (unreadable)" % t); continue
    if total == 0:
        print("  SKIP %-26s (empty — cannot demonstrate)" % t); skip += 1; continue
    wrong, err = one_int("SET app.current_tenant_id = '%s'; SELECT count(*) FROM %s;" % (WRONG, t))
    if wrong is None:
        print("  ?    %-26s (err: %s)" % (t, (err or "")[:38])); continue
    if wrong == 0:
        print("  PASS %-26s total=%-6d wrong-tenant=0 (enforced)" % (t, total)); pas += 1
    else:
        print("  FAIL %-26s total=%-6d wrong-tenant=%d (LEAK)" % (t, total, wrong)); fail += 1

print("\nRESULT: %d enforced, %d leaking, %d empty (of %d RLS tables)" % (pas, fail, skip, len(tables)))
if bypass and fail:
    print("ROOT CAUSE: role '%s' bypasses RLS -> every policy is inert." % ROLE)
    print("STAGE-1 FIX: run app/agent queries under a NON-superuser NON-bypassrls role")
    print("            + SET app.current_tenant_id per request; extend policies to saha_* tables.")
print("VERDICT: " + ("ISOLATION ENFORCED" if fail == 0 and pas > 0 else "ISOLATION NOT ENFORCED"))
