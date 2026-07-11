# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# REP_GATE — drop the client localStorage day-key gate on the rep greeting.
# Server cache is now the real gate (agent='rep'). Keep !histMsgs.length so it
# won't re-greet mid-conversation. (The leftover setItem becomes an unused no-op.)
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = "if (!histMsgs.length && !localStorage.getItem(todayKey)) {"
NEW = "if (!histMsgs.length) {"
c = s.count(OLD)
assert c == 1, "ABORT: rep gate anchor found %d" % c
s = s.replace(OLD, NEW)
print("OK: rep-gate-removed")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
