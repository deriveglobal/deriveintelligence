#!/usr/bin/env python3
# HARITA_CHORO_V1 (Faz 4b) — il choropleth katmani.
#   "Renklendir" secici: kapali / Ciro (sequential acik->koyu) / Gecikme (KRB ort. diverging kirmizi<->yesil).
#   L.geoJSON (tr-geo) alt pane'de (pinler ustte, tiklanabilir). Il tikla -> il analizi. Legend. Donemle senkron.
# shells/saha.js. Idempotent, marker-guardli. HARITA_IL_SEC_V1 + HARITA_GEO_V1(server) gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_CHORO_V1" in s:
    print("choro: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_IL_SEC_V1" in s, "once HARITA_IL_SEC_V1 gerekli"

# (1) Renklendir secici + legend — il-sec'ten sonra
A1 = '          <select id="ss-il-sec" style="font-size:12px;padding:6px 8px;width:100%;box-sizing:border-box;margin-bottom:8px;border:1px solid #e5e7eb;border-radius:8px;background:#fff;color:#0f172a"><option value="">İl seç — şehir analizi…</option></select>\n'
assert s.count(A1) == 1, "il-sec anchor"
N1 = A1 + (
    '          <select id="ss-choro-sec" style="font-size:12px;padding:6px 8px;width:100%;box-sizing:border-box;margin-bottom:8px;border:1px solid #e5e7eb;border-radius:8px;background:#fff;color:#0f172a"><option value="">🎨 Renklendir: kapalı</option><option value="ciro">🎨 Ciro (dönem)</option><option value="gecikme">🎨 Gecikme — KRB ort. kıyas</option></select>\n'
    '          <div id="ss-choro-legend" style="display:none;font-size:11px;color:#475569;margin:-2px 0 8px;padding:5px 8px;background:#f8fafc;border:1px solid #eef2f7;border-radius:8px"></div>\n'
)
s = s.replace(A1, N1, 1)

# (2) Choropleth state + fonksiyonlar — haritaIlSec'ten once
A2 = '    async function haritaIlSec(il) { /* HARITA_IL_SEC_V1 */\n'
assert s.count(A2) == 1, "haritaIlSec anchor"
BLOCK = r'''    /* HARITA_CHORO_V1 */
    let _choroLayer = null, _trGeo = null, _ilMetrik = null, _ilMetrikDonem = null, _haritaMapRef = null, _choroMetrik = "";
    function _normIl(x) {
      if (!x) return "";
      let n = String(x).trim().toLocaleUpperCase("tr-TR").replace(/\s+/g, " ");
      n = n.replace(/İ/g, "I").replace(/Ş/g, "S").replace(/Ç/g, "C").replace(/Ğ/g, "G").replace(/Ü/g, "U").replace(/Ö/g, "O");
      const alias = { "ICEL": "MERSIN", "AFYONKARAHISAR": "AFYON", "K.MARAS": "KAHRAMANMARAS", "KAHRAMAN MARAS": "KAHRAMANMARAS", "URFA": "SANLIURFA" };
      return alias[n] || n;
    }
    async function _ensureTrGeo() { if (_trGeo) return _trGeo; _trGeo = await api("/api/saha/tr-geo"); return _trGeo; }
    async function _ensureIlMetrik() {
      const donem = (typeof rpFrom === "function" ? rpFrom() : "") + ":" + (typeof rpTo === "function" ? rpTo() : "");
      if (_ilMetrik && _ilMetrikDonem === donem) return _ilMetrik;
      const dq = (typeof rpFrom === "function") ? ("?from=" + rpFrom() + "&to=" + rpTo()) : "";
      _ilMetrik = await api("/api/saha/harita-il-metrikler" + dq);
      _ilMetrikDonem = donem;
      return _ilMetrik;
    }
    function _ciroColor(v, max) { if (!v || max <= 0) return "#eef2f7"; const t = Math.min(1, v / max), L = (a, b) => Math.round(a + (b - a) * t); return "rgb(" + L(219, 30) + "," + L(234, 58) + "," + L(254, 138) + ")"; }
    function _gecikmeColor(v, krb) { if (v == null) return "#eef2f7"; if (krb == null || krb <= 0) krb = 0.0001; const d = (v - krb) / krb; if (d <= -0.15) return "#16a34a"; if (d <= -0.05) return "#86efac"; if (d < 0.05) return "#fde68a"; if (d < 0.20) return "#fca5a5"; return "#dc2626"; }
    function _choroLegend(metrik, data) {
      const lg = document.getElementById("ss-choro-legend"); if (!lg) return;
      if (!metrik) { lg.style.display = "none"; lg.innerHTML = ""; return; }
      lg.style.display = "block";
      if (metrik === "ciro") lg.innerHTML = "<b>Ciro (dönem)</b> — <span style=\"display:inline-block;width:70px;height:9px;vertical-align:middle;background:linear-gradient(90deg,#dbeafe,#1e3a8a);border-radius:2px\"></span> açık=düşük · koyu=yüksek";
      else { const k = (data && data.krb_gecikme_orani != null) ? (" %" + Math.round(data.krb_gecikme_orani * 100)) : ""; lg.innerHTML = "<b>Gecikme (KRB ort." + k + ")</b> — <span style=\"color:#16a34a\">yeşil: ort. altı (iyi)</span> · <span style=\"color:#dc2626\">kırmızı: ort. üstü (çekiyor)</span>"; }
    }
    async function renklendir(metrik) {
      _choroMetrik = metrik || "";
      const map = _haritaMapRef; if (!map || !window.L) return;
      if (_choroLayer) { try { map.removeLayer(_choroLayer); } catch (_) {} _choroLayer = null; }
      if (!metrik) { _choroLegend("", null); return; }
      try {
        const geo = await _ensureTrGeo();
        const data = await _ensureIlMetrik();
        const byIl = {}; (data.iller || []).forEach(x => { byIl[_normIl(x.il)] = x; });
        const ciroMax = Math.max(1, ...(data.iller || []).map(x => Number(x.ciro || 0)));
        _choroLayer = L.geoJSON(geo, {
          pane: "choroPane",
          style: (f) => {
            const d = byIl[_normIl(f.properties && (f.properties.name || f.properties.NAME))];
            let fill = "#eef2f7";
            if (d) fill = (metrik === "ciro") ? _ciroColor(Number(d.ciro || 0), ciroMax) : _gecikmeColor(d.gecikme_orani, data.krb_gecikme_orani);
            return { fillColor: fill, fillOpacity: 0.6, color: "#94a3b8", weight: 0.7 };
          },
          onEachFeature: (f, layer) => {
            const nm = (f.properties && (f.properties.name || f.properties.NAME)) || "";
            const d = byIl[_normIl(nm)];
            const t = d ? ((metrik === "ciro") ? ("Ciro: ₺" + Math.round(Number(d.ciro || 0)).toLocaleString("tr-TR")) : (d.gecikme_orani != null ? ("Gecikme: %" + Math.round(d.gecikme_orani * 100)) : "veri yok")) : "veri yok";
            layer.bindTooltip(nm + " — " + t, { sticky: true });
            layer.on("click", () => { try { haritaIlSec(nm); } catch (_) {} });
          }
        }).addTo(map);
        _choroLegend(metrik, data);
      } catch (e) { _choroLegend("", null); }
    }
'''
s = s.replace(A2, BLOCK + A2, 1)

# (3) loadHarita: harita ref + choroPane + secili metrigi yeniden uygula
A3 = '        const map = L.map(el, { zoomControl: true }).setView([39.0, 35.0], 5);\n'
assert s.count(A3) == 1, "map create anchor"
N3 = A3 + (
    '        _haritaMapRef = map; _choroLayer = null; /* HARITA_CHORO_V1 */\n'
    '        try { map.createPane("choroPane"); map.getPane("choroPane").style.zIndex = 350; } catch (_) {}\n'
    '        if (_choroMetrik) { setTimeout(() => { try { renklendir(_choroMetrik); } catch (_) {} }, 200); }\n'
)
s = s.replace(A3, N3, 1)

# (4) Renklendir secici baglama — il-sec baglamasindan sonra
A4 = '            if (!sel.dataset.bound) { sel.dataset.bound = "1"; sel.addEventListener("change", () => { if (sel.value) haritaIlSec(sel.value); else haritaIlKapat(); }); document.getElementById("ss-sehir-kapat")?.addEventListener("click", haritaIlKapat); } /* HARITA_IL_KAPAT_V1 */\n'
assert s.count(A4) == 1, "il-sec binding anchor"
N4 = A4 + '            const _cs = document.getElementById("ss-choro-sec"); if (_cs && !_cs.dataset.bound) { _cs.dataset.bound = "1"; _cs.addEventListener("change", () => renklendir(_cs.value)); } /* HARITA_CHORO_V1 */\n'
s = s.replace(A4, N4, 1)

# (5) Donem hook: choropleth'i de tazele
A5 = '    window._haritaDonemHook = () => { try { if (mapSehir) haritaIlSec(mapSehir); } catch (_) {} }; /* HARITA_DONEM_UI_V1 */\n'
assert s.count(A5) == 1, "donem hook anchor"
N5 = '    window._haritaDonemHook = () => { try { if (mapSehir) haritaIlSec(mapSehir); } catch (_) {} try { if (_choroMetrik) { _ilMetrik = null; renklendir(_choroMetrik); } } catch (_) {} }; /* HARITA_DONEM_UI_V1 + CHORO */\n'
s = s.replace(A5, N5, 1)

write(FP, s)
print("choro: renklendir secici + il choropleth katmani eklendi")
print("marker count:", s.count("HARITA_CHORO_V1"))
print("DONE.")
