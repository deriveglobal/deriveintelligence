# -*- coding: utf-8 -*-
# BUGUN_ADRES_FIX_V1 — /api/saha/bugun ziyaretler sorgusu OLMAYAN m.adres kolonunu seciyor;
#   sorgu HATA veriyor, sessiz catch yutuyor -> ziyaretler=[] -> ekranda 0. (Bastan beri boyleydi.)
#   Cozum: SELECT'ten COALESCE(m.adres,'') AS adres cikar (ziyaret satirinda adres gerekmez).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "BUGUN_ADRES_FIX_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = "z.durum, COALESCE(m.firma, '') AS musteri_adi, COALESCE(m.adres, '') AS adres FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id = z.musteri_id LEFT JOIN users u ON u.id = z.rep_id"
NEW = "z.durum, COALESCE(m.firma, '') AS musteri_adi FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id = z.musteri_id LEFT JOIN users u ON u.id = z.rep_id /* BUGUN_ADRES_FIX_V1: m.adres kolonu yok, cikarildi */"
assert s.count(OLD) == 1, "anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_ADRES_FIX_V1")
