# -*- coding: utf-8 -*-
# BUGUN_ZIYARET_GORDUM_V1 — /api/saha/bugun ziyaretler sorgusu, her ziyaret icin bu
#   kullanicinin onu GORUP gormedigini (saha_ziyaret_gorulme) doner: gordum boolean.
#   Boylece Bugun listesinde gorulmemis ziyaretler "Yeni" rozetiyle gosterilebilir.
#   $3 = session.userId; hem gordum EXISTS hem rep filtresi ayni degeri kullanir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "BUGUN_ZIYARET_GORDUM_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) SELECT'e gordum ekle
OLD1 = "COALESCE(NULLIF(z.rep_adi,''), u.full_name) AS rep_adi, z.ziyaret_tarihi, z.durum, COALESCE(m.firma, '') AS musteri_adi FROM saha_ziyaret z"
NEW1 = "COALESCE(NULLIF(z.rep_adi,''), u.full_name) AS rep_adi, z.ziyaret_tarihi, z.durum, COALESCE(m.firma, '') AS musteri_adi, EXISTS(SELECT 1 FROM saha_ziyaret_gorulme g WHERE g.ziyaret_id = z.id AND g.user_id = $3) AS gordum FROM saha_ziyaret z"
assert s.count(OLD1) == 1, "SELECT anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) params: userId'yi her zaman $3 olarak ekle; rep filtresi de $3 kullansin (ayni deger)
OLD2 = """        const zvP = [tid, today];
        if (session.sahaRole === "rep") { zvSql += " AND z.rep_id = $3"; zvP.push(session.userId); }"""
NEW2 = """        const zvP = [tid, today, session.userId];  /* BUGUN_ZIYARET_GORDUM_V1: $3 = gordum EXISTS + rep filtresi */
        if (session.sahaRole === "rep") { zvSql += " AND z.rep_id = $3"; }"""
assert s.count(OLD2) == 1, "params anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_ZIYARET_GORDUM_V1")
