# -*- coding: utf-8 -*-
# IK_LOCK_V1 — Ik Odasi erisimini matrise al: modul-admin bypass'i IK icin gecersiz;
# yalniz platform_owner + acik 'ikodasi' capi. Iki uc (shell + data). Idempotent, .iklockbak.
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
REL = "server_container.mjs"
MARK = "IK_LOCK_V1"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit
def lock(v):
    return (' /* IK_LOCK_V1 */ if (%s) { const _po = normalizeRole(%s.role) === "platform_owner";'
            ' const _c = (%s.permissions && Array.isArray(%s.permissions.departments)) ? %s.permissions.departments : [];'
            ' if (!_po && !_c.includes("ikodasi")) %s = null; }') % (v, v, v, v, v, v)
A1 = 'let _isess = await requireBiDept(request, "ikodasi").catch(() => null);'
A2 = 'let session = await requireBiDept(request, "ikodasi").catch(() => null);'
assert orig.count(A1) == 1, "A1=%d" % orig.count(A1)
assert orig.count(A2) == 1, "A2=%d" % orig.count(A2)
s = orig.replace(A1, A1 + lock("_isess"), 1).replace(A2, A2 + lock("session"), 1)
if not os.path.exists(path + ".iklockbak"):
    with io.open(path + ".iklockbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| MARK:", s.count(MARK))
