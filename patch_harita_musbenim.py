# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
MARK = "HARITA_MUS_BENIM_V1"
REL = "server_container.mjs"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit
s = orig
edits = [
 ('B1',
  '      const hb = [session.tenantId];\n      let tipW = "";',
  '      const hb = [session.tenantId, session.userId];  /* HARITA_MUS_BENIM_V1 — $2 = benim */\n      let tipW = "";'),
 ('B2',
  '        "SELECT m.id, m.firma, m.tip, m.durum, m.il, m.ilce,"',
  '        "SELECT m.id, m.firma, m.tip, m.durum, m.il, m.ilce, (m.sorumlu_rep = $2) AS benim,"  /* HARITA_MUS_BENIM_V1 */'),
]
for name, old, new in edits:
    c = s.count(old)
    assert c == 1, "ANCHOR %s bulundu=%d" % (name, c)
    s = s.replace(old, new)
if not os.path.exists(path + ".musbenimbak"):
    with io.open(path + ".musbenimbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| BENIM:", s.count(MARK))
