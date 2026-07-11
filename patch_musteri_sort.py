# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# MUSTERI_SORT — Eftal: "customer list dates are shuffled".
# The list was ORDER BY m.firma (alphabetical) while the card shows the LAST VISIT
# date, so the dates looked random. Sort by last visit (most recent first);
# never-visited customers fall to the bottom, alphabetical as tiebreak.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'      sql += ` ORDER BY m.firma LIMIT 200`;',
'      sql += ` ORDER BY sz.son_ziyaret DESC NULLS LAST, m.firma ASC LIMIT 200`;',
    "musteri-order-by-son-ziyaret")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
