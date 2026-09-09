#!/usr/bin/env python3
# HARITA_TAMEKRAN_V1 — saha haritasina tam ekran butonu (Leaflet topright kontrolu).
#   Dokun -> #ss-harita position:fixed inset:0 (tam ekran) + invalidateSize; tekrar dokun -> kucult.
#   shells/saha.js. Idempotent, marker-guardli. HARITA_LEAFLET_V1 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_TAMEKRAN_V1" in s:
    print("tam-ekran: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_LEAFLET_V1" in s, "once HARITA_LEAFLET_V1 gerekli"

# (1) Tam ekran kontrolu — SORUNLU set'inden once (map + el kapsamda)
A1 = '        const SORUNLU = new Set(["PASIF_NOKTA","ESKI_NOKTA","RISKLI_NOKTA"]);\n'
assert s.count(A1) == 1, "SORUNLU anchor (count!=1)"
CTL = (
    '        (function(){ /* HARITA_TAMEKRAN_V1 */\n'
    '          const FsCtl = L.Control.extend({ options: { position: "topright" },\n'
    '            onAdd: function() {\n'
    '              const b = L.DomUtil.create("button", "");\n'
    '              b.innerHTML = "\\u26f6"; b.title = "Tam ekran";\n'
    '              b.style.cssText = "width:34px;height:34px;background:#fff;border:2px solid rgba(0,0,0,.2);border-radius:6px;font-size:16px;line-height:1;cursor:pointer;color:#334155";\n'
    '              L.DomEvent.disableClickPropagation(b);\n'
    '              b.onclick = function(){ const on = el.classList.toggle("harita-tam"); b.innerHTML = on ? "\\u2715" : "\\u26f6"; b.title = on ? "Kucult" : "Tam ekran"; setTimeout(function(){ try { map.invalidateSize(); } catch(_){} }, 60); };\n'
    '              return b;\n'
    '            }\n'
    '          });\n'
    '          map.addControl(new FsCtl());\n'
    '        })();\n'
)
s = s.replace(A1, CTL + A1, 1)

# (2) Tam ekran CSS — .leaflet-container satirindan sonra
A2 = "  .leaflet-container { font: inherit; background:#eef2f7 }\n"
assert s.count(A2) == 1, "leaflet-container css anchor (count!=1)"
N2 = A2 + "  .harita-tam { position:fixed !important; inset:0 !important; width:100vw !important; height:100vh !important; z-index:100000 !important; border-radius:0 !important; margin:0 !important; } /* HARITA_TAMEKRAN_V1 */\n"
s = s.replace(A2, N2, 1)

write(FP, s)
print("tam-ekran: buton + CSS eklendi")
print("marker count:", s.count("HARITA_TAMEKRAN_V1"))
print("DONE.")
