# -*- coding: utf-8 -*-
# ZIYARET_SIRALA_V2 — v1 karsilastirici sadece ziyaret_tarihi'ne + new Date'e bakiyordu:
#   (a) ziyaret_tarihi NULL olan (planlanan_tarih'te tutulan) kayitlar 0'a dusup KARISIYORDU
#   (b) iOS'ta parse edilemeyen formatta NaN -> sirayi BOZUYORDU.
#   Cozum: sunucudaki gibi COALESCE(ziyaret_tarihi,planlanan_tarih,created_at) + cok-formatli parse.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "ZIYARET_SIRALA_V2" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '''      liste = liste.slice().sort((a, b) => {
        const ta = a.ziyaret_tarihi ? new Date(a.ziyaret_tarihi).getTime() : 0;
        const tb = b.ziyaret_tarihi ? new Date(b.ziyaret_tarihi).getTime() : 0;
        return _ziySortDesc ? tb - ta : ta - tb;
      });'''
NEW = r'''      const _ziyTs = z => {
        const v = z.ziyaret_tarihi || z.planlanan_tarih || z.created_at || "";
        let t = v ? new Date(v).getTime() : NaN;
        if (isNaN(t)) { const mm = String(v).match(/(\d{1,2})[.\/](\d{1,2})[.\/](\d{4})/); if (mm) t = new Date(+mm[3], +mm[2] - 1, +mm[1]).getTime(); }
        return isNaN(t) ? 0 : t;
      };  /* ZIYARET_SIRALA_V2 — coalesce + iOS-guvenli cok-format parse */
      liste = liste.slice().sort((a, b) => _ziySortDesc ? _ziyTs(b) - _ziyTs(a) : _ziyTs(a) - _ziyTs(b));'''
assert s.count(OLD) == 1, "v1 sort block anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] ZIYARET_SIRALA_V2")
