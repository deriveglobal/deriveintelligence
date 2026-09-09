# -*- coding: utf-8 -*-
# YAYIM_CLICK_DK_V1 (masaustu) — Son Hızlı Duyurular satirlari tiklanabilir: tam metin modal.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "YAYIM_CLICK_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD1 = '${yayimlar.map(y => `<div class="sub2" style="padding:3px 0">${esc(y.icerik.slice(0, 90))}${y.icerik.length > 90 ? "…" : ""} · ${_dkKisaTs(y.created_at)}${y.okuyan!=null?` · 👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""}`:""}</div>`).join("")}'
NEW1 = '${yayimlar.map((y,yi) => `<div data-yidx="${yi}" class="sub2" style="padding:4px 0;cursor:pointer">${esc(y.icerik.slice(0, 90))}${y.icerik.length > 90 ? "…" : ""} · ${_dkKisaTs(y.created_at)}${y.okuyan!=null?` · 👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""}`:""} ›</div>`).join("")}'
assert s.count(OLD1) == 1, "map anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

OLD2 = '  m.querySelector("#msg-yayim").addEventListener("click", yayimMesaj);'
NEW2 = '''  m.querySelector("#msg-yayim").addEventListener("click", yayimMesaj);
  m.querySelectorAll("[data-yidx]").forEach(el => el.addEventListener("click", () => {  /* YAYIM_CLICK_DK_V1 */
    const y = yayimlar[+el.dataset.yidx]; if (!y) return;
    dkModal(`<div class="dk-det-head"><h3>📣 Hızlı Duyuru</h3><button class="dk-x" data-kapat>✕</button></div>
      <div class="sub2" style="margin:2px 0 8px">${_dkKisaTs(y.created_at)}${y.gonderen_adi ? " · " + esc(y.gonderen_adi) : ""}${y.okuyan!=null?` · 👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""} okudu`:""}</div>
      <div style="white-space:pre-wrap;font-size:14px;line-height:1.6">${esc(y.icerik)}</div>
      <div class="dk-det-alt"><button class="dk-btn" data-kapat>Kapat</button></div>`);
  }));'''
assert s.count(OLD2) == 1, "handler anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_CLICK_DK_V1")
