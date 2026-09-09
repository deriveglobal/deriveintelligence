# -*- coding: utf-8 -*-
# RAPOR_DATEFIX_DK_V1 (masaüstü) — tarih seçici tutarlılığı + off-by-one düzeltmesi.
#   SORUN: preset "30 gün" = bugün-30 (31 gün, 06/30 gibi tuhaf başlangıç) → mobil (bugün-29, temiz 30 gün)
#          ile UYUŞMUYOR. Varsayılan da bugün-30'du.
#   FIX: "N gün" = son N gün DAHİL = bugün-(N-1) → bugün (mobil ile aynı). Varsayılan da bugün-29.
#        30 gün vurgusu (RAPOR_DEF30) korunur; artık gerçek 30 güne oturur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_DATEFIX_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "RAPOR_DEF30_DK_V1" in s, "HATA: once RAPOR_DEF30_DK (varsayilan) olmali"

# 1) preset math off-by-one: - gun  →  - gun + 1  (son N gün dahil)
o1 = "from.setDate(from.getDate() - gun);"
n1 = "from.setDate(from.getDate() - gun + 1);  /* RAPOR_DATEFIX_DK_V1 */"
assert s.count(o1) == 1, "anchor#1=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) varsayilan: bugün-30 → bugün-29 (hem input value hem rpFrom fallback = 2 yer)
o2 = "simdi.getTime() - 30 * 864e5"
n2 = "simdi.getTime() - 29 * 864e5"
c = s.count(o2)
assert c == 2, "anchor#2=%d (2 bekleniyor)" % c
s = s.replace(o2, n2)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_DATEFIX_DK_V1 (masaüstü) — son 30 gün = bugün-29..bugün")
