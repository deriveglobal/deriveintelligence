#!/usr/bin/env python3
# HARITA_CHORO_V4 — metrik listesini NET bazina hizala (server HARITA_ILMETRIK_V3 ile).
#   KALDIR: "Gecikme — KRB ort." (overdue/bakiye — kumulatif vadesi_gecmis'e dayali, bozuk) + "Açık alacak" (ham overdue).
#   EKLE:   "Net gecikmiş alacak" (net_gecikmis — bi_cari_bakiye mahsuplu) + "Cari bakiye" (bakiye). Hepsi sequential ₺.
# shells/saha.js. Idempotent, marker-guardli. HARITA_CHORO_V2 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_CHORO_V4" in s:
    print("choro-v4: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_CHORO_V2" in s, "HARITA_CHORO_V2 yok"

# (1) secici: overdue + gecikme -> net_gecikmis + net_risk + cari_bakiye
A1 = '<option value="net_risk">🎨 Net risk (güncel)</option><option value="overdue">🎨 Açık alacak ₺ (güncel)</option><option value="gecikme">🎨 Gecikme — KRB ort. (güncel)</option>'
assert s.count(A1) == 1, "secici anchor"
N1 = '<option value="net_gecikmis">🎨 Net gecikmiş alacak (güncel)</option><option value="net_risk">🎨 Net risk (güncel)</option><option value="cari_bakiye">🎨 Cari bakiye (güncel)</option>'
s = s.replace(A1, N1, 1)

# (2) _CHORO_META: overdue + gecikme satirlarini kaldir, net_gecikmis + cari_bakiye ekle
A2 = ('      net_risk:      { lbl: "Net risk (güncel)",     fld: "net_risk",      seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") },\n'
      '      overdue:       { lbl: "Açık alacak (güncel)",  fld: "overdue",       seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") },\n'
      '      gecikme:       { lbl: "Gecikme — KRB ort.",    fld: "gecikme_orani", seq: false, gate: true, fmt: v => v != null ? ("%" + Math.round(v * 100)) : "veri yok" } /* HARITA_CHORO_V3 */\n')
assert s.count(A2) == 1, "_CHORO_META anchor"
N2 = ('      net_gecikmis:  { lbl: "Net gecikmiş alacak",   fld: "net_gecikmis",  seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") }, /* HARITA_CHORO_V4 */\n'
      '      net_risk:      { lbl: "Net risk (güncel)",     fld: "net_risk",      seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") },\n'
      '      cari_bakiye:   { lbl: "Cari bakiye (güncel)",  fld: "bakiye",        seq: true,  fmt: v => "₺" + Math.round(v).toLocaleString("tr-TR") }\n')
s = s.replace(A2, N2, 1)

write(FP, s)
print("choro-v4: metrik listesi NET bazina hizalandi (gecikme+açık alacak kaldirildi, net gecikmiş+cari bakiye eklendi)")
print("marker:", s.count("HARITA_CHORO_V4"))
print("DONE.")
