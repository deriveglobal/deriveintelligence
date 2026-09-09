#!/usr/bin/env python3
# TZ_FIX1 — saha ziyaret tarihleri Europe/Istanbul'a alinir (UTC iken tarih 1 gun geride kaliyordu).
# server_container.mjs (insert fallback + bugun/recep sayimlari) + shells/saha.js (bugun ISO).
# Idempotent. Run in /opt/krb-assessment.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

IST_JS = "new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' })"
IST_SQL = "(now() AT TIME ZONE 'Europe/Istanbul')::date"

# ---------- server_container.mjs ----------
SP = "server_container.mjs"
s = read(SP)
n = 0
a = "(p.ziyaret_tarihi || new Date().toISOString().slice(0, 10))"
b = "(p.ziyaret_tarihi || " + IST_JS + ")"
if a in s:
    c = s.count(a); s = s.replace(a, b); n += c; print("server visit-date fallback:", c, "yer")
else:
    print("server visit-date fallback: zaten/yok")
for old, tag in [("ziyaret_tarihi = CURRENT_DATE) AS bugun", "bugun-tamam"),
                 ("planlanan_tarih = CURRENT_DATE) AS planli", "bugun-planli"),
                 ("ziyaret_tarihi=CURRENT_DATE) AS tamam", "recep-tamam"),
                 ("planlanan_tarih=CURRENT_DATE) AS planli", "recep-planli")]:
    new = old.replace("CURRENT_DATE", IST_SQL)
    if new in s:
        print("server", tag, ": zaten")
    elif old in s:
        s = s.replace(old, new, 1); n += 1; print("server", tag, ": duzeltildi")
    else:
        print("server", tag, ": ANCHOR YOK")
write(SP, s)

# ---------- shells/saha.js ----------
FP = "shells/saha.js"
t = read(FP)
a2 = "new Date().toISOString().slice(0, 10)"
if a2 in t:
    c = t.count(a2); t = t.replace(a2, IST_JS); write(FP, t); print("client bugun ISO:", c, "yer")
else:
    print("client bugun ISO: zaten/yok")
print("DONE. server degisiklik:", n)
