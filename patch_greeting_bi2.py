# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# GREETING_BI2 — remove the client-side localStorage day-key gate on the CEO greeting.
# It blocked the greeting from firing (once set for the day) and is now redundant:
# the SERVER daily cache is the real gate (cache hit = cheap, miss = generate once).
# Keep the `!msgsEl.children.length` check so it won't re-greet mid-conversation.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/bi.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = (
"    var _brainDayKey = 'brain_greeted_' + new Date().toISOString().slice(0, 10);\n"
"    if (!msgsEl.children.length && !localStorage.getItem(_brainDayKey)) {\n"
"      localStorage.setItem(_brainDayKey, '1');"
)
NEW = "    if (!msgsEl.children.length) {"

c = s.count(OLD)
assert c == 1, "ABORT: greeting-gate anchor found %d" % c
s = s.replace(OLD, NEW)
print("OK: remove-client-gate")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
