# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
MARK = "NO_PTR_YENILE_V1"

def patch(rel, edits):
    path = os.path.join(BASE, rel)
    with io.open(path, encoding="utf-8") as f: orig = f.read()
    if MARK in orig:
        print("SKIP (zaten var):", rel); return
    s = orig
    for name, old, new in edits:
        c = s.count(old)
        assert c == 1, "ANCHOR %s bulundu=%d -> %s" % (name, c, rel)
        s = s.replace(old, new)
    if not os.path.exists(path + ".ptrbak"):
        with io.open(path + ".ptrbak", "w", encoding="utf-8") as f: f.write(orig)
    with io.open(path, "w", encoding="utf-8") as f: f.write(s)
    print("OK", rel, "| MARK:", s.count(MARK))

# ===== styles.css — tarayıcı pull-to-refresh (overscroll) kapat =====
CSSo = '''html {
  background: var(--color-bg);
  -webkit-font-smoothing: antialiased;'''
CSSn = '''html {
  overscroll-behavior: none;   /* NO_PTR_YENILE_V1 — iPhone/tarayıcı aşağı-çek-yenile kapatıldı (reload=oturum uçuyordu) */
  background: var(--color-bg);
  -webkit-font-smoothing: antialiased;'''

# ===== saha.js — header'a 🔄 Yenile butonu =====
Ho = '''<button id="saha-cikis" title="Çıkış Yap"'''
Hn = '''<button id="saha-yenile" title="Yenile" style="background:none;border:none;color:#cbd5e1;font-size:15px;cursor:pointer;padding:0 8px 0 0;line-height:1">🔄</button><button id="saha-cikis" title="Çıkış Yap"'''  # NO_PTR_YENILE_V1

# ===== saha.js — wireNav: 🔄 → mevcut görünümü yeniden çiz (reload YOK) =====
Wo = '''  S.container.querySelector("#saha-cikis")?.addEventListener("click", async () => {'''
Wn = '''  S.container.querySelector("#saha-yenile")?.addEventListener("click", () => { /* NO_PTR_YENILE_V1 */
    const yb = S.container.querySelector("#saha-yenile"); if (yb) { yb.style.transition = "transform .5s"; yb.style.transform = "rotate(360deg)"; setTimeout(() => { yb.style.transform = ""; }, 520); }
    try { loadView(S.view); } catch (e) {}
  });
  S.container.querySelector("#saha-cikis")?.addEventListener("click", async () => {'''

patch("styles.css", [("CSS", CSSo, CSSn)])
patch("shells/saha.js", [("H", Ho, Hn), ("W", Wo, Wn)])
print("BITTI.")
