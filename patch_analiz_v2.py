#!/usr/bin/env python3
# ANALIZ_V2 — margin shows both (% + ₺/adet); per-line market empty-state reworded
# to "Piyasa verisi yok"; rep's stated rival surfaced on the matching product line.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK: %s" % tag)

# A) reword per-line market empty-state (distinct from the top rep-rival one)
rep('margin-top:3px;color:#94a3b8;font-style:italic">Rakip bilgisi girilmemiş.',
    'margin-top:3px;color:#94a3b8;font-style:italic">Piyasa/e-ticaret verisi yok.',
    "reword-market")

# B) margin: show both % and profit per unit
rep(' · Marj: <b style="color:${marjColor}">${marjStr}</b></div>',
    ' · Marj: <b style="color:${marjColor}">${marjStr}</b>${(k.talep_fiyat != null && k.birim_maliyet != null) ? ` · Kâr: <b>₺${Math.round(k.talep_fiyat - k.birim_maliyet).toLocaleString("tr-TR")}/adet</b>` : ""}</div>',
    "margin-both")

# C1) helpers: normalize + match rep rivals to a line's ebat
rep('  const rr = az.rep_rakip || [];\n  const headerR = az.header_rakip;',
    r'''  const rr = az.rep_rakip || [];
  const headerR = az.header_rakip;
  const _nz = e => String(e || "").toLowerCase().replace(/\s/g, "");
  const _rrEbat = eb => rr.filter(x => x.ebat && _nz(x.ebat) === _nz(eb));
  const _rrTop = rr.filter(x => !x.ebat || !(az.kalemler || []).some(k => _nz(k.ebat) === _nz(x.ebat)));
  const _rivalStr = x => (x.marka || "Rakip") + (x.ebat ? (" " + x.ebat) : "") + (x.fiyat != null ? (" · " + tl(x.fiyat)) : " · fiyat yok") + (x.supheli ? " ⚠ şüpheli" : "");''',
    "helpers")

# C2) top block shows only rivals not matched to a line
rep(r'''  if (rr.length || headerR) {
    const items = [];
    if (headerR) items.push((headerR.marka || "Rakip") + (headerR.fiyat != null ? (" · " + tl(headerR.fiyat)) : ""));
    rr.forEach(x => items.push((x.marka || "Rakip") + (x.ebat ? (" " + x.ebat) : "") + (x.fiyat != null ? (" · " + tl(x.fiyat)) : "") + (x.supheli ? " ⚠ şüpheli olabilir" : "")));
    repRakipHTML = `<div style="font-size:12px;color:#0f172a">${items.map(esc).join("<br>")}</div>`;
  } else {''',
    r'''  if (_rrTop.length || headerR) {
    const items = [];
    if (headerR) items.push((headerR.marka || "Rakip") + (headerR.fiyat != null ? (" · " + tl(headerR.fiyat)) : ""));
    _rrTop.forEach(x => items.push(_rivalStr(x)));
    repRakipHTML = `<div style="font-size:12px;color:#0f172a">${items.map(esc).join("<br>")}</div>`;
  } else {''',
    "top-unmatched")

# C3) per-line matched rival, shown above the market block
rep('        ${hasRival',
    '        ${_rrEbat(k.ebat).length ? `<div style="margin-top:3px;color:#b45309;font-weight:600">🏁 Temsilci: ${_rrEbat(k.ebat).map(_rivalStr).map(esc).join(" · ")}</div>` : ""}\n        ${hasRival',
    "per-line-rival")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
