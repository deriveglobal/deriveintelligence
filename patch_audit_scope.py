# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# AUDIT_SCOPE — the body/readJson check used a fixed 15-line lookback, which
# false-positives on long handlers (the brain handlers parse `body` at the top,
# then use it 80-100 lines later inside the LLM/tool loop). Scope the lookback to
# the ENCLOSING HANDLER instead of a magic line count: correct, and still catches
# a genuine "used body without ever parsing it".
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "saha_audit.py"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''# each `... } = body;` or `body.<x>` occurrence: is there a readJson within 15 lines above?
lines = saha.splitlines()
for i, ln in enumerate(lines):
    if re.search(r"\\}\\s*=\\s*body;|=\\s*body\\.", ln) or re.search(r"\\bbody\\.\\w+", ln):
        window = "\\n".join(lines[max(0, i-15):i+1])
        if ("readJson(request)" not in window and "await new Promise" not in window
                and "for await" not in window and "JSON.parse" not in window
                and "readRawBody" not in window):
            bad("line uses `body` without readJson nearby: " + ln.strip()[:70])''',
'''# each `... } = body;` or `body.<x>` occurrence: was `body` parsed earlier in the
# SAME handler? (a fixed 15-line window false-positives on long handlers)
lines = saha.splitlines()
_HSTART = re.compile(r"if \\(method === ")
for i, ln in enumerate(lines):
    if re.search(r"\\}\\s*=\\s*body;|=\\s*body\\.", ln) or re.search(r"\\bbody\\.\\w+", ln):
        start = max(0, i - 400)
        for j in range(i, start, -1):
            if _HSTART.search(lines[j]):
                start = j
                break
        window = "\\n".join(lines[start:i+1])
        if ("readJson(request)" not in window and "await new Promise" not in window
                and "for await" not in window and "JSON.parse" not in window
                and "readRawBody" not in window):
            bad("line uses `body` without readJson in its handler: " + ln.strip()[:70])''',
    "audit-handler-scope")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
