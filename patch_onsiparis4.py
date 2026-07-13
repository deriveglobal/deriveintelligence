#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ONSIPARIS_V4 — EBAT NORMALIZASYONU. Kendi kapim kendini vurdu; duzeltiyorum.
#
# ⚠ V3'UN OZ-DOGRULAMASI GECMEDI: %92,7 (esik %95).
#   Kodu KORU KORUNE koymadim; kapi patladi, sebebe baktim.
#
# UYUSMAYANLAR SISTEMATIK VE ACIKLANABILIR:
#   "225/45ZR17 94Y XL US71"  -> ilk kelime 225/45ZR17  · ERP: 225/45R17
#   "205/55ZR16 94Y XL"       -> ilk kelime 205/55ZR16  · ERP: 205/55R16
#   "225/75 R17.5 129M"       -> ilk kelime 225/75      · ERP: 225/75R17.5
#
#   Iki fark:
#     1) 'Z' HIZ ENDEKSI — ERP atiyor, urun adi tasiyor. AYNI LASTIK.
#     2) 'R'den ONCE BOSLUK — "225/75 R17.5" tek token degil.
#
#   Yani yontem DOGRU, NORMALIZASYON eksikti.
#
# ✅ COZUM:
#   1) Bosluklari AT      -> "225/75 R17.5 129M" -> "225/75R17.5129M"
#   2) SINIRLI kalip yakala (greedy olmasin):
#        ^([0-9]{2,3}(/[0-9]{2,3})?(\.[0-9]{2})?Z?R[0-9]{2}(\.[0-9])?C?)
#      "245/40R1897VBLIZZAK" -> 245/40R18   (R[0-9]{2} sinirli -> '1897' YEMEZ)
#      "185R14C102/100R..."  -> 185R14C
#      "12.00R24VCHSZ"       -> 12.00R24
#   3) ZR -> R  (hiz endeksini at)
#
# ⚠ Hala %95 altinda kalirsa KULLANMAYIZ. Kapi kapali kalir.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# Yardimci: SUTUN 0 (global). SQL tarafinda da ayni mantik kullanilacak.
rep("""// ONSIPARIS_V1 ═══════════════════════════════════════════════════════════""",
"""// ONSIPARIS_V4 — EBAT NORMALIZASYONU (SQL ifadesi, tek yerde tanimli)
//   ⚠ Urun adindan ebat cikarirken IKI sistematik fark vardi:
//     'Z' hiz endeksi (225/45ZR17 vs 225/45R17) ve 'R' oncesi bosluk (225/75 R17.5).
//   Ayni lastik, farkli yazim. Normalize etmeden eslestirirsek ayri ebat sanariz
//   -> mevcut stok bolunur -> eksik SISER -> FAZLA SIPARIS.
const _EBAT_SQL = `
  NULLIF(replace(
    substring(replace(upper($TANIM$), ' ', '')
              from '^([0-9]{2,3}(/[0-9]{2,3})?(\\\\.[0-9]{2})?Z?R[0-9]{2}(\\\\.[0-9])?C?)'),
    'ZR', 'R'), '')`;

// ONSIPARIS_V1 ═══════════════════════════════════════════════════════════""",
    "v4-ebat-sql-sabit")


# stok_ebat CTE'sinde ham 'ilk kelime' yerine NORMALIZE edilmis ebat
rep("""      stok_ebat AS (
        SELECT s.kalem_kodu, s.adet,
               COALESCE(ke.ebat, substring(s.kalem_tanimi from '^([^ ]+)')) AS ebat,
               CASE WHEN ke.ebat IS NOT NULL THEN 'erp' ELSE 'turetilmis' END AS ebat_kaynagi
          FROM bi_stok_anlik s
          LEFT JOIN kod_ebat ke ON ke.kalem_kodu = s.kalem_kodu
         WHERE s.tenant_id = $1::uuid AND s.adet > 0 AND s.sezon ILIKE $2
           AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)
      ),""",
"""      -- ONSIPARIS_V4: 'ilk kelime' YETMEDI (oz-dogrulama %92,7, esik %95).
      --   Z hiz endeksi ve R oncesi bosluk sistematik fark yaratiyordu.
      --   Simdi: bosluklari at -> sinirli kalip yakala -> ZR'yi R yap.
      stok_ebat AS (
        SELECT s.kalem_kodu, s.adet,
               COALESCE(
                 ke.ebat,
                 NULLIF(replace(
                   substring(replace(upper(s.kalem_tanimi), ' ', '')
                             from '^([0-9]{2,3}(/[0-9]{2,3})?(\\\\.[0-9]{2})?Z?R[0-9]{2}(\\\\.[0-9])?C?)'),
                   'ZR', 'R'), '')
               ) AS ebat,
               CASE WHEN ke.ebat IS NOT NULL THEN 'erp' ELSE 'turetilmis' END AS ebat_kaynagi
          FROM bi_stok_anlik s
          LEFT JOIN kod_ebat ke ON ke.kalem_kodu = s.kalem_kodu
         WHERE s.tenant_id = $1::uuid AND s.adet > 0 AND s.sezon ILIKE $2
           AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)
      ),""",
    "v4-stok-ebat-normalize")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
