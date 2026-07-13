#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# IADE_V1 — IADE satirlari (miktar < 0) fiyat analizinden CIKARILSIN.
#
# BULGU (son_bes.sh):
#   PRATİK OTOMOTİV  ATIRE 315/45-12  miktar = -2  satir_tutar = -31.468
#   UZUNSOY          SAILUN 385/65R22.5  miktar = -1  satir_tutar = -3.791
#   -> Bunlar SATIS degil, IADE / alacak dekontu.
#
# HATA: /analiz sorgulari 'birim_fiyat > 0' filtreliyor ama 'miktar > 0' FILTRELEMIYOR.
#   Sonuc:
#     • min/medyan/maks araligina IADE satirlari karisiyor
#     • "en ucuz bu musteri aldi" derken bir IADEYI gosterebiliyor
#     • agirlikli ortalama fiyat/vade NEGATIF miktarla agirliklaniyor
#       (SUM(miktar*fiyat)/SUM(miktar) -> iade agirligi TERS isaretli, sonucu bozar)
#
# ⚠ En sinsisi sonuncusu: agirlikli ortalama sessizce kayiyor. Hata vermiyor.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# 1) KENDI SATIS GECMISI — min/medyan/maks + en ucuz/en pahali musteri
rep("""              " FROM bi_satis_faturalari " +
              " WHERE tenant_id=$1::text AND ebat=$2 AND upper(marka)=upper($3) " +
              "   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 " +
              "   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)",""",
"""              " FROM bi_satis_faturalari " +
              " WHERE tenant_id=$1::text AND ebat=$2 AND upper(marka)=upper($3) " +
              "   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 " +
              // IADE_V1: miktar<0 = iade/alacak dekontu. SATIS DEGIL.
              //   Araliga ve "en ucuz musteri"ye karismasin.
              "   AND miktar > 0 " +
              "   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)",""",
    "kendi-satis-iade")


# 2) AGIRLIKLI SATIS — SUM(miktar*fiyat)/SUM(miktar); negatif miktar sonucu BOZAR
rep("""              "    FROM bi_satis_faturalari " +
              "   WHERE tenant_id=$1::text AND kalem_kodu=$2 AND birim_fiyat>0 " +
              "     AND vade_tarihi IS NOT NULL " +""",
"""              "    FROM bi_satis_faturalari " +
              "   WHERE tenant_id=$1::text AND kalem_kodu=$2 AND birim_fiyat>0 " +
              // IADE_V1: agirlikli ortalamada negatif miktar TERS isaretli agirlik
              //   verir ve sonucu SESSIZCE kaydirir. Hata vermez. En sinsi hali.
              "     AND miktar > 0 " +
              "     AND vade_tarihi IS NOT NULL " +""",
    "agirlikli-satis-iade")


# 3) AGIRLIKLI ALIS — ayni sorun, tedarikci iadeleri
rep("""              "   WHERE tenant_id=$1::uuid AND kalem_kodu=$2 AND birim_fiyat_kdv_haric>0 " +
              "     AND vade_gun IS NOT NULL " +""",
"""              "   WHERE tenant_id=$1::uuid AND kalem_kodu=$2 AND birim_fiyat_kdv_haric>0 " +
              "     AND miktar > 0 " +          // IADE_V1: tedarikci iadesi de agirligi bozar
              "     AND vade_gun IS NOT NULL " +""",
    "agirlikli-alis-iade")


# 4) SON ALIS FIYATI (ikame maliyeti) — iade faturasindan maliyet TURETME
rep("""    "  FROM bi_tedarikci_faturalari " +
    " WHERE tenant_id=$1::uuid AND kalem_kodu=$2 AND birim_fiyat_kdv_haric > 0 " +
    " ORDER BY fatura_tarihi DESC LIMIT 1",""",
"""    "  FROM bi_tedarikci_faturalari " +
    " WHERE tenant_id=$1::uuid AND kalem_kodu=$2 AND birim_fiyat_kdv_haric > 0 " +
    "   AND miktar > 0 " +                      // IADE_V1: iade satiri maliyet DEGILDIR
    " ORDER BY fatura_tarihi DESC LIMIT 1",""",
    "son-alis-iade")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
