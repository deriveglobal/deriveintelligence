# -*- coding: utf-8 -*-
# YETKI_FAZ1 (tenant-admin.js) — DEFAULTS.saha.rep + manager'a "musterikart" ekle (matris dürüst kalsın:
#   rol seçince/Kaydet'te musterikart yanlışlıkla silinmesin). admin zaten modTools ile alıyor.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

def rep(old, new, why):
    global s
    n = s.count(old); assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

# rep default: "musteriler", -> "musteriler", "musterikart",   (tam satır eşle)
rep('rep: ["bugun", "ziyaretler", "plan", "musteriler", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "rotam"],',
    'rep: ["bugun", "ziyaretler", "plan", "musteriler", "musterikart", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "rotam"],  /* YETKI_FAZ1 */',
    "rep-default")
rep('manager: ["bugun", "ziyaretler", "plan", "musteriler", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "harita", "kokpit", "ceo", "ciro", "risk", "rotam", "kapsam"],',
    'manager: ["bugun", "ziyaretler", "plan", "musteriler", "musterikart", "teklif", "notlarim", "rep-brain", "piyasa", "rakip", "rapor", "duyurular", "mesajlar", "oneriler", "harita", "kokpit", "ceo", "ciro", "risk", "rotam", "kapsam"],  /* YETKI_FAZ1 */',
    "manager-default")
open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ1 (tenant-admin) — musterikart rep+manager default'a eklendi")
