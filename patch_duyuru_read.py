# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# DUYURU_READ_UI — after opening a post (marks read), refresh the current view so
# the "Yeni" badge/counts update; and show the "who saw" reader list to everyone.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) refresh Bugün/Duyurular after marking read
rep('  api(`/api/saha/duyurular/${did}/oku`, { method: "PUT", body: "{}" }).catch(() => {});',
    '  api(`/api/saha/duyurular/${did}/oku`, { method: "PUT", body: "{}" }).then(() => { if (S.view === "bugun" || S.view === "duyurular") loadView(S.view); }).catch(() => {});',
    "refresh-after-read")

# 2) show "who saw" to all roles (not just managers)
rep('      ${S.role !== "rep" && okuyanlar.length ? `<div style="font-size:12px;color:#64748b;margin-bottom:12px">👁 <b>${okuyanlar.length}</b> kişi okudu: ${okuyanlar.map(o => esc(o.full_name)).join(", ")}</div>` : ""}',
    '      ${okuyanlar.length ? `<div style="font-size:12px;color:#64748b;margin-bottom:12px">👁 <b>${okuyanlar.length}</b> kişi okudu: ${okuyanlar.map(o => esc(o.full_name)).join(", ")}</div>` : ""}',
    "who-saw-all")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
