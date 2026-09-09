# -*- coding: utf-8 -*-
# TZ_ISTANBUL_V1 — tarih gosterimlerini isletmenin saatine (Europe/Istanbul) sabitle.
#   Sorun: new Date("2026-07-28") UTC gece-yarisi olarak ayrisir; toLocaleDateString
#   izleyenin YEREL saatine cevirir. ABD'den bakinca 28.07 -> 27.07 kayar (bir gun geri).
#   Cozum: timeZone:"Europe/Istanbul" ekle -> herkes dogru Turkiye gununu gorur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "TZ_ISTANBUL_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

REPLS = [
  ('toLocaleDateString("tr-TR")',
   'toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul" })'),
  ("toLocaleDateString('tr-TR')",
   'toLocaleDateString(\'tr-TR\', { timeZone: "Europe/Istanbul" })'),
  ('toLocaleDateString("en-CA")',
   'toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" })'),
  ('toLocaleDateString("tr-TR", { day: "numeric", month: "short" })',
   'toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul", day: "numeric", month: "short" })'),
  ('toLocaleDateString("tr-TR",{day:"numeric",month:"short"})',
   'toLocaleDateString("tr-TR",{timeZone:"Europe/Istanbul",day:"numeric",month:"short"})'),
  ('toLocaleDateString("tr-TR", { month: "long", year: "numeric" })',
   'toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul", month: "long", year: "numeric" })'),
  ('toLocaleDateString("tr-TR", { weekday: "long", day: "numeric", month: "long" })',
   'toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul", weekday: "long", day: "numeric", month: "long" })'),
  ('toLocaleDateString("tr-TR", { weekday:"long", day:"numeric", month:"long" })',
   'toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul", weekday:"long", day:"numeric", month:"long" })'),
]
n = 0
for old, new in REPLS:
    c = s.count(old)
    if c:
        s = s.replace(old, new)
        n += c
        print("  %2d x %s" % (c, old))
s = "/* TZ_ISTANBUL_V1 */\n" + s
open(F, "w", encoding="utf-8").write(s)
print("[done] TZ_ISTANBUL_V1 (%s) — %d degisiklik" % (F, n))
