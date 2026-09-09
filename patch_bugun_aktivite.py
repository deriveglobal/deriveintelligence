# -*- coding: utf-8 -*-
# BUGUN_AKTIVITE_V1 — /api/saha/bugun "ziyaretler" sadece PLANLANDI (planli) cekiyordu;
#   TAMAMLANDI (bugun yapilan gercek ziyaretler) haric kaliyordu -> yonetici ekraninda 0.
#   Ayrica today UTC hesaplaniyordu. Cozum: bugun TAMAMLANMIS + PLANLI ziyaretleri goster,
#   today Istanbul saatinde, rep adi users tablosundan tamamla.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "BUGUN_AKTIVITE_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) today -> Istanbul
OLD1 = """      const today = new Date().toISOString().slice(0, 10);
      const tid   = session.tenantId;"""
NEW1 = """      const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });  /* BUGUN_AKTIVITE_V1 */
      const tid   = session.tenantId;"""
assert s.count(OLD1) == 1, "today anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) ziyaretler sorgusu — TAMAMLANDI(bugun) + PLANLANDI(bugun), rep adi users'tan
OLD2 = """        let zvSql = `SELECT z.id, z.rep_adi, z.ziyaret_tarihi, z.durum, COALESCE(m.firma, '') AS musteri_adi, COALESCE(m.adres, '') AS adres FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id = z.musteri_id WHERE z.tenant_id = $1 AND z.durum = 'PLANLANDI' AND z.ziyaret_tarihi::date = $2::date`;"""
NEW2 = """        let zvSql = `SELECT z.id, COALESCE(NULLIF(z.rep_adi,''), u.full_name) AS rep_adi, z.ziyaret_tarihi, z.durum, COALESCE(m.firma, '') AS musteri_adi, COALESCE(m.adres, '') AS adres FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id = z.musteri_id LEFT JOIN users u ON u.id = z.rep_id WHERE z.tenant_id = $1 AND ( (z.durum = 'TAMAMLANDI' AND z.ziyaret_tarihi::date = $2::date) OR (z.durum = 'PLANLANDI' AND COALESCE(z.planlanan_tarih, z.ziyaret_tarihi)::date = $2::date) )`;  /* BUGUN_AKTIVITE_V1 */"""
assert s.count(OLD2) == 1, "zvSql anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# 3) siralama + limit (bugun yapilan en yeni ustte)
OLD3 = '        zvSql += " ORDER BY z.ziyaret_tarihi ASC LIMIT 20";'
NEW3 = '        zvSql += " ORDER BY z.ziyaret_tarihi DESC NULLS LAST LIMIT 50";  /* BUGUN_AKTIVITE_V1 */'
assert s.count(OLD3) == 1, "order anchor count=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_AKTIVITE_V1")
