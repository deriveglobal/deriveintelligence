# -*- coding: utf-8 -*-
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "TEKLIF_UI_SADE_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) Eşik kutusu metni — teklifte kademe kalmadı (FULL_CONTROL). İskonto eşiği editörü butonu kalır.
OLD1 = '          Genel eşik: ≤%${ayarlar.oto_onay_max} oto · %${ayarlar.oto_onay_max}–${ayarlar.mudur_max} müdür · >%${ayarlar.mudur_max} GM'
NEW1 = '          Tüm teklifler yönetici onayına gider  <!-- TEKLIF_UI_SADE_V1 -->'
assert s.count(OLD1) == 1, "esik anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1)

# 2) Kademe etiketi (kart + detay, 2 yer) — müdür/GM ayrımı kalktı
OLD2 = '${t.onay_seviyesi === "GM" ? "GM" : "Müdür"} onayı gerekli'
NEW2 = 'Yönetici onayı gerekli'
assert s.count(OLD2) == 2, "kademe etiketi count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2)

open(F, "w", encoding="utf-8").write(s)
print("[done] TEKLIF_UI_SADE_V1")
