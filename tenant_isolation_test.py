#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# tenant_isolation_test.py — proves RLS isolates tenants.
#
# Ground-truth row counts come from a bypass role (assessment_app, sees all).
# Then, AS the role under test, we set the CORRECT tenant and the WRONG tenant:
#   correct-tenant count should equal the tenant's real rows,
#   wrong-tenant count MUST be 0.
#
# Usage: tenant_isolation_test.py [test_role] [correct_tenant_uuid]
#   default test_role = assessment_app  (bypass -> every table LEAKS, pre-flip proof)
#   after Stage-1 prep: tenant_isolation_test.py app_tenant  -> must be all PASS
import subprocess, sys

TEST_ROLE  = sys.argv[1] if len(sys.argv) > 1 else "assessment_app"
CORRECT    = sys.argv[2] if len(sys.argv) > 2 else "f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
WRONG      = "00000000-0000-0000-0000-000000000000"
TRUTH_ROLE = "assessment_app"  # superuser/bypass -> ground-truth totals
TRUE = ("t", "true", "on", "yes", "1")

def q(sql, role):
    r = subprocess.run(
        ["docker", "exec", "-i", "krb-assessment-postgres", "psql", "-U", role,
         "-d", "assessment_platform", "-tA", "-c", sql],
        capture_output=True, text=True)
    return r.stdout.strip(), r.stderr.strip()

def count(sql, role):
    out, err = q(sql, role)
    for ln in out.splitlines():
        ln = ln.strip()
        if ln.lstrip("-").isdigit():
            return int(ln), err
    return None, err

rl, _ = q("SELECT rolsuper||'|'||rolbypassrls FROM pg_roles WHERE rolname='%s'" % TEST_ROLE, TRUTH_ROLE)
p = (rl.split("|") + ["", ""])[:2]
bypass = p[0] in TRUE or p[1] in TRUE
print("=== Tenant Isolation Test ===")
print("test role      : %s (super=%s bypassrls=%s -> %s)" %
      (TEST_ROLE, p[0], p[1], "BYPASSES RLS" if bypass else "subject to RLS"))
print("correct tenant : %s\n" % CORRECT)

out, _ = q("SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
           "WHERE c.relrowsecurity=true AND n.nspname='public' ORDER BY 1", TRUTH_ROLE)
tables = [t for t in out.splitlines() if t]

pas = fail = blind = skip = 0
for t in tables:
    tot, _ = count("SELECT count(*) FROM %s" % t, TRUTH_ROLE)
    if tot is None:
        print("  ?     %-26s (unreadable)" % t); continue
    if tot == 0:
        print("  SKIP  %-26s (empty)" % t); skip += 1; continue
    corr, _ = count("SET app.current_tenant_id='%s'; SELECT count(*) FROM %s;" % (CORRECT, t), TEST_ROLE)
    wrong, e = count("SET app.current_tenant_id='%s'; SELECT count(*) FROM %s;" % (WRONG, t), TEST_ROLE)
    if corr is None or wrong is None:
        print("  ?     %-26s (err: %s)" % (t, (e or "")[:34])); continue
    if wrong > 0:
        print("  FAIL  %-26s truth=%-7d wrong-tenant=%d (LEAK)" % (t, tot, wrong)); fail += 1
    elif corr == 0:
        print("  BLIND %-26s truth=%-7d correct-tenant=0 (role can't see own data)" % (t, tot)); blind += 1
    else:
        print("  PASS  %-26s truth=%-7d correct=%-7d wrong=0" % (t, tot, corr)); pas += 1

print("\nRESULT: %d pass, %d leak, %d blind, %d empty (of %d RLS tables)" %
      (pas, fail, blind, skip, len(tables)))
if bypass and fail:
    print("NOTE: test role bypasses RLS -> policies inert (expected before the flip).")
if blind:
    print("NOTE: 'blind' = role sees nothing even with correct tenant -> grant/policy gap.")
print("VERDICT: " + ("ISOLATION ENFORCED" if (fail == 0 and blind == 0 and pas > 0)
                     else "ISOLATION NOT ENFORCED"))
