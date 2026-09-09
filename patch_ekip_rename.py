# -*- coding: utf-8 -*-
# EKIP_RENAME_V1 — Yönetim navigasyonunda "Temsilciler/Temsilci" -> "Ekip".
#   (Rapor -> Temsilciler rapor sekmesi DEGISMEZ; sadece Yönetim modül etiketi.)
import sys
which = sys.argv[2] if len(sys.argv) > 2 else ("mobil" if "saha.js" in (sys.argv[1] if len(sys.argv)>1 else "") and "desktop" not in (sys.argv[1] if len(sys.argv)>1 else "") else "masaustu")
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "EKIP_RENAME_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

edits = []
if "saha_desktop.js" in F:
    edits = [
        ('if (mgmt) yon.push(["temsilciler", "👥", "Temsilciler"]);',
         'if (mgmt) yon.push(["temsilciler", "👥", "Ekip"]);  /* EKIP_RENAME_V1 */'),
        ('kokpit: "Kokpit", ceo: "CEO Asistan", temsilciler: "Temsilciler", sistem: "Sistem",',
         'kokpit: "Kokpit", ceo: "CEO Asistan", temsilciler: "Ekip", sistem: "Sistem",'),
    ]
else:
    edits = [
        ('...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Temsilci"]] : []),',
         '...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Ekip"]] : []),  /* EKIP_RENAME_V1 */'),
    ]

for a, b in edits:
    assert s.count(a) == 1, "anchor bulunamadi (%d): %s" % (s.count(a), a[:50])
    s = s.replace(a, b, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] EKIP_RENAME_V1 (%s)" % ("masaustu" if "desktop" in F else "mobil"))
