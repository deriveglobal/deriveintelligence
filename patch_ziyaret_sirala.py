# -*- coding: utf-8 -*-
# ZIYARET_SIRALA_V1 (mobil saha.js / vZiyaretler) — ziyaret listesi ziyaret_tarihi'ne gore
#   VARSAYILAN AZALAN (en yeni ustte) siralanir + "Tarih ▼/▲" tiklanabilir yon oku.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "ZIYARET_SIRALA_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) sirala durumu (varsayilan azalan)
OLD1 = "    function renderListe(repFiltre) {"
NEW1 = "    let _ziySortDesc = true;  /* ZIYARET_SIRALA_V1 — varsayilan: en yeni ustte */\n    function renderListe(repFiltre) {"
assert s.count(OLD1) == 1, "renderListe anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) listeyi tarihe gore sirala (render'dan hemen once)
OLD2 = '      const listEl = document.getElementById("ziyaret-liste");'
NEW2 = '''      liste = liste.slice().sort((a, b) => {
        const ta = a.ziyaret_tarihi ? new Date(a.ziyaret_tarihi).getTime() : 0;
        const tb = b.ziyaret_tarihi ? new Date(b.ziyaret_tarihi).getTime() : 0;
        return _ziySortDesc ? tb - ta : ta - tb;
      });
      const listEl = document.getElementById("ziyaret-liste");'''
assert s.count(OLD2) == 1, "listEl anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# 3) sirala butonu (liste ustune)
OLD3 = '''      ${repSecEl}
      <div id="ziyaret-liste"></div>`;'''
NEW3 = '''      ${repSecEl}
      <div style="display:flex;justify-content:flex-end;margin-bottom:6px">
        <button id="ziy-sirala" style="background:none;border:1px solid #cbd5e1;border-radius:7px;padding:4px 10px;font-size:12px;color:#334155;cursor:pointer">Tarih <span id="ziy-sirala-ok">▼</span></button>
      </div>
      <div id="ziyaret-liste"></div>`;'''
assert s.count(OLD3) == 1, "innerHTML anchor count=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# 4) buton davranisi (yonu cevir + yeniden render)
OLD4 = '''    renderListe("");
    main().querySelector("#yeni-ziyaret")?.addEventListener("click", () => musteriSecModal(z => ziyaretFormModal(z, "kaydet")));'''
NEW4 = '''    renderListe("");
    main().querySelector("#ziy-sirala")?.addEventListener("click", () => {
      _ziySortDesc = !_ziySortDesc;
      const _ok = main().querySelector("#ziy-sirala-ok"); if (_ok) _ok.textContent = _ziySortDesc ? "▼" : "▲";
      renderListe(main().querySelector("#rep-filtre")?.value || "");
    });
    main().querySelector("#yeni-ziyaret")?.addEventListener("click", () => musteriSecModal(z => ziyaretFormModal(z, "kaydet")));'''
assert s.count(OLD4) == 1, "renderListe(\"\") anchor count=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] ZIYARET_SIRALA_V1")
