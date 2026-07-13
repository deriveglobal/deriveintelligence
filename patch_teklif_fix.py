#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# TEKLIF_V2_FIX — Fatih hakli: CEO aracinda AGIRLIKLI SATIS FIYATI yoktu.
#   Sadece agirlikli satis VADESI vardi. /analiz endpoint'inde fiyat da var,
#   ama asistanin gordugu tool ciktisinda yoktu -> asistan "kaca satiyoruz"
#   sorusuna agirlikli ortalamayi soyleyemezdi.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) SQL: agirlikli satis FIYATINI da cek
rep("""            " LEFT JOIN LATERAL (SELECT ROUND(SUM(miktar*(vade_tarihi-fatura_tarihi))/NULLIF(SUM(miktar),0)) AS ag_satis_vade " +
            "  FROM bi_satis_faturalari sv WHERE sv.tenant_id=t.tenant_id::text AND sv.kalem_kodu=t.kalem_kodu " +
            "    AND sv.vade_tarihi IS NOT NULL AND sv.fatura_tarihi >= date_trunc('year', CURRENT_DATE)) sv ON true " +""",
"""            " LEFT JOIN LATERAL (SELECT ROUND(SUM(miktar*(vade_tarihi-fatura_tarihi))/NULLIF(SUM(miktar),0)) AS ag_satis_vade, " +
            "    ROUND(SUM(miktar*birim_fiyat)/NULLIF(SUM(miktar),0)) AS ag_satis_fiyat " +
            "  FROM bi_satis_faturalari sv WHERE sv.tenant_id=t.tenant_id::text AND sv.kalem_kodu=t.kalem_kodu " +
            "    AND sv.birim_fiyat > 0 AND sv.vade_tarihi IS NOT NULL " +
            "    AND sv.fatura_tarihi >= date_trunc('year', CURRENT_DATE)) sv ON true " +""",
    "sql-agirlikli-satis-fiyat")

# 2) SELECT listesine ekle
rep("""            " al.ag_alis, al.ag_alis_vade, sv.ag_satis_vade, " +""",
"""            " al.ag_alis, al.ag_alis_vade, sv.ag_satis_vade, sv.ag_satis_fiyat, " +""",
    "select-agirlikli-satis-fiyat")

# 3) Cikti nesnesine ekle
rep("""              agirlikli_alis_vadesi_gun: num(t.ag_alis_vade),
              agirlikli_satis_vadesi_gun: num(t.ag_satis_vade),""",
"""              agirlikli_alis_fiyati: num(t.ag_alis),            // gecmiste odedigimiz (batik)
              agirlikli_alis_vadesi_gun: num(t.ag_alis_vade),
              agirlikli_satis_fiyati: num(t.ag_satis_fiyat),    // bu yil ortalama kaca sattik
              agirlikli_satis_vadesi_gun: num(t.ag_satis_vade),""",
    "cikti-agirlikli-satis-fiyat")

# 4) Asistana anlat
rep("""            'agirlikli_alis_vadesi_gun / agirlikli_satis_vadesi_gun = kaç günde ödüyoruz / kaç günde tahsil ediyoruz. ' +""",
"""            'agirlikli_alis_fiyati / agirlikli_satis_fiyati = bu yıl ağırlıklı ortalama kaça aldık / kaça sattık (miktarla ağırlıklı). ' +
            'agirlikli_alis_vadesi_gun / agirlikli_satis_vadesi_gun = kaç günde ödüyoruz / kaç günde tahsil ediyoruz. ' +""",
    "desc-agirlikli-satis-fiyat")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
