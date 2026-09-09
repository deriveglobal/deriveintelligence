# -*- coding: utf-8 -*-
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "FOTO_BUYUT_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) fotoBuyut() — tam ekran lightbox (fotoUrl'den önce)
FUNC = '''function fotoBuyut(src) {  /* FOTO_BUYUT_V1 — fotoğrafa dokun → tam ekran */
  if (!src) return;
  const ov = document.createElement("div");
  ov.style.cssText = "position:fixed;inset:0;z-index:100000;background:rgba(0,0,0,.92);display:flex;align-items:center;justify-content:center;padding:12px;cursor:zoom-out";
  ov.innerHTML = `<img src="${src}" alt="" style="max-width:100%;max-height:100%;object-fit:contain;border-radius:6px"><div style="position:absolute;top:14px;right:16px;width:40px;height:40px;border-radius:50%;background:rgba(255,255,255,.18);color:#fff;display:flex;align-items:center;justify-content:center;font-size:22px">✕</div>`;
  ov.addEventListener("click", () => ov.remove());
  const _im = ov.querySelector("img"); if (_im) _im.addEventListener("click", e => e.stopPropagation());
  document.body.appendChild(ov);
}
'''
rep_anchor = 'async function fotoUrl(id) {'
assert s.count(rep_anchor) == 1, "fotoUrl anchor count=%d" % s.count(rep_anchor)
s = s.replace(rep_anchor, FUNC + "\n" + rep_anchor, 1)

# 2) Ziyaret detay fotoları — tıklanabilir + delegated click
OLD = '''      const { fotolar } = await api(`/api/saha/ziyaretler/${zid}/fotolar`);
      const g = document.getElementById("det-fotolar");
      for (const f of fotolar) {
        const url = await fotoUrl(f.id);
        if (url && g) g.insertAdjacentHTML("beforeend", `<img src="${url}" alt="">`);
      }'''
NEW = '''      const { fotolar } = await api(`/api/saha/ziyaretler/${zid}/fotolar`);
      const g = document.getElementById("det-fotolar");
      for (const f of fotolar) {
        const url = await fotoUrl(f.id);
        if (url && g) g.insertAdjacentHTML("beforeend", `<img src="${url}" alt="" style="cursor:zoom-in">`);
      }
      if (g && !g._buyutBound) { g._buyutBound = true; g.addEventListener("click", ev => { const im = ev.target.closest("img"); if (im) fotoBuyut(im.src); }); }  /* FOTO_BUYUT_V1 */'''
assert s.count(OLD) == 1, "det-fotolar anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] FOTO_BUYUT_V1 (mobil)")
