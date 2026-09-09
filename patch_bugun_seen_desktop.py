# -*- coding: utf-8 -*-
# BUGUN_ZIYARET_SEEN_V1 — Masaustu Bugun ekraninda gorulmemis ziyaretlere "● Yeni" rozeti +
#   sol mavi cizgi; ziyarete tiklayip acinca rozet aninda temizlenir (server /gordum zaten
#   kalici olarak "gordum" yazar; bu sadece gorsel aninda-guncelleme).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "BUGUN_ZIYARET_SEEN_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) ziyBody: gorulmemis ziyaret icin rozet + kenarlik
OLD1 = '''  const ziyBody = ziyaretler.length
    ? ziyaretler.map(z => `<div class="dk-row" data-zid="${esc(z.id)}" style="cursor:pointer">
        <div style="flex:1;min-width:0"><div class="firm">${esc(z.musteri_adi || "")}</div>
        ${z.adres ? `<div class="sub2">\U0001F4CD ${esc(z.adres)}</div>` : ""}</div>
        ${z.rep_adi ? `<span class="sub2">\U0001F464 ${esc(z.rep_adi)}</span>` : `<span class="pill p-info">Check-in</span>`}</div>`).join("")
    : `<div class="dk-empty-s">Bugün planlanmış ziyaret yok</div>`;'''
NEW1 = '''  const ziyBody = ziyaretler.length
    ? ziyaretler.map(z => `<div class="dk-row" data-zid="${esc(z.id)}" style="cursor:pointer${!z.gordum ? ";border-left:3px solid #0284c7" : ""}">
        <div style="flex:1;min-width:0"><div class="firm">${!z.gordum ? `<span data-nokta style="color:#0284c7">● </span>` : ""}${esc(z.musteri_adi || "")}</div>
        ${z.adres ? `<div class="sub2">\U0001F4CD ${esc(z.adres)}</div>` : ""}</div>
        ${!z.gordum ? `<span class="pill p-info" data-yeni>Yeni</span>` : ""}${z.rep_adi ? `<span class="sub2">\U0001F464 ${esc(z.rep_adi)}</span>` : `<span class="pill p-info">Check-in</span>`}</div>`).join("")  /* BUGUN_ZIYARET_SEEN_V1 */
    : `<div class="dk-empty-s">Bugün planlanmış ziyaret yok</div>`;'''
assert s.count(OLD1) == 1, "ziyBody anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) tikla handler: acinca rozeti aninda temizle
OLD2 = '    if (z) ziyaretDetay(z); else go("ziyaretler");'
NEW2 = '    if (z) { el.style.borderLeft = ""; const _n = el.querySelector("[data-nokta]"); if (_n) _n.remove(); const _y = el.querySelector("[data-yeni]"); if (_y) _y.remove(); ziyaretDetay(z); } else go("ziyaretler");  /* BUGUN_ZIYARET_SEEN_V1 */'
assert s.count(OLD2) == 1, "handler anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_ZIYARET_SEEN_V1")
