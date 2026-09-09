# -*- coding: utf-8 -*-
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "FOTO_BUYUT_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

FUNC = '''function fotoBuyut(src) {  /* FOTO_BUYUT_V1 — fotoğrafa tıkla → tam ekran */
  if (!src) return;
  const ov = document.createElement("div");
  ov.style.cssText = "position:fixed;inset:0;z-index:100000;background:rgba(0,0,0,.92);display:flex;align-items:center;justify-content:center;padding:16px;cursor:zoom-out";
  ov.innerHTML = `<img src="${src}" alt="" style="max-width:100%;max-height:100%;object-fit:contain;border-radius:6px"><div style="position:absolute;top:16px;right:20px;width:40px;height:40px;border-radius:50%;background:rgba(255,255,255,.18);color:#fff;display:flex;align-items:center;justify-content:center;font-size:22px;cursor:pointer">✕</div>`;
  ov.addEventListener("click", () => ov.remove());
  const _im = ov.querySelector("img"); if (_im) _im.addEventListener("click", e => e.stopPropagation());
  document.body.appendChild(ov);
}
'''
rep_anchor = 'async function fotoUrl(id) {'
assert s.count(rep_anchor) == 1, "fotoUrl anchor count=%d" % s.count(rep_anchor)
s = s.replace(rep_anchor, FUNC + "\n" + rep_anchor, 1)

OLD = '''      const { fotolar = [] } = await api(`/api/saha/ziyaretler/${z.id}/fotolar`);
      const g = S.container.querySelector("#dk-det-foto");
      for (const f of fotolar) { const u = await fotoUrl(f.id); if (u && g) g.insertAdjacentHTML("beforeend", `<img src="${u}" alt="">`); }'''
NEW = '''      const { fotolar = [] } = await api(`/api/saha/ziyaretler/${z.id}/fotolar`);
      const g = S.container.querySelector("#dk-det-foto");
      for (const f of fotolar) { const u = await fotoUrl(f.id); if (u && g) g.insertAdjacentHTML("beforeend", `<img src="${u}" alt="" style="cursor:zoom-in">`); }
      if (g && !g._buyutBound) { g._buyutBound = true; g.addEventListener("click", ev => { const im = ev.target.closest("img"); if (im) fotoBuyut(im.src); }); }  /* FOTO_BUYUT_V1 */'''
assert s.count(OLD) == 1, "dk-det-foto anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] FOTO_BUYUT_V1 (masaustu)")
