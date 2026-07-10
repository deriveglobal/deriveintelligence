# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OKU_FIX — mark-as-read: server accepts POST+PUT on /oku; front marks read for
# all roles (was rep-only + method mismatch, so reads never registered).
import sys

srv = "server_container.mjs"
s = open(srv, encoding="utf-8").read(); o1 = len(s)
OLD_S = '    if (method === "PUT" && (m = path.match(/^\\/api\\/saha\\/duyurular\\/([0-9a-f-]{36})\\/oku$/))) {'
NEW_S = '    if ((method === "PUT" || method === "POST") && (m = path.match(/^\\/api\\/saha\\/duyurular\\/([0-9a-f-]{36})\\/oku$/))) {'
c = s.count(OLD_S)
assert c == 1, "ABORT server oku: found %d" % c
s = s.replace(OLD_S, NEW_S)
open(srv, "w", encoding="utf-8").write(s)
print("OK: server-oku  (%d -> %d)" % (o1, len(s)))

fr = "shells/saha.js"
f = open(fr, encoding="utf-8").read(); o2 = len(f)
OLD_F = '  if (S.role === "rep") api(`/api/saha/duyurular/${did}/oku`, { method: "POST", body: "{}" }).catch(() => {});'
NEW_F = '  api(`/api/saha/duyurular/${did}/oku`, { method: "PUT", body: "{}" }).catch(() => {});'
c2 = f.count(OLD_F)
assert c2 == 1, "ABORT front oku: found %d" % c2
f = f.replace(OLD_F, NEW_F)
open(fr, "w", encoding="utf-8").write(f)
print("OK: front-oku  (%d -> %d)" % (o2, len(f)))
