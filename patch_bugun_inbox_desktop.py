# -*- coding: utf-8 -*-
# BUGUN_INBOX_V1 (desktop) — Bugun "Bugunun Ziyaretleri" artik bir OKUNMAMIS gelen-kutusu:
#   sadece gorulmemis ziyaretler listelenir; bir ziyaret acilinca (gordum) listeden ANINDA
#   dusr. Ziyaretler sekmesi tum ziyaretleri gostermeye devam eder (degismez).
#   Not: liste zaten "okunmamis"lardan olustugu icin satir-basi "Yeni" rozeti/mavi cizgi
#   kaldirildi (gereksiz tekrar); okunmamislik artik kartta bulunmakla ifade edilir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "BUGUN_INBOX_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) ziyBody -> gorulmemis filtre + temiz liste
OLD1 = '''  const ziyBody = ziyaretler.length
    ? ziyaretler.map(z => `<div class="dk-row" data-zid="${esc(z.id)}" style="cursor:pointer${!z.gordum ? ";border-left:3px solid #0284c7" : ""}">
        <div style="flex:1;min-width:0"><div class="firm">${!z.gordum ? `<span data-nokta style="color:#0284c7">● </span>` : ""}${esc(z.musteri_adi || "")}</div>
        ${z.adres ? `<div class="sub2">\U0001F4CD ${esc(z.adres)}</div>` : ""}</div>
        ${!z.gordum ? `<span class="pill p-info" data-yeni>Yeni</span>` : ""}${z.rep_adi ? `<span class="sub2">\U0001F464 ${esc(z.rep_adi)}</span>` : `<span class="pill p-info">Check-in</span>`}</div>`).join("")  /* BUGUN_ZIYARET_SEEN_V1 */
    : `<div class="dk-empty-s">Bugün planlanmış ziyaret yok</div>`;'''
NEW1 = '''  const gorulmemis = ziyaretler.filter(z => !z.gordum);  /* BUGUN_INBOX_V1: gorulmus ziyaretler Bugun'den dusr, Ziyaretler'de kalir */
  const ziyBody = gorulmemis.length
    ? gorulmemis.map(z => `<div class="dk-row" data-zid="${esc(z.id)}" style="cursor:pointer">
        <div style="flex:1;min-width:0"><div class="firm">${esc(z.musteri_adi || "")}</div>
        ${z.adres ? `<div class="sub2">\U0001F4CD ${esc(z.adres)}</div>` : ""}</div>
        ${z.rep_adi ? `<span class="sub2">\U0001F464 ${esc(z.rep_adi)}</span>` : `<span class="pill p-info">Check-in</span>`}</div>`).join("")
    : `<div class="dk-empty-s">Tüm bugünkü ziyaretler görüldü ✓</div>`;'''
assert s.count(OLD1) == 1, "ziyBody anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) stat alt yazisi -> gorulmemis sayisi
OLD2 = '        ${stat("Bugünkü Ziyaret", String(ziyaretler.length), ziyaretler.length ? "planlı/tamam" : "yok")}'
NEW2 = '        ${stat("Bugünkü Ziyaret", String(ziyaretler.length), gorulmemis.length ? gorulmemis.length + " görülmemiş" : "hepsi görüldü ✓")}'
assert s.count(OLD2) == 1, "stat anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# 3) kart basligi sayaci -> gorulmemis
OLD3 = '        <div class="dk-card"><div class="dk-card-h"><h3>Bugünün Ziyaretleri</h3><span class="sub">${ziyaretler.length}</span></div>${ziyBody}</div>'
NEW3 = '        <div class="dk-card"><div class="dk-card-h"><h3>Bugünün Ziyaretleri</h3><span class="sub">${gorulmemis.length}</span></div>${ziyBody}</div>'
assert s.count(OLD3) == 1, "kart anchor count=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# 4) tikla handler -> acinca satiri listeden cikar + sayaci guncelle
OLD4 = '  if (z) { el.style.borderLeft = ""; const _n = el.querySelector("[data-nokta]"); if (_n) _n.remove(); const _y = el.querySelector("[data-yeni]"); if (_y) _y.remove(); ziyaretDetay(z); } else go("ziyaretler");  /* BUGUN_ZIYARET_SEEN_V1 */'
NEW4 = '  if (z) { const _card = el.closest(".dk-card"); ziyaretDetay(z); el.remove(); if (_card) { const _kalan = _card.querySelectorAll("[data-zid]").length; const _sub = _card.querySelector(".dk-card-h .sub"); if (_sub) _sub.textContent = String(_kalan); if (!_kalan && !_card.querySelector(".dk-empty-s")) { const _e = document.createElement("div"); _e.className = "dk-empty-s"; _e.textContent = "Tüm bugünkü ziyaretler görüldü ✓"; _card.appendChild(_e); } } } else go("ziyaretler");  /* BUGUN_INBOX_V1 */'
assert s.count(OLD4) == 1, "handler anchor count=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_INBOX_V1")
