# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# GREETING_BI — bi.js: send is_greeting flag so the server can cache the CEO greeting.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/bi.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) sendBrainMsg accepts an isGreeting flag
rep("async function sendBrainMsg(msg) {",
    "async function sendBrainMsg(msg, isGreeting) {",
    "fn-sig")

# 2) pass the flag through to the server (anchor on the /api/brain/chat fetch to stay unique)
rep(
"""        const res = await fetch('/api/brain/chat', {
          method: 'POST', credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: msg })
        });""",
"""        const res = await fetch('/api/brain/chat', {
          method: 'POST', credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: msg, is_greeting: !!isGreeting })
        });""",
    "fn-body")

# 3) the daily greeting auto-send marks itself as a greeting
rep("zetle.'); }, 700);",
    "zetle.', true); }, 700);",
    "greet-call")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
