# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
MARK = "PTR_OFF_V1"
REL = "shells/saha.js"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit
old = '''    if (window.__sahaPTR) return;
    window.__sahaPTR = 1;'''
new = '''    if (window.__sahaPTR) return;
    window.__sahaPTR = 1;
    return; /* PTR_OFF_V1 — aşağı-çek-yenile kapatıldı (reload=oturum uçuyordu); yerine header 🔄 */'''
c = orig.count(old)
assert c == 1, "ANCHOR bulundu=%d" % c
s = orig.replace(old, new)
if not os.path.exists(path + ".ptroffbak"):
    with io.open(path + ".ptroffbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| PTR_OFF:", s.count(MARK))
