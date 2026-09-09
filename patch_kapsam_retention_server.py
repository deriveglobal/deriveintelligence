# -*- coding: utf-8 -*-
# KAPSAM_RETENTION_V1 (server) — /api/saha/rapor/kapsam satirlarina tekrar-alim (retention) sinyali.
#   Additive: 3 CTE (h1r/h2r/vis12) + 3 kolon + 3 join + mapRow.tk {vc, durum}.
#   durum: sadik (son 6 ay aldi) / kayiyor (onceki 6 ay aldi, son 6 ay YOK) / sessiz.
#   CURRENT_DATE bazli (kapsam ciro penceresiyle tutarli). Yeni param yok.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "KAPSAM_RETENTION_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) CTE'ler — mute'dan sonra
o1 = """           ORDER BY musteri_id, olusturma_ts DESC
        )
        SELECT m.id::text id, m.firma, m.il, m.ilce, m.tip, m.sorumlu_rep::text rid, m.musteri_kodu,"""
n1 = """           ORDER BY musteri_id, olusturma_ts DESC
        ),
        h1r AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric v FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '360 days') AND fatura_tarihi < (CURRENT_DATE - INTERVAL '180 days') GROUP BY musteri_kodu),  /* KAPSAM_RETENTION_V1 */
        h2r AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric v FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '180 days') GROUP BY musteri_kodu),
        vis12 AS (SELECT musteri_id, COUNT(*) c FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' AND ziyaret_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_id)
        SELECT m.id::text id, m.firma, m.il, m.ilce, m.tip, m.sorumlu_rep::text rid, m.musteri_kodu,"""
assert s.count(o1) == 1, "cte anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) kolonlar
o2 = """               mu.gerekce, mu.gerekce_metin, mu.aktor_id::text mute_by, mu.olusturma_ts mute_ts
          FROM saha_musteri m"""
n2 = """               mu.gerekce, mu.gerekce_metin, mu.aktor_id::text mute_by, mu.olusturma_ts mute_ts,
               COALESCE(h1r.v,0)::numeric h1, COALESCE(h2r.v,0)::numeric h2, COALESCE(vis12.c,0)::int vc12  /* KAPSAM_RETENTION_V1 */
          FROM saha_musteri m"""
assert s.count(o2) == 1, "kolon anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) join'ler
o3 = """          LEFT JOIN mute mu ON mu.musteri_id=m.id
         WHERE m.tenant_id::text=$1::text AND m.aktif=true${repF}${tipF}`, p);"""
n3 = """          LEFT JOIN mute mu ON mu.musteri_id=m.id
          LEFT JOIN h1r ON h1r.musteri_kodu=m.musteri_kodu
          LEFT JOIN h2r ON h2r.musteri_kodu=m.musteri_kodu
          LEFT JOIN vis12 ON vis12.musteri_id=m.id
         WHERE m.tenant_id::text=$1::text AND m.aktif=true${repF}${tipF}`, p);"""
assert s.count(o3) == 1, "join anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

# 4) mapRow.tk
o4 = "const mapRow = (x) => ({ id: x.id, firma: x.firma, il: x.il, tip: x.tip, ciro: Number(x.ciro) || 0, gun: gunOf(x.son), rep: x.rid ? (nameMap[x.rid] || null) : null, rep_id: x.rid || null });"
n4 = "const mapRow = (x) => ({ id: x.id, firma: x.firma, il: x.il, tip: x.tip, ciro: Number(x.ciro) || 0, gun: gunOf(x.son), rep: x.rid ? (nameMap[x.rid] || null) : null, rep_id: x.rid || null, tk: { vc: Number(x.vc12) || 0, durum: (Number(x.h2) > 0 ? \"sadik\" : Number(x.h1) > 0 ? \"kayiyor\" : \"sessiz\") } });  /* KAPSAM_RETENTION_V1 */"
assert s.count(o4) == 1, "mapRow anchor=%d" % s.count(o4)
s = s.replace(o4, n4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_RETENTION_V1 (server) — retention alanlari kapsam satirlarina")
