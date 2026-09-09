#!/usr/bin/env python3
# HARITA_LEAFLET_V1 (Faz 1) — Saha Harita: kirik SVG il-choropleth -> Leaflet + OSM.
#   Tip-renkli pinler (Tuketici mavi / Ticari amber), sorunlu musteriler yanip soner,
#   pine dokun -> temel balon (firma, tip, durum, il/ilce, yol tarifi). ensureLeaflet CDN loader.
#   Eski choropleth kontrolleri (katman/donem/ebat) kaldirildi; handler'lari ?. ile no-op.
#   shells/saha.js. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_LEAFLET_V1" in s:
    print("harita-leaflet: already present, skip"); print("DONE."); raise SystemExit

# ── (D) ensureLeaflet — rpHarita'dan once (modul seviyesi) ──
A_rp = "  function rpHarita() {"
assert s.count(A_rp) == 1, "rpHarita anchor (count!=1)"
ENSURE = '''  let _leafletP = null; /* HARITA_LEAFLET_V1 */
  function ensureLeaflet() {
    if (window.L) return Promise.resolve();
    if (_leafletP) return _leafletP;
    _leafletP = new Promise((resolve, reject) => {
      const css = document.createElement("link");
      css.rel = "stylesheet"; css.href = "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css";
      document.head.appendChild(css);
      const sc = document.createElement("script");
      sc.src = "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js";
      sc.onload = () => resolve();
      sc.onerror = () => { _leafletP = null; reject(new Error("Leaflet yuklenemedi (ag/CSP)")); };
      document.head.appendChild(sc);
    });
    return _leafletP;
  }
'''
s = s.replace(A_rp, ENSURE + A_rp, 1)

# ── (E) Yanip sonme CSS keyframe (saha-css icine) ──
A_css = "  .saha-app, .saha-main, .modal-fon, .modal-kutu { overscroll-behavior-y: none; } /* PTR_FIX_V2 */\n"
assert s.count(A_css) == 1, "PTR_FIX_V2 css anchor (count!=1)"
N_css = A_css + (
    "  @keyframes haritaPinPulse { 0%,100%{ opacity:1 } 50%{ opacity:.2 } } /* HARITA_LEAFLET_V1 */\n"
    "  .harita-pin-sorunlu { animation: haritaPinPulse 1.1s ease-in-out infinite; }\n"
    "  .leaflet-container { font: inherit; background:#eef2f7 }\n"
)
s = s.replace(A_css, N_css, 1)

# ── (A) Choropleth kontrolleri -> legend (index-slice: Layer toggle .. Map) ──
assert s.count("<!-- Layer toggle -->") == 1 and s.count("<!-- Map -->") == 1, "harita HTML anchor"
sA = s.index("<!-- Layer toggle -->")
eA = s.index("<!-- Map -->", sA)
LEGEND = ('<!-- Legend (HARITA_LEAFLET_V1) -->\n'
  '          <div style="display:flex;gap:14px;align-items:center;flex-wrap:wrap;margin-bottom:8px;font-size:11px;color:#475569">\n'
  '            <span style="display:inline-flex;align-items:center;gap:5px"><span style="width:11px;height:11px;border-radius:50%;background:#0ea5e9;border:2px solid #fff;box-shadow:0 0 0 1px #cbd5e1"></span>Tuketici</span>\n'
  '            <span style="display:inline-flex;align-items:center;gap:5px"><span style="width:11px;height:11px;border-radius:50%;background:#f59e0b;border:2px solid #fff;box-shadow:0 0 0 1px #cbd5e1"></span>Ticari</span>\n'
  '            <span style="display:inline-flex;align-items:center;gap:5px"><span style="width:11px;height:11px;border-radius:50%;background:#94a3b8;border:2px solid #fff;box-shadow:0 0 0 1px #cbd5e1;animation:haritaPinPulse 1.1s ease-in-out infinite"></span>Sorunlu (yanip soner)</span>\n'
  '          </div>\n'
  '          ')
s = s[:sA] + LEGEND + s[eA:]

# ── (C) Harita konteyneri daha yuksek ──
A_h = 'id="ss-harita" style="position:relative;background:#f8fafc;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden;min-height:60px"'
assert s.count(A_h) == 1, "ss-harita container anchor"
N_h = 'id="ss-harita" style="position:relative;background:#eef2f7;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden;height:440px"'
s = s.replace(A_h, N_h, 1)

