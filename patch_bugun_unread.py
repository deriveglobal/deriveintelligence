# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# BUGUN_UNREAD_UNIFY — Bugün shows unread-only announcements for EVERYONE (was
# recent-for-managers, which made them look perpetually unread). Reading clears it.
srv = "server_container.mjs"
s = open(srv, encoding="utf-8").read(); o1 = len(s)
OLD_S = 'const _dq = _isRep ? (_base + " AND NOT EXISTS(SELECT 1 FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id AND o.user_id=$2) ORDER BY d.created_at DESC LIMIT 10") : (_base + " ORDER BY d.created_at DESC LIMIT 6");'
NEW_S = 'const _dq = _base + " AND NOT EXISTS(SELECT 1 FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id AND o.user_id=$2) ORDER BY d.created_at DESC LIMIT 10";'
assert s.count(OLD_S) == 1, "ABORT server: found %d" % s.count(OLD_S)
s = s.replace(OLD_S, NEW_S)
open(srv, "w", encoding="utf-8").write(s)
print("OK: server-unify (%d -> %d)" % (o1, len(s)))

fr = "shells/saha.js"
f = open(fr, encoding="utf-8").read(); o2 = len(f)
OLD_F = 'empty(S.role === "rep" ? "Okunmamış duyuru yok ✓" : "Henüz duyuru yok")'
NEW_F = 'empty("Okunmamış duyuru yok ✓")'
assert f.count(OLD_F) == 1, "ABORT front: found %d" % f.count(OLD_F)
f = f.replace(OLD_F, NEW_F)
open(fr, "w", encoding="utf-8").write(f)
print("OK: front-empty (%d -> %d)" % (o2, len(f)))
