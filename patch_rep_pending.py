#!/usr/bin/env python3
# REP_PENDING_V1 — reps could not see their ONAY_BEKLIYOR quotes: the pending
# section in vIskonto was gated on `yonetici`. Show it to reps too (status only;
# approve/reject buttons remain manager-only in teklifKart).
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK: %s" % tag)

# show the pending section to reps too
rep("${yonetici && bekleyenler.length ?",
    "${bekleyenler.length ?",
    "ungate-pending")

# rep-appropriate heading (they're not approving, just tracking)
rep('⏳ Onay Bekleyen (${bekleyenler.length})</h4>',
    '⏳ ${yonetici ? "Onay Bekleyen" : "Onay Bekleniyor — yönetici onayında"} (${bekleyenler.length})</h4>',
    "rep-heading")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