# ── (B) loadHarita() -> Leaflet; renderLayerButtons() cagrisini birak ──
START = "    async function loadHarita() {"
END = "\n    loadHarita();\n    renderLayerButtons();\n"
assert s.count(START) == 1, "loadHarita start anchor"
i = s.index(START)
assert s.count(END) == 1, "loadHarita end anchor"
j = s.index(END, i)
NEWFN = '''    async function loadHarita() { /* HARITA_LEAFLET_V1 */
      const el = document.getElementById("ss-harita"); if (!el) return;
      el.innerHTML = `<div style="padding:24px;text-align:center;font-size:12px;color:#94a3b8">Harita yukleniyor...</div>`;
      try {
        await ensureLeaflet();
        const tip = (typeof S !== "undefined" && S.semsiye) ? S.semsiye : "";
        const qs = tip ? ("?tip=" + encodeURIComponent(tip)) : "";
        const resp = await api("/api/saha/harita-musteriler" + qs);
        const musteriler = resp.musteriler || [];
        el.style.height = "440px"; el.innerHTML = "";
        if (!musteriler.length) {
          el.innerHTML = `<div style="padding:24px;text-align:center;font-size:12px;color:#94a3b8">Koordinati kayitli musteri yok.<br><span style="font-size:11px">Temsilci ziyarette check-in yapip musteri adresine kaydettiginde burada belirir.</span></div>`;
          return;
        }
        const map = L.map(el, { zoomControl: true }).setView([39.0, 35.0], 5);
        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "\\u00a9 OpenStreetMap" }).addTo(map);
        const SORUNLU = new Set(["PASIF_NOKTA","ESKI_NOKTA","RISKLI_NOKTA"]);
        const pts = [];
        for (const m of musteriler) {
          if (m.lat == null || m.lng == null) continue;
          const lat = Number(m.lat), lng = Number(m.lng);
          if (isNaN(lat) || isNaN(lng)) continue;
          const tuk = m.tip === "TUKETICI";
          const renk = tuk ? "#0ea5e9" : "#f59e0b";
          const mk = L.circleMarker([lat, lng], { radius: 7, color: "#fff", weight: 2, fillColor: renk, fillOpacity: 0.95, className: SORUNLU.has(m.durum) ? "harita-pin-sorunlu" : "" }).addTo(map);
          const durumEt = (typeof DURUM_ETIKET !== "undefined" && DURUM_ETIKET[m.durum] && DURUM_ETIKET[m.durum][0]) || m.durum || "";
          const yer = [m.il, m.ilce].filter(Boolean).join(" / ");
          mk.bindPopup(
            `<div style="font-size:13px;font-weight:700;margin-bottom:2px">${esc(m.firma || "")}</div>`
            + `<div style="font-size:11px;color:#64748b">${tuk ? "Tuketici" : "Ticari"}${durumEt ? " &middot; " + esc(durumEt) : ""}${yer ? " &middot; " + esc(yer) : ""}</div>`
            + `<button class="pin-yol" style="margin-top:7px;padding:4px 10px;border:none;border-radius:6px;background:#0ea5e9;color:#fff;font-size:12px;cursor:pointer">Yol Tarifi</button>`
          );
          mk.on("popupopen", (e) => {
            const b = e.popup.getElement() && e.popup.getElement().querySelector(".pin-yol");
            if (b) b.onclick = () => { try { yolTarifi(lat, lng, m.firma); } catch (_) {} };
          });
          pts.push([lat, lng]);
        }
        if (pts.length) map.fitBounds(pts, { padding: [30, 30], maxZoom: 12 });
        setTimeout(() => { try { map.invalidateSize(); } catch (_) {} }, 120);
      } catch (err) {
        el.innerHTML = `<div style="padding:12px;text-align:center;font-size:12px;color:#ef4444">Harita yuklenemedi: ${esc(err && err.message || "")}</div>`;
      }
    }'''
s = s[:i] + NEWFN + "\n    loadHarita();\n" + s[j + len(END):]

write(FP, s)
print("harita-leaflet: Leaflet haritasi + tip-renkli pinler + yanip sonen sorunlu pinler eklendi")
print("marker count:", s.count("HARITA_LEAFLET_V1"))
print("DONE.")
