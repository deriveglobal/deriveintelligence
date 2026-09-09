# -*- coding: utf-8 -*-
# YAYIM_CLICK_V1 (mobil) — SON HIZLI DUYURULAR satirlari tiklanabilir: tam metin modal.
#   Ayrica template'e sizan "/* YAYIM_OKUNDU_V1 */" yorumunu da temizler (varsa).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "YAYIM_CLICK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

MAPBODY = '''          ${yayimlar.map(y => `<div style="font-size:12px;color:#713f12;padding:4px 0;border-bottom:1px solid #fef08a">${esc(y.icerik.slice(0,80))}${y.icerik.length>80?"…":""} <span style="color:#a16207">${_msgKisaTs(y.created_at)}</span>${y.okuyan!=null?` · <span style="color:#a16207">👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""}</span>`:""}</div>`).join("")}'''
NEWMAP = '''          ${yayimlar.map((y,yi) => `<div data-yidx="${yi}" style="cursor:pointer;font-size:12px;color:#713f12;padding:5px 0;border-bottom:1px solid #fef08a">${esc(y.icerik.slice(0,80))}${y.icerik.length>80?"…":""} <span style="color:#a16207">${_msgKisaTs(y.created_at)}</span>${y.okuyan!=null?` · <span style="color:#a16207">👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""}</span>`:""} <span style="color:#a16207">›</span></div>`).join("")}'''

# leaked-comment durumu ne olursa olsun (varsa da yoksa da) map'i degistir
if (MAPBODY + '  /* YAYIM_OKUNDU_V1 */') in s:
    s = s.replace(MAPBODY + '  /* YAYIM_OKUNDU_V1 */', NEWMAP, 1)
elif MAPBODY in s:
    s = s.replace(MAPBODY, NEWMAP, 1)
else:
    raise AssertionError("yayim map anchor bulunamadi")

# tikla handler (yayim-btn wiring'inden sonra)
OLD2 = '      main().querySelector("#yayim-btn")?.addEventListener("click", yayimMesajModal);'
NEW2 = '''      main().querySelector("#yayim-btn")?.addEventListener("click", yayimMesajModal);
      main().querySelectorAll("[data-yidx]").forEach(el => el.addEventListener("click", () => {  /* YAYIM_CLICK_V1 */
        const y = yayimlar[+el.dataset.yidx]; if (!y) return;
        modal(`<h3>📣 Hızlı Duyuru</h3>
          <div style="font-size:11px;color:#94a3b8;margin-bottom:8px">${_msgKisaTs(y.created_at)}${y.gonderen_adi ? " · " + esc(y.gonderen_adi) : ""}${y.okuyan!=null?` · 👁 ${y.okuyan}${rep_toplam?"/"+rep_toplam:""} okudu`:""}</div>
          <div style="white-space:pre-wrap;font-size:14px;line-height:1.6;color:#0f172a">${esc(y.icerik)}</div>
          <div class="modal-btnlar"><button class="btn gri" data-kapat>Kapat</button></div>`);
      }));'''
assert s.count(OLD2) == 1, "handler anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_CLICK_V1")
