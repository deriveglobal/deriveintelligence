#!/usr/bin/env python3
# HARITA_CHORO_V3 — Gecikme layer'i dönem satisina bagla (period-consistency).
#   Sorun: gecikme guncel risk snapshot'i (donemden bagimsiz) -> donemde satisi olmayan il (Afyon) kirmizi gorunuyor -> "no sales but %100" garip.
#   Cozum: _CHORO_META.gecikme.gate=true; d.ciro (donem) == 0 ise il boyanmaz (gri, "dönemde satış yok"). Net risk/acik alacak (mutlak ₺) DEGISMEZ.
# shells/saha.js. Idempotent, marker-guardli. HARITA_CHORO_V2 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_CHORO_V3" in s:
    print("choro-v3: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_CHORO_V2" in s, "HARITA_CHORO_V2 yok"

# (1) gecikme meta'ya gate:true ekle
A1 = '      gecikme:       { lbl: "Gecikme — KRB ort.",    fld: "gecikme_orani", seq: false, fmt: v => v != null ? ("%" + Math.round(v * 100)) : "veri yok" }\n'
assert s.count(A1) == 1, "gecikme meta anchor"
N1 = '      gecikme:       { lbl: "Gecikme — KRB ort.",    fld: "gecikme_orani", seq: false, gate: true, fmt: v => v != null ? ("%" + Math.round(v * 100)) : "veri yok" } /* HARITA_CHORO_V3 */\n'
s = s.replace(A1, N1, 1)

# (2) style fill: gate'li metrikte dönem satisi yoksa boyama
A2 = '            if (d) fill = _meta.seq ? _ciroColor(Number(d[_meta.fld] || 0), seqMax) : _gecikmeColor(d.gecikme_orani, data.krb_gecikme_orani);\n'
assert s.count(A2) == 1, "style fill anchor"
N2 = '            if (d && (!_meta.gate || Number(d.ciro || 0) > 0)) fill = _meta.seq ? _ciroColor(Number(d[_meta.fld] || 0), seqMax) : _gecikmeColor(d.gecikme_orani, data.krb_gecikme_orani); /* HARITA_CHORO_V3 */\n'
s = s.replace(A2, N2, 1)

# (3) tooltip: gate'lenmis il -> "dönemde satış yok"
A3 = '            const t = d ? (_meta.seq ? (_meta.lbl + ": " + _meta.fmt(Number(d[_meta.fld] || 0))) : (d.gecikme_orani != null ? ("Gecikme: %" + Math.round(d.gecikme_orani * 100)) : "veri yok")) : "veri yok";\n'
assert s.count(A3) == 1, "tooltip anchor"
N3 = '            const _gated = !!(d && _meta.gate && !(Number(d.ciro || 0) > 0)); const t = (d && !_gated) ? (_meta.seq ? (_meta.lbl + ": " + _meta.fmt(Number(d[_meta.fld] || 0))) : (d.gecikme_orani != null ? ("Gecikme: %" + Math.round(d.gecikme_orani * 100)) : "veri yok")) : (_gated ? "dönemde satış yok" : "veri yok"); /* HARITA_CHORO_V3 */\n'
s = s.replace(A3, N3, 1)

write(FP, s)
print("choro-v3: gecikme layer dönem satisina baglandi (satis yok -> gri)")
print("marker count:", s.count("HARITA_CHORO_V3"))
print("DONE.")
