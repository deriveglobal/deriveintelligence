#!/usr/bin/env python3
# HARITA_DONEM_UI_V1 — harita metrikleri ustteki global tarih araligiyla (rpFrom/rpTo) senkron.
#   Pin balonu metrikleri + haritaIlSec + sehir AI -> from/to gecirir. Etiketler (dönem). Pinler DEGISMEZ.
#   Tarih degisince: acik sehir karti tazelenir (hook), pin balonu tekrar acilinca donem'e gore refetch.
# shells/saha.js. Idempotent, marker-guardli. HARITA_IL_SEC_V1 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_DONEM_UI_V1" in s:
    print("donem-ui: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_IL_SEC_V1" in s, "once HARITA_IL_SEC_V1 gerekli"

# (1) Pin balonu metrik fetch — donem'e gore refetch + from/to
A1 = ('            if (oz && !oz.dataset.yuklendi) {\n'
      '              oz.dataset.yuklendi = "1";\n'
      '              try {\n'
      '                const d = await api("/api/saha/harita-musteri-ozet?id=" + encodeURIComponent(m.id));\n')
assert s.count(A1) == 1, "pin fetch anchor"
N1 = ('            const _donem = (typeof rpFrom === "function" ? rpFrom() : "") + ":" + (typeof rpTo === "function" ? rpTo() : ""); /* HARITA_DONEM_UI_V1 */\n'
      '            if (oz && oz.dataset.donem !== _donem) {\n'
      '              oz.dataset.donem = _donem;\n'
      '              try {\n'
      '                const _dq = (typeof rpFrom === "function") ? ("&from=" + rpFrom() + "&to=" + rpTo()) : "";\n'
      '                const d = await api("/api/saha/harita-musteri-ozet?id=" + encodeURIComponent(m.id) + _dq);\n')
s = s.replace(A1, N1, 1)

# (2) haritaIlSec il-ozet fetch — from/to
A2 = '        const d = await api("/api/saha/harita-il-ozet?il=" + encodeURIComponent(il));\n'
assert s.count(A2) == 1, "il-ozet fetch anchor"
N2 = '        const _dq = (typeof rpFrom === "function") ? ("&from=" + rpFrom() + "&to=" + rpTo()) : ""; const d = await api("/api/saha/harita-il-ozet?il=" + encodeURIComponent(il) + _dq); /* HARITA_DONEM_UI_V1 */\n'
s = s.replace(A2, N2, 1)

# (3) Etiketler (12ay) -> (dönem)  [pin + il ikiser]
before_s = s.count("Satış (12ay)"); before_c = s.count("Ciro (12ay)")
s = s.replace("Satış (12ay)", "Satış (dönem)")
s = s.replace("Ciro (12ay)", "Ciro (dönem)")
assert before_s >= 1 and before_c >= 1, "label anchors"

# (4) Sehir AI cache key — donem'e gore
A4 = '      const cacheKey = `sehir:${mapSehir}:${mapDays}`;\n'
assert s.count(A4) == 1, "cacheKey anchor"
N4 = '      const cacheKey = `sehir:${mapSehir}:${(typeof rpFrom === "function" ? rpFrom() : "")}:${(typeof rpTo === "function" ? rpTo() : "")}`; /* HARITA_DONEM_UI_V1 */\n'
s = s.replace(A4, N4, 1)

# (5) Sehir AI URL — mapDays yerine rpFrom/rpTo
A5 = ('        const p = new URLSearchParams({ kapsam: "sehir", sehir: mapSehir });\n'
      '        if (mapDays > 0) {\n'
      '          const t = new Date(), f = new Date(); f.setDate(f.getDate() - mapDays + 1);\n'
      '          p.set("from", f.toISOString().slice(0, 10)); p.set("to", t.toISOString().slice(0, 10));\n'
      '        }\n')
assert s.count(A5) == 1, "sehir AI url anchor"
N5 = ('        const p = new URLSearchParams({ kapsam: "sehir", sehir: mapSehir });\n'
      '        if (typeof rpFrom === "function") { p.set("from", rpFrom()); p.set("to", rpTo()); } /* HARITA_DONEM_UI_V1 */\n')
s = s.replace(A5, N5, 1)

# (6) Tarih hook'u kur — loadHarita'dan once
A6 = '    async function loadHarita() { /* HARITA_LEAFLET_V1 */\n'
assert s.count(A6) == 1, "loadHarita anchor"
N6 = '    window._haritaDonemHook = () => { try { if (mapSehir) haritaIlSec(mapSehir); } catch (_) {} }; /* HARITA_DONEM_UI_V1 */\n' + A6
s = s.replace(A6, N6, 1)

# (7) Tarih handler'lari — harita aktifken karti tazele, digerlerinde loadTab
A7 = 'if (activeTab !== "harita") loadTab(activeTab);'
cnt = s.count(A7)
assert cnt == 4, "date handler count != 4 (bulundu: %d)" % cnt
N7 = 'if (activeTab === "harita") { try { if (window._haritaDonemHook) window._haritaDonemHook(); } catch (_) {} } else { loadTab(activeTab); }'
s = s.replace(A7, N7)

write(FP, s)
print("donem-ui: metrikler + sehir AI global tarihle senkron; etiket (dönem); tarih handler harita tazeler")
print("marker count:", s.count("HARITA_DONEM_UI_V1"), "| handler replace:", cnt)
print("DONE.")
