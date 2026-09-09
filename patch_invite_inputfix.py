# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
MARK = "INVITE_INPUT_FIX_V1"
REL = "shells/tenant-admin.js"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit
OLD = r'''    .ta-input{width:100%;padding:11px 13px;border:1px solid #d7dbe3;border-radius:10px;font-size:14px;outline:none;background:#fff;transition:.14s}'''
NEW = r'''    .ta-input{width:100%;padding:11px 13px;border:1px solid #d7dbe3;border-radius:10px;font-size:14px;outline:none;background:#fff;color:#12182a;color-scheme:light;transition:.14s} /* INVITE_INPUT_FIX_V1 */
    .ta-input option{color:#12182a;background:#fff}'''
c = orig.count(OLD)
assert c == 1, "ANCHOR bulundu=%d" % c
s = orig.replace(OLD, NEW)
if not os.path.exists(path + ".invinputbak"):
    with io.open(path + ".invinputbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| MARK:", s.count(MARK))
