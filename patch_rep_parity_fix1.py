# -*- coding: utf-8 -*-
# REP_PARITE_FIX1 (client · saha.js) — REP_PARITE_V1 yorumları şablon HTML'inin İÇİNE düşmüş,
#   kartta "/* REP_PARITE_V1 */" yazısı görünüyordu. Görünür /* */ yorumlarını görünmez HTML yorumuna çevir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "REP_PARITE_FIX1" in s:
    print("[skip] zaten fix'li"); sys.exit(0)
old = ': ""}  /* REP_PARITE_V1 */'
new = ': ""}  <!-- REP_PARITE_V1 FIX1 -->'
n = s.count(old)
assert n == 3, "beklenen 3 görünür yorum, bulunan=%d" % n
s = s.replace(old, new)
# idempotency/iz için dosya sonuna zararsız JS yorumu
s += "\n/* REP_PARITE_FIX1 — gorunur sablon yorumlari HTML yorumuna cevrildi */\n"
open(F, "w", encoding="utf-8").write(s)
print("[done] REP_PARITE_FIX1 — 3 görünür yorum gizlendi")
