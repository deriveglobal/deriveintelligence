#!/usr/bin/env python3
# MODAL_LAYOUT_V1 — quote approval modal, proper on ANY screen:
#  - size columns to content (wider currency cols so ₺ values stop truncating,
#    tighter number cols) — fixes the cut-off on all screen sizes
#  - contain the table's horizontal scroll so it can never widen the modal
#  - responsive modal (full-width on phones) + sticky action buttons
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK (x%d): %s" % (c, tag))

# 1) column sizing to content (header + rows + footer share the same string ×3)
rep('28px 1fr 56px ${approverMode ? "80px 110px" : "80px 90px"} 90px 64px${approverMode ? " auto" : ""}',
    '24px minmax(52px,1fr) 32px ${approverMode ? "50px 64px" : "56px 80px"} 80px 88px${approverMode ? " auto" : ""}',
    "grid-sizing", n=3)

# 2) approval-discount input fits its column
rep('width:68px;padding:3px 6px;border:1px solid #cbd5e1',
    'width:56px;padding:3px 4px;border:1px solid #cbd5e1',
    "input-fit")

# 3) contain the table scroll so it never widens the modal
rep('<div style="overflow-x:auto;border-radius:8px;border:1px solid #e2e8f0">',
    '<div style="overflow-x:auto;max-width:100%;border-radius:8px;border:1px solid #e2e8f0">',
    "contain-scroll")

# 4) responsive modal + sticky action buttons
rep('.modal-kutu{background:#fff;color-scheme:light;border-radius:18px 18px 0 0;width:100%;max-width:min(95vw,760px);max-height:88vh;overflow-y:auto;padding:18px 16px 26px;color:#0f172a}',
    '.modal-kutu{background:#fff;color-scheme:light;border-radius:18px 18px 0 0;width:100%;max-width:min(95vw,760px);max-height:88vh;overflow-y:auto;padding:18px 16px 26px;color:#0f172a}\n  @media(max-width:640px){.modal-kutu{max-width:100vw;border-radius:14px 14px 0 0;max-height:92vh;padding:14px 10px 0}.modal-kutu .modal-btnlar{position:sticky;bottom:0;background:#fff;display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap;margin:10px -10px 0;padding:10px 10px calc(14px + env(safe-area-inset-bottom,0px));border-top:1px solid #eef2f6;z-index:5}}',
    "responsive-css")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
