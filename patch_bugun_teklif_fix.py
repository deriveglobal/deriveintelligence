# -*- coding: utf-8 -*-
# BUGUN_TEKLIF_FIX_V1 — /api/saha/bugun "teklifler" sorgusu OLMAYAN t.musteri_adi kolonunu
#   seciyordu -> sorgu HATA -> sessiz catch yutuyor -> teklifler=[] -> "Acik Teklif" ve
#   "Bekleyen Teklifler" 0 gorunuyordu (oysa 5 TASLAK teklif var).
#   Cozum: saha_teklif'te musteri_adi/rep_adi kolonu YOK; saha_musteri + users JOIN ile getir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "BUGUN_TEKLIF_FIX_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = "        let tSql = `SELECT t.id, t.musteri_adi, t.durum, t.toplam_tutar, t.created_at FROM saha_teklif t WHERE t.tenant_id = $1 AND t.durum IN ('TASLAK','ONAY_BEKLIYOR')`;"
NEW = "        let tSql = `SELECT t.id, COALESCE(m.firma,'') AS musteri_adi, u.full_name AS rep_adi, t.durum, t.toplam_tutar, t.created_at FROM saha_teklif t LEFT JOIN saha_musteri m ON m.id = t.musteri_id LEFT JOIN users u ON u.id = t.rep_id WHERE t.tenant_id = $1 AND t.durum IN ('TASLAK','ONAY_BEKLIYOR')`; /* BUGUN_TEKLIF_FIX_V1: musteri_adi/rep_adi kolon degil, JOIN ile getir */"
assert s.count(OLD) == 1, "anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_TEKLIF_FIX_V1")
