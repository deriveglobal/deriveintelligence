#!/usr/bin/env python3
# MARKATIER_PRICE_V1 — Kisiye-ozel fiyat TABANINI da markaya-ozel hedefe bagla.
#   musteri-fiyat-liste: pesin taban = floorCost/(1 - brand_hedef) (onceki sabit /0.88 = %12 yerine).
#   SKUQ'ya brand_hedef sutunu (o kalemin markasinin p60 hedefi, taban 0.12 tavan 0.30) eklenir.
# Boylece Sailun onerisi ~%26 marja, ince premium %12'ye nisan alir. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "MARKATIER_PRICE_V1" in s:
    print("markatier-price: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTPRICE_V3" in s and "MARKATIER_V1" in s, "once SMARTPRICE_V3 + MARKATIER_V1 gerekli"

# (1) SKUQ + V1 SKU sorgusuna brand_hedef sutunu (ebat sutunundan sonra) — her ikisine (replace_all)
A_col = "(SELECT max(ebat) FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2) ebat"
n_col = s.count(A_col)
assert n_col >= 1, "SKU ebat sutunu bulunamadi"
N_col = ("(SELECT max(ebat) FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2) ebat,\n"
         "             (SELECT GREATEST(0.12, LEAST(0.30, percentile_cont(0.6) WITHIN GROUP (ORDER BY m))) "
         "FROM (SELECT SUM(brut_kar)/NULLIF(SUM(ciro),0) m FROM bi_marj_atom "
         "WHERE tenant_id::text=$1 AND marka=(SELECT max(marka) FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2) "
         "AND ebat IS NOT NULL AND ebat<>'' AND ay>=(CURRENT_DATE-INTERVAL '12 months') "
         "GROUP BY kalem_kodu HAVING SUM(adet)>=20 AND SUM(ciro)>0) x) brand_hedef /* MARKATIER_PRICE_V1 */")
s = s.replace(A_col, N_col)

# (2) musteri-fiyat-liste fairAt tabani: floorCost/0.88 -> floorCost/(1-brandH)
A_p = "              const pesin = Math.max(bandBase, floorCost > 0 ? floorCost / 0.88 : bandBase);"
assert s.count(A_p) == 1, "pesin taban satiri bulunamadi"
N_p = ("              const brandH = (p.brand_hedef != null) ? Math.max(0.12, Math.min(0.30, Number(p.brand_hedef))) : 0.12; /* MARKATIER_PRICE_V1 */\n"
       "              const pesin = Math.max(bandBase, floorCost > 0 ? floorCost / (1 - brandH) : bandBase);")
s = s.replace(A_p, N_p, 1)

write(FP, s)
print("markatier-price: SKU brand_hedef sutunu x%d + pesin taban markaya-ozel" % n_col)
print("marker count:", s.count("MARKATIER_PRICE_V1"))
print("DONE.")
