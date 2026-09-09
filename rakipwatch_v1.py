#!/usr/bin/env python3
# RAKIPWATCH_V1 — kisiye-ozel fiyata RAKIP sinyali. saha_teklif'te (musteri+ebat) rakip_fiyat varsa:
#   oneri, rakip fiyatini GECMEZ (anlasmayi savun), 12% politika tabaninin ALTINA da inmez.
#   Rakip bizden ucuzsa durum=RAKIP (savun/kes); tabana carparsa RAKIP_MALIYET. Rakip yoksa mevcut mantik.
#   Sadece /api/bi/musteri-fiyat-liste (kart + son-alim). Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "RAKIPWATCH_V1" in s:
    print("rakipwatch: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTPRICE_V2" in s, "once SMARTPRICE_V2 gerekli"

A = ("              r.marj_oneri = (floorCost > 0 && fair > 0) ? Math.round((fair - floorCost) / fair * 1000) / 10 : null;\n"
     "            }")
assert s.count(A) == 1, "musteri-fiyat-liste marj_oneri anchor (count!=1)"
N = ("              r.marj_oneri = (floorCost > 0 && fair > 0) ? Math.round((fair - floorCost) / fair * 1000) / 10 : null;\n"
     "              try { /* RAKIPWATCH_V1 */\n"
     "                if (r.ebat) {\n"
     "                  const cmp = (await query(`SELECT st.rakip_marka, st.rakip_fiyat, st.kayip_nedeni, to_char(st.created_at,'YYYY-MM-DD') tarih FROM saha_teklif st JOIN saha_musteri sm ON sm.id=st.musteri_id WHERE st.tenant_id=$1::uuid AND sm.musteri_kodu=$2 AND st.rakip_fiyat IS NOT NULL AND st.ebat=$3 AND st.created_at >= now() - INTERVAL '9 months' ORDER BY st.created_at DESC LIMIT 1`, [T, musteri, r.ebat])).rows[0];\n"
     "                  if (cmp && cmp.rakip_fiyat != null) {\n"
     "                    const rf = Math.round(Number(cmp.rakip_fiyat));\n"
     "                    r.rakip = { marka: cmp.rakip_marka || null, fiyat: rf, neden: cmp.kayip_nedeni || null, tarih: cmp.tarih || null };\n"
     "                    const minFloor = floorCost > 0 ? floorCost / 0.88 : 0;\n"
     "                    if (rf < fair) {\n"
     "                      r.oneri = Math.round(Math.max(rf, minFloor) / 250) * 250;\n"
     "                      r.durum = (rf >= minFloor) ? 'RAKIP' : 'RAKIP_MALIYET';\n"
     "                      r.marj_oneri = (floorCost > 0 && r.oneri > 0) ? Math.round((r.oneri - floorCost) / r.oneri * 1000) / 10 : null;\n"
     "                    }\n"
     "                  }\n"
     "                }\n"
     "              } catch (e) { console.error('[rakipwatch]', e && e.message); }\n"
     "            }")
s = s.replace(A, N, 1)
write(FP, s)
print("rakipwatch: musteri-fiyat-liste rakip sinyali eklendi")
print("marker count:", s.count("RAKIPWATCH_V1"))
print("DONE.")
