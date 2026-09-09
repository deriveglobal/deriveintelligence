#!/usr/bin/env python3
# REPONLY_V2 — saha-rep + intelligence:VIEWER hala rep-only kalsin.
# Kok: _hasIntel HERHANGI bir intelligence abonesini sayiyordu -> viewer de "dual" sayilip
# BI kabugu aciliyordu. Viewer = yalniz 'rakip' dept API granti (Rakip Fiyatlari), BI koltugu DEGIL.
# Fix: _hasIntel yalniz manager/admin intel koltugunu saysin. Tek satir, idempotent, count==1.
import sys

F = "/opt/krb-assessment/app.js"
src = open(F, encoding="utf-8").read()

if "REPONLY_V2" in src:
    print("SKIP: REPONLY_V2 zaten uygulanmis")
    sys.exit(0)

OLD = 'const _hasIntel = (me.subscriptions || []).some(s => s.moduleId === "intelligence");'
NEW = ('const _hasIntel = (me.subscriptions || []).some(s => s.moduleId === "intelligence" '
       '&& (s.moduleRole === "manager" || s.moduleRole === "admin")); '
       '/* REPONLY_V2 — intel:viewer sadece rakip API granti, BI koltugu degil; saha-rep+viewer hala rep-only, BI kabugu YOK */')

n = src.count(OLD)
assert n == 1, f"HATA: beklenen 1, bulunan {n} -> anchor degismis, dur"

src = src.replace(OLD, NEW)
open(F, "w", encoding="utf-8").write(src)
print("OK: REPONLY_V2 uygulandi")
