# -*- coding: utf-8 -*-
# RAPOR_SPARK_HOVER_V1 (mobil) — Özet hero sparkline'a hover/dokun: dikey çizgi + tarih·ziyaret tooltip.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_SPARK_HOVER_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) CSS — spark konumlanabilir + crosshair çizgisi
c_old = ".rpc-spark{margin-top:10px}"
c_new = ".rpc-spark{margin-top:10px;position:relative;cursor:crosshair}\n        .rpc-xline{position:absolute;top:2px;bottom:2px;width:1px;background:#2563eb;opacity:0;pointer-events:none;transition:opacity .1s}/*RAPOR_SPARK_HOVER_V1*/"
assert s.count(c_old) == 1, "css anchor=%d" % s.count(c_old)
s = s.replace(c_old, c_new, 1)

# 2) hero markup — data-g (tarih+değer) + crosshair div
h_old = '${gunluk.length > 1 ? `<div class="rpc-spark">${_rpSpark(gunluk.map(g => Number(g.ziyaret) || 0))}</div>` : ""}'
h_new = '${gunluk.length > 1 ? `<div class="rpc-spark" data-g="${esc(JSON.stringify(gunluk.map(g => ({ t: String(g.tarih || "").slice(0,10), v: Number(g.ziyaret) || 0 }))))}">${_rpSpark(gunluk.map(g => Number(g.ziyaret) || 0))}<div class="rpc-xline"></div></div>` : ""}'
assert s.count(h_old) == 1, "hero anchor=%d" % s.count(h_old)
s = s.replace(h_old, h_new, 1)

# 3) _rpSparkWire tanımı — el2.innerHTML'den hemen önce
w_anchor = "      el2.innerHTML = `<!--RAPOR_UI_V1-->"
WIRE = r'''      const _rpSparkWire = (root) => {  /* RAPOR_SPARK_HOVER_V1 */
        let tp = document.getElementById("rpc-tip");
        if (!tp) { tp = document.createElement("div"); tp.id = "rpc-tip"; tp.className = "rpc-tip"; document.body.appendChild(tp); document.addEventListener("click", () => tp.classList.remove("show")); }
        root.querySelectorAll(".rpc-spark[data-g]").forEach((box) => {
          let g; try { g = JSON.parse(box.getAttribute("data-g")); } catch (e) { return; }
          if (!g || g.length < 2) return;
          const xl = box.querySelector(".rpc-xline");
          const at = (clientX) => {
            const r = box.getBoundingClientRect(); if (!r.width) return;
            let ratio = (clientX - r.left) / r.width; ratio = Math.max(0, Math.min(1, ratio));
            const idx = Math.round(ratio * (g.length - 1)), it = g[idx], p = String(it.t).split("-");
            if (xl) { xl.style.left = (idx / (g.length - 1) * 100) + "%"; xl.style.opacity = ".55"; }
            tp.innerHTML = "<b>" + (p.length === 3 ? p[2] + "." + p[1] + "." + p[0] : it.t) + "</b> · " + it.v + " ziyaret";
            tp.classList.add("show");
            const px = r.left + (idx / (g.length - 1)) * r.width;
            tp.style.left = Math.max(8, Math.min(window.innerWidth - tp.offsetWidth - 8, px - tp.offsetWidth / 2)) + "px";
            let top = r.top - tp.offsetHeight - 8; if (top < 8) top = r.bottom + 8;
            tp.style.top = top + "px";
          };
          const off = () => { if (xl) xl.style.opacity = "0"; tp.classList.remove("show"); };
          box.addEventListener("mousemove", (e) => at(e.clientX));
          box.addEventListener("mouseleave", off);
          box.addEventListener("touchstart", (e) => { if (e.touches[0]) at(e.touches[0].clientX); }, { passive: true });
          box.addEventListener("touchmove", (e) => { if (e.touches[0]) at(e.touches[0].clientX); }, { passive: true });
          box.addEventListener("touchend", off);
        });
      };
'''
assert s.count(w_anchor) == 1, "wire anchor=%d" % s.count(w_anchor)
s = s.replace(w_anchor, WIRE + w_anchor, 1)

# 4) çağrı — _rpTips(el2)'den sonra
call_old = "      _rpTips(el2);"
call_new = "      _rpTips(el2);\n      _rpSparkWire(el2);"
assert s.count(call_old) == 1, "call anchor=%d" % s.count(call_old)
s = s.replace(call_old, call_new, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_SPARK_HOVER_V1 (mobil)")
