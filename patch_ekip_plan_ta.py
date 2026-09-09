#!/usr/bin/env python3
# EKIP_PLAN_TA_V1 (tenant-admin.js) — "ekip-plan" capability'sini yetki grant editorune kaydet.
#   (1) MODULES.saha "Yönetim & Analiz" grubuna ekle → Bölümler/Kişiler editorunde checkbox.
#   (2) manager DEFAULTS listesine ekle → yonetici varsayilan alir (rep almaz; admin modTools ile otomatik).
#   Boylece client _dok("ekip-plan") + masaustu CATALOG ile tam governance kapanir. Idempotent.
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/tenant-admin.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
if "EKIP_PLAN_TA_V1" in src: print("[=] zaten mevcut (idempotent)"); sys.exit(0)

edits = [
  ("MODULES.saha grubu",
   '''["Yönetim & Analiz", [["rapor", "Rapor"], ["kokpit", "Kokpit"], ["ceo", "CEO"], ["rep-aktivite", "Aktivite"], ["memnuniyet", "Memnuniyet"], ["yon-portfoy", "Yönetici Portföy"]]]''',
   '''["Yönetim & Analiz", [["rapor", "Rapor"], ["ekip-plan", "Ekip Planı"], ["kokpit", "Kokpit"], ["ceo", "CEO"], ["rep-aktivite", "Aktivite"], ["memnuniyet", "Memnuniyet"], ["yon-portfoy", "Yönetici Portföy"]]] /* EKIP_PLAN_TA_V1 */'''),
  ("manager DEFAULTS",
   '''"ozet", "yon-portfoy"],''',
   '''"ozet", "ekip-plan", "yon-portfoy"],  /* EKIP_PLAN_TA_V1 */'''),
]

for ad, old, new in edits:
    c = src.count(old)
    if c != 1:
        print("HATA: anchor '" + ad + "' " + str(c) + " kez (1 bekleniyor)"); sys.exit(1)
    src = src.replace(old, new, 1); print("[+] " + ad)

with open(path, "w", encoding="utf-8") as f: f.write(src)
print("[ok] yazildi:", path)
