# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# CHECK_AUDIT_FIX — my first cut scanned the WHOLE file for `col = 'X'` without
# knowing which TABLE the statement targeted. `status`, `durum`, `tip` live on many
# tables with different allowed values -> 2882 false positives.
# Scope every literal to a statement that actually targets that table.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "saha_audit.py"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''# (b) SET col = 'X'  /  WHERE col = 'X'  — catches UPDATE and SELECT literals
for tbl, cols in _enum.items():
    if tbl not in src:
        continue
    for col, allowed in cols.items():
        for m in re.finditer(r"\\b%s\\s*=\\s*'([^']*)'" % re.escape(col), src):
            v = m.group(1)
            if v and v not in allowed:
                bad("%s.%s = '%s' ihlal; izinli: %s" % (tbl, col, v, "|".join(sorted(allowed))))
                _hits += 1''',
'''# (b) literals in UPDATE/SELECT/DELETE — but ONLY inside a statement that targets
# that table. (Scanning the whole file is meaningless: `status`/`durum`/`tip` exist
# on many tables with different allowed values.)
_seen = set()
for tbl, cols in _enum.items():
    if tbl not in src:
        continue
    for m in re.finditer(r"(?:FROM|INTO|UPDATE|JOIN)\\s+%s\\b" % re.escape(tbl), src):
        win = src[m.end(): m.end() + 400]
        # don't bleed past the end of the SQL string into surrounding JS
        for _stop in ("`", '";', "';", "\\n\\n"):
            _k = win.find(_stop)
            if _k != -1:
                win = win[:_k]
        for col, allowed in cols.items():
            for mm in re.finditer(r"\\b%s\\s*=\\s*'([^']*)'" % re.escape(col), win):
                v = mm.group(1)
                if not v or v in allowed:
                    continue
                key = (tbl, col, v)
                if key in _seen:
                    continue
                _seen.add(key)
                bad("%s.%s = '%s' ihlal; izinli: %s" % (tbl, col, v, "|".join(sorted(allowed))))
                _hits += 1''',
    "check-audit-table-scoped")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
