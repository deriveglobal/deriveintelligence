# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# CHECK_AUDIT_HONEST — two checks with very different confidence, so treat them differently:
#
#   (a) INSERT INTO tbl (cols) VALUES (...)  -> literal mapped POSITIONALLY to its column.
#       Unambiguous. Zero false positives. -> FAIL.
#
#   (b) loose `col = 'X'` inside a table-scoped window.
#       CANNOT distinguish z.durum from m.durum without parsing SQL, and a migration's
#       WHERE legitimately references old values. -> WARN, never FAIL.
#       A hint for a human, not a verdict, and it must not be able to trip a crit alarm.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "saha_audit.py"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# (b): exclude alias-qualified columns (z.durum), and downgrade to WARN
rep(
'''        for col, allowed in cols.items():
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
'''        for col, allowed in cols.items():
            # (?<![.\\w]) — skip alias-qualified refs (z.durum belongs to another table)
            for mm in re.finditer(r"(?<![.\\w])%s\\s*=\\s*'([^']*)'" % re.escape(col), win):
                v = mm.group(1)
                if not v or v in allowed:
                    continue
                key = (tbl, col, v)
                if key in _seen:
                    continue
                _seen.add(key)
                # WARN, not FAIL: a migration's WHERE legitimately references old values,
                # and this scan cannot fully disambiguate joined tables.
                warn("%s.%s = '%s' (kontrol et); izinli: %s" % (tbl, col, v, "|".join(sorted(allowed))))''',
    "loose-scan-to-warn")

# make the summary line reflect that only (a) is authoritative
rep(
'''if _hits == 0:
    ok("tum sabit enum degerleri CHECK kisitlariyla uyumlu (%d tablo tarandi)" % len(_enum))''',
'''if _hits == 0:
    ok("INSERT sabit enum degerleri CHECK kisitlariyla uyumlu (%d tablo tarandi)" % len(_enum))''',
    "summary-wording")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
