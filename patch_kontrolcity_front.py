# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# KONTROL_CITY_FRONT — show the customer's city + the suggested match's city on
# each Kontrol Bekleyen card, so location can be compared when deciding a match.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''          <div style="font-weight:600">${esc(m.firma)} <span style="color:#94a3b8;font-size:11px">· ${m.ziyaret_sayisi} ziyaret</span></div>
          ${m.notlar ? `<div style="font-size:11px;color:#64748b;margin:3px 0">${esc(m.notlar)}</div>` : ""}''',
'''          <div style="font-weight:600">${esc(m.firma)}${(m.il || m.ilce) ? ` <span style="color:#0f766e;font-size:11px">· 📍${esc([m.il, m.ilce].filter(Boolean).join(" / "))}</span>` : ""} <span style="color:#94a3b8;font-size:11px">· ${m.ziyaret_sayisi} ziyaret</span></div>
          ${m.oneri_firma
            ? `<div style="font-size:11px;color:#64748b;margin:3px 0">Olası eş: <b>${esc(m.oneri_firma)}</b>${m.oneri_il ? ` · 📍${esc(m.oneri_il)}` : ""} <span style="color:#94a3b8">(benzerlik ${m.oneri_skor ?? "-"})</span></div>`
            : (m.notlar ? `<div style="font-size:11px;color:#64748b;margin:3px 0">${esc(m.notlar)}</div>` : "")}''',
    "kontrol-city-render")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
