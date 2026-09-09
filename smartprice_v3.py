#!/usr/bin/env python3
# SMARTPRICE_V3 — vade-fiyat menusu duzeltmesi. Onceki formulde vade placement icindeydi ve maliyet
# tabani (floor) tum vadeleri ayni degere kilitliyordu (Bridgestone gibi batik SKU'da menu duzdu).
# Yeni: placement = SADECE hacim+risk (banda konum). Sonra her vade icin ACIK finansman eklenir
# (peşin en ucuz, 90 gun en pahali). Boylece menu her zaman artan/anlamli. saha UI degismez.
# Yalnizca /api/bi/musteri-fiyat-liste (SMARTPRICE_V2) hesabini gunceller. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "SMARTPRICE_V3" in s:
    print("smartprice3: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTPRICE_V2" in s, "once SMARTPRICE_V2 uygulanmali"

OLD = '''              const fairAt = (vd) => {
                let pl = 0.45 * (1 - vol) + 0.35 * Math.min(Math.max(vd, 0), 120) / 120 + 0.20 * (1 - risk);
                pl = Math.max(0, Math.min(1, pl));
                let f = lo + pl * (hi - lo);
                if (floorCost > 0) f = Math.max(f, floorCost / 0.88);
                if (mx != null) f = Math.min(f, Math.max(mx, floorCost / 0.88));
                return Math.round(f / 250) * 250;
              };
              const fair = fairAt(gvade != null ? gvade : 45);'''
assert s.count(OLD) == 1, "fairAt block anchor (count!=1)"

NEW = '''              // SMARTPRICE_V3 — placement (banda konum) = hacim+risk; vade ACIK finansman olarak eklenir
              const RATE = 0.42; // yillik para maliyeti (vade primi icin)
              const plBase = Math.max(0, Math.min(1, 0.62 * (1 - vol) + 0.38 * (1 - risk)));
              const bandBase = lo + plBase * (hi - lo);
              const pesin = Math.max(bandBase, floorCost > 0 ? floorCost / 0.88 : bandBase);
              const fairAt = (vd) => {
                const fin = (floorCost > 0 ? floorCost : lo) * (RATE / 365) * Math.min(Math.max(vd, 0), 120);
                let f = pesin + fin;
                if (mx != null) f = Math.min(f, Math.max(mx, pesin));
                return Math.round(f / 250) * 250;
              };
              const fair = fairAt(gvade != null ? gvade : 45);'''
s = s.replace(OLD, NEW, 1)
write(FP, s)
print("smartprice3: vade menusu finansman-merdiveni ile duzeltildi")
print("marker count:", s.count("SMARTPRICE_V3"))
print("DONE.")
