#!/usr/bin/env python3
# HARITA_CHORO_V2 — Renklendir secici 2 -> 7 metrik + genel metrik-meta tablosu.
#   Sequential (acik->koyu mavi): ciro, adet, tuketici ciro, ticari ciro, net risk, acik alacak.
#   Diverging (KRB ort.): gecikme (V2 sunucuda %100 clamp'li).
# shells/saha.js. Idempotent, marker-guardli. HARITA_CHORO_V1 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_CHORO_V2" in s:
    print("choro-v2: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_CHORO_V1" in s, "HARITA_CHORO_V1 yok"
assert "_choroGeo" in s, "HARITA_CHORO_FIX_V1 gerekli"

# (F1) secici secenekleri: 2 -> 7
F1 = '<option value="">🎨 Renklendir: kapalı</option><option value="ciro">🎨 Ciro (dönem)</option><option value="gecikme">🎨 Gecikme — KRB ort. kıyas</option>'
assert s.count(F1) == 1, "secici anchor"
N1 = ('<option value="">🎨 Renklendir: kapalı</option>'
      '<option value="ciro">🎨 Ciro (dönem)</option>'
      '<option value="adet">🎨 Adet (dönem)</option>'
      '<option value="ciro_tuketici">🎨 Tüketici ciro (dönem)</option>'
      '<option value="ciro_ticari">🎨 Ticari ciro (dönem)</option>'
      '<option value="net_risk">🎨 Net risk (güncel)</option>'
      '<option value="overdue">🎨 Açık alacak ₺ (güncel)</option>'
      '<option value="gecikme">🎨 Gecikme — KRB ort. (güncel)</option>')
s = s.replace(F1, N1, 1)

# (F2) _gecikmeColor satirindan sonra _CHORO_META tablosu ekle
F2 = '    function _gecikmeColor(v, krb) { if (v == null) return "#eef2f7"; if (krb == null || krb <= 0) krb = 0.0001; const d = (v - krb) / krb; if (d <= -0.15) return "#16a34a"; if (d <= -0.05) return "#86efac"; if (d < 0.05) return "#fde68a"; if (d < 0.20) return "#fca5a5"; return "#dc2626"; }\n'
assert s.count(F2) == 1, "_gecikmeColor anchor"
META = '''    const _CHORO_META = { /* HARITA_CHORO_V2 */
      ciro:          { lbl: "Ciro (dönem)",          fld: "ciro",          seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") },
      adet:          { lbl: "Adet (dönem)",          fld: "adet",          seq: true,  fmt: v => Math.round(v).toLocaleString("tr-TR") + " ad" },
      ciro_tuketici: { lbl: "Tüketici ciro (dönem)", fld: "ciro_tuketici", seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") },
      ciro_ticari:   { lbl: "Ticari ciro (dönem)",   fld: "ciro_ticari",   seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") },
      net_risk:      { lbl: "Net risk (güncel)",     fld: "net_risk",      seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") },
      overdue:       { lbl: "Açık alacak (güncel)",  fld: "overdue",       seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") },
      gecikme:       { lbl: "Gecikme — KRB ort.",    fld: "gecikme_orani", seq: false, fmt: v => v != null ? ("%" + Math.round(v * 100)) : "veri yok" }
    };
'''
s = s.replace(F2, F2 + META, 1)

# (F3) ciroMax -> metrik-genel seqMax + _meta
F3 = '        const ciroMax = Math.max(1, ...(data.iller || []).map(x => Number(x.ciro || 0)));\n'
assert s.count(F3) == 1, "ciroMax anchor"
N3 = '        const _meta = _CHORO_META[metrik] || _CHORO_META.ciro; const seqMax = _meta.seq ? Math.max(1, ...(data.iller || []).map(x => Number(x[_meta.fld] || 0))) : 1; /* HARITA_CHORO_V2 */\n'
s = s.replace(F3, N3, 1)

# (F4) style fill: metrik-genel
F4 = '            if (d) fill = (metrik === "ciro") ? _ciroColor(Number(d.ciro || 0), ciroMax) : _gecikmeColor(d.gecikme_orani, data.krb_gecikme_orani);\n'
assert s.count(F4) == 1, "style fill anchor"
N4 = '            if (d) fill = _meta.seq ? _ciroColor(Number(d[_meta.fld] || 0), seqMax) : _gecikmeColor(d.gecikme_orani, data.krb_gecikme_orani);\n'
s = s.replace(F4, N4, 1)

# (F5) tooltip metni: metrik-genel
F5 = '            const t = d ? ((metrik === "ciro") ? ("Ciro: ₺" + Math.round(Number(d.ciro || 0)).toLocaleString("tr-TR")) : (d.gecikme_orani != null ? ("Gecikme: %" + Math.round(d.gecikme_orani * 100)) : "veri yok")) : "veri yok";\n'
assert s.count(F5) == 1, "tooltip anchor"
N5 = '            const t = d ? (_meta.seq ? (_meta.lbl + ": " + _meta.fmt(Number(d[_meta.fld] || 0))) : (d.gecikme_orani != null ? ("Gecikme: %" + Math.round(d.gecikme_orani * 100)) : "veri yok")) : "veri yok";\n'
s = s.replace(F5, N5, 1)

# (F6) legend kosulu: metrik === "ciro" -> _CHORO_META[metrik].seq + dinamik etiket
F6 = '      if (metrik === "ciro") lg.innerHTML = "<b>Ciro (dönem)</b> — <span'
assert s.count(F6) == 1, "legend anchor"
N6 = '      const _m = _CHORO_META[metrik]; if (_m && _m.seq) lg.innerHTML = "<b>" + _m.lbl + "</b> — <span'
s = s.replace(F6, N6, 1)

write(FP, s)
print("choro-v2: 7 metrik secici + genel metrik-meta + genel renklendir")
print("marker count:", s.count("HARITA_CHORO_V2"))
print("DONE.")
