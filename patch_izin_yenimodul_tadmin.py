# -*- coding: utf-8 -*-
# IZIN_YENIMODUL_V1 (tenant-admin.js) — Ciro / Risk Radarı / Bugün Sahada'yı
#   Saha izin matrisine ayrı ayrı verilebilir alt-araç olarak ekle + rol varsayılanlarına işle.
#   Salt konfig; runtime kapılama shell'lerde (backward-compatible) yapılır.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "IZIN_YENIMODUL_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) groups: Yönetim & Analiz'e ciro/risk/rotam ekle (rapor'dan hemen sonra)
o1 = '["Yönetim & Analiz", [["rapor", "Rapor"], ["kokpit", "Kokpit"], ["ceo", "CEO"], ["rep-aktivite", "Aktivite"]]],'
n1 = '["Yönetim & Analiz", [["rapor", "Rapor"], ["ciro", "Ciro"], ["risk", "Risk Radarı"], ["rotam", "Bugün Sahada"], ["kokpit", "Kokpit"], ["ceo", "CEO"], ["rep-aktivite", "Aktivite"]]],  /* IZIN_YENIMODUL_V1 */'
assert s.count(o1) == 1, "groups anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) DEFAULTS.saha.rep — rotam ekle (kendi sabah rotası)
o2 = 'rep: ["bugun", "ziyaretler", "plan", "musteriler", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler"],'
n2 = 'rep: ["bugun", "ziyaretler", "plan", "musteriler", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "rotam"],  /* IZIN_YENIMODUL_V1 */'
assert s.count(o2) == 1, "rep default anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) DEFAULTS.saha.manager — ciro/risk/rotam ekle
o3 = 'manager: ["bugun", "ziyaretler", "plan", "musteriler", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "harita", "kokpit", "ceo"],'
n3 = 'manager: ["bugun", "ziyaretler", "plan", "musteriler", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "harita", "kokpit", "ceo", "ciro", "risk", "rotam"],  /* IZIN_YENIMODUL_V1 */'
assert s.count(o3) == 1, "manager default anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)
# admin = modTools("saha") → yeni anahtarları otomatik kapsar (dokunma)

open(F, "w", encoding="utf-8").write(s)
print("[done] IZIN_YENIMODUL_V1 (tenant-admin.js) — +3 alt-araç, rep+rotam, manager+ciro/risk/rotam")
