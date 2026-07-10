# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OKUNDU_INSERT_FIX — saha_duyuru_okundu has NO tenant_id column; the oku INSERT
# referenced it, so every read silently failed. Drop tenant_id from the insert.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = '''        `INSERT INTO saha_duyuru_okundu (duyuru_id, user_id, tenant_id)
         VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
        [m[1], session.userId, session.tenantId]'''
NEW = '''        `INSERT INTO saha_duyuru_okundu (duyuru_id, user_id)
         VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [m[1], session.userId]'''

c = s.count(OLD)
assert c == 1, "ABORT: okundu insert anchor found %d (need 1)" % c
s = s.replace(OLD, NEW)
print("OK: okundu-insert")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
