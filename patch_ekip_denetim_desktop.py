# -*- coding: utf-8 -*-
# EKIP_DENETIM_TASI_V1 (masaustu) — Aktivite (rep-aktivite) + Sistem, saha nav'ndan kaldirildi.
#   Yönetim konsoluna (Denetim bolumu) tasindi. VIEWS.sistem / VIEWS["rep-aktivite"]
#   fonksiyonlari kod olarak DURUR (erisilemez, zararsiz) — sadece nav girisleri kaldirilir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "EKIP_DENETIM_TASI_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
OLD = ('  if (S.isYonetim) yon.push(["rep-aktivite", "📡", "Aktivite"]);\n'
       '  if (S.isOwner || S.isYonetim) yon.push(["sistem", "🔧", "Sistem"]); /* HATA_YONETIM_V1 */')
NEW = '  /* EKIP_DENETIM_TASI_V1 — Aktivite + Sistem, Yönetim konsoluna tasindi (saha nav girisi kaldirildi) */'
assert s.count(OLD) == 1, "anchor bulunamadi (%d)" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] EKIP_DENETIM_TASI_V1 (masaustu)")
