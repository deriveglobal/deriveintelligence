import sys, io
p = sys.argv[1]; s = io.open(p, encoding="utf-8").read()
if "ZIYARET_LIMIT_V1" in s:
    print("[patch_ziyaret_limit] zaten uygulanmis, atlaniyor."); sys.exit(0)
OLD = "      sql += ` ORDER BY COALESCE(z.ziyaret_tarihi, z.planlanan_tarih) DESC NULLS LAST, z.created_at DESC LIMIT 200`;"
NEW = "      sql += ` ORDER BY COALESCE(z.ziyaret_tarihi, z.planlanan_tarih) DESC NULLS LAST, z.created_at DESC LIMIT 1000`; // ZIYARET_LIMIT_V1 (200->1000; tum repler gecmisi gorsun)"
if s.count(OLD) != 1:
    sys.stderr.write("[patch_ziyaret_limit] HATA: anchor %d (1 bekleniyordu)\n" % s.count(OLD)); sys.exit(2)
io.open(p,"w",encoding="utf-8").write(s.replace(OLD,NEW,1))
print("[patch_ziyaret_limit] uygulandi.")
