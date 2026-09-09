import sys, io
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
if "ZIYARET_LISTE_HAFIF_V1" in s:
    print("[patch_ziyaret_hafif] zaten uygulanmis, atlaniyor."); sys.exit(0)
OLD = "               z.katilimci, z.notlar, z.detay, z.kaynak, z.created_at,"
NEW = "               z.katilimci, left(z.notlar, 240) AS notlar, z.detay, z.kaynak, z.created_at, -- ZIYARET_LISTE_HAFIF_V1 (liste notu kisaltildi; detay tam kaydi ceker)"
if s.count(OLD) != 1:
    sys.stderr.write("[patch_ziyaret_hafif] HATA: anchor %d (1 bekleniyordu)\n" % s.count(OLD)); sys.exit(2)
io.open(p,"w",encoding="utf-8").write(s.replace(OLD,NEW,1))
print("[patch_ziyaret_hafif] uygulandi.")
