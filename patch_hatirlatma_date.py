# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# HATIRLATMA_DATE_FIX — return hatirlatma_tarihi as 'YYYY-MM-DD' text (not an ISO
# timestamp) so the front stops showing "Invalid Date" and overdue/today logic works.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) Bugün reminders
rep("SELECT id, icerik, hatirlatma_tarihi FROM saha_rep_not",
    "SELECT id, icerik, to_char(hatirlatma_tarihi,'YYYY-MM-DD') AS hatirlatma_tarihi FROM saha_rep_not",
    "bugun-select")

# 2) Notlarım list
rep("SELECT id, icerik, hatirlatma_tarihi, tamamlandi, created_at, updated_at",
    "SELECT id, icerik, to_char(hatirlatma_tarihi,'YYYY-MM-DD') AS hatirlatma_tarihi, tamamlandi, created_at, updated_at",
    "notlar-select")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
