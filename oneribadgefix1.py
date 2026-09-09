#!/usr/bin/env python3
# ONERI_BADGE_FIX — "Daha" sekmesindeki öneri rozeti KAPANMIŞ (çözülmüş) önerileri de sayıyordu,
# bu yüzden okunmamış hiçbir şey yokken 16 gibi yanlış bir sayı görünüyordu. Yalnız AÇIK
# (YENI/INCELENIYOR) VE okunmamış önerileri say. shells/saha.js içinde 2 yer. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
old = 'tabBadge("oneriler", oneriler.filter(o => o.okunmamis).length);'
new = 'tabBadge("oneriler", oneriler.filter(o => o.okunmamis && ["YENI", "INCELENIYOR"].includes(o.durum)).length); /* ONERI_BADGE_FIX */'

if "ONERI_BADGE_FIX" in s:
    print("saha.js: already patched, skip")
else:
    c = s.count(old)
    if c >= 1:
        s = s.replace(old, new)
        write(FP, s)
        print("saha.js: patched", c, "occurrence(s)")
    else:
        print("WARN: anchor not found")
print("DONE.")
