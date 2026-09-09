# -*- coding: utf-8 -*-
# KAPSAM_TAD_V1 — "kapsam" alt-aracını İzinler matrisine (Saha) ekle + manager varsayılanı.
#   Yönetici raporu: rep varsayılanına EKLENMEZ (istenirse elle verilir → kendi kitabını görür).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_TAD_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

o1 = '["Yönetim & Analiz", [["rapor", "Rapor"], ["ciro", "Ciro"], ["risk", "Risk Radarı"], ["rotam", "Bugün Sahada"], ["kokpit", "Kokpit"], ["ceo", "CEO"], ["rep-aktivite", "Aktivite"]]],'
n1 = '["Yönetim & Analiz", [["rapor", "Rapor"], ["ciro", "Ciro"], ["risk", "Risk Radarı"], ["rotam", "Bugün Sahada"], ["kapsam", "Kapsam & Beyaz Alan"], ["kokpit", "Kokpit"], ["ceo", "CEO"], ["rep-aktivite", "Aktivite"]]],  /* KAPSAM_TAD_V1 */'
assert s.count(o1) == 1, "groups anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

o2 = 'manager: ["bugun", "ziyaretler", "plan", "musteriler", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "harita", "kokpit", "ceo", "ciro", "risk", "rotam"],'
n2 = 'manager: ["bugun", "ziyaretler", "plan", "musteriler", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "harita", "kokpit", "ceo", "ciro", "risk", "rotam", "kapsam"],  /* KAPSAM_TAD_V1 */'
assert s.count(o2) == 1, "manager default anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_TAD_V1 (tenant-admin) — kapsam alt-arac + manager varsayilani")
