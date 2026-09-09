# -*- coding: utf-8 -*-
# DS_TEMA_V1 — GLOBAL tasarım temeli (adım 1): koyu-tema SIZINTI önleyici.
#   Kök neden: host app.js <html data-tema="koyu"> ile bare eleman kurallarına (table/td/th,
#   form kontrolleri) LİTERAL koyu arka plan set ediyor; bu, .dk-app'in açık token'larını
#   ezip saha içeriğine sızıyor. Her sekme bunu tek tek yamıyordu (kırılgan, tekrarlayan hata).
#   ÇÖZÜM: .dk-app düzeyinde sızıntıyı bir kez nötrle → HER görünüm (mevcut+gelecek) açık kalır.
#   Sekmeye özel stiller (.zc-t td vb.) daha yüksek specificity ile korunur; bu yalnız sızıntıyı keser.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "DS_TEMA_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

o = '.dk-app *{box-sizing:border-box}'
n = ('.dk-app *{box-sizing:border-box}\n'
     '/* DS_TEMA_V1 — koyu-tema sızıntı önleyici (app.js html[data-tema=koyu] eleman kuralları saha içeriğine sızmasın) */\n'
     '.dk-app table,.dk-app thead,.dk-app tbody,.dk-app tr,.dk-app th,.dk-app td{background-color:transparent;color:inherit}\n'
     '.dk-app input:not([type=checkbox]):not([type=radio]),.dk-app select,.dk-app textarea{background-color:var(--zemin-1);color:var(--tx-0)}\n'
     '.dk-app ::placeholder{color:var(--tx-3)}')
assert s.count(o) == 1, "anchor=%d" % s.count(o)
s = s.replace(o, n, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] DS_TEMA_V1 (saha_desktop.js) — global koyu-tema sızıntı önleyici")
