#!/usr/bin/env python3
# Allow the daily-digest endpoint to be triggered via GET + ?key= (mirrors the
# existing alarm flush pattern, works with the container's wget).
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, t):
    global s
    assert s.count(a) == 1, "ABORT [%s]: count %d" % (t, s.count(a))
    s = s.replace(a, b); print("OK:", t)

rep('if (method === "POST" && path === "/api/saha/gunluk-ozet") {',
    'if ((method === "POST" || method === "GET") && path === "/api/saha/gunluk-ozet") {',
    "accept-get")
rep('try { secret = request.headers["x-ozet-secret"] || ""; } catch (e) {}',
    'try { secret = url.searchParams.get("key") || request.headers["x-ozet-secret"] || ""; } catch (e) {}',
    "secret-from-query")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
