#!/usr/bin/env python3
# WINDOW_MAXAY_FIX — donem penceresini CURRENT_DATE yerine max(ay)'e gore ac.
#  Sorun: bi_marj_atom aylik + veri bir ay geride → "Bu ay" (ay>=CURRENT_DATE-1ay) BOŞ dönüyor.
#  Cozum (mevcut KIRILIM_TF pattern'i): pencere = son N MEVCUT ay, max(ay)'e demirli.
#  kokpit-umbrella (winSql) + musteri-evreni (aWin) ayni RHS'i paylasir → ikisi de düzelir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
GUARD = "max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - ($2"
if GUARD in s:
    print("[skip] WINDOW_MAXAY_FIX zaten var"); sys.exit(0)
OLD = r'''ytd ? "ay >= date_trunc('year', CURRENT_DATE)" : "ay >= (CURRENT_DATE - ($2 * INTERVAL '1 month'))"'''
NEW = r'''ytd ? "ay >= date_trunc('year', (SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1))" : "ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - ($2 * INTERVAL '1 month'))"'''
n = s.count(OLD)
assert n >= 1, "HATA: hedef winSql/aWin satiri bulunamadi (umbrella/evreni deploy edilmis mi?)"
s = s.replace(OLD, NEW)
open(F, "w", encoding="utf-8").write(s)
print("[ok] WINDOW_MAXAY_FIX uygulandi —", n, "yerde (umbrella winSql + evreni aWin). 'Bu ay' artik son mevcut ay.")
