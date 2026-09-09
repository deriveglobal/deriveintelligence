#!/usr/bin/env python3
# HARITA_ILMETRIK_V2 — harita-il-metrikler cok-metrik genisletme + gecikme clamp/floor.
#   Ekler: net_risk (toplam_risk), ciro_tuketici/ciro_ticari (saha_musteri.tip split), overdue/bakiye zaten vardi.
#   Gecikme artefakti duzeltmesi: LEAST(1.0, overdue/bakiye) (>%100 kirpilir) + bakiye>=1000 taban (kucuk hesap gurultusu -> null/gri).
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_ILMETRIK_V2" in s:
    print("ilmetrik-v2: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_GEO_V1" in s, "HARITA_GEO_V1 yok"

# (A) risk CTE: net_risk (toplam_risk) ekle
A = 'COALESCE(vadesi_gecmis,0) overdue FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi ORDER BY muhatap_kodu, export_date DESC),"'
assert s.count(A) == 1, "risk CTE anchor"
N = 'COALESCE(vadesi_gecmis,0) overdue, COALESCE(toplam_risk,0) net_risk FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi ORDER BY muhatap_kodu, export_date DESC),"'
s = s.replace(A, N, 1)

# (B) il_risk CTE: net_risk topla
B = 'SUM(GREATEST(r.bakiye,0)) bakiye FROM risk r JOIN cs ON cs.musteri_kodu=r.muhatap_kodu GROUP BY cs.sehir),"'
assert s.count(B) == 1, "il_risk CTE anchor"
NB = 'SUM(GREATEST(r.bakiye,0)) bakiye, SUM(GREATEST(r.net_risk,0)) net_risk FROM risk r JOIN cs ON cs.musteri_kodu=r.muhatap_kodu GROUP BY cs.sehir),"'
s = s.replace(B, NB, 1)

# (C) il_satis CTE kapanisina il_tip CTE ekle (tuketici/ticari ciro)
C = '          + " il_satis AS (SELECT sehir il, SUM(satir_tutar) ciro, SUM(miktar) adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir IS NOT NULL AND sehir<>\'\' AND ($2::date IS NULL OR fatura_tarihi BETWEEN $2 AND $3) GROUP BY sehir)"\n'
assert s.count(C) == 1, "il_satis CTE anchor"
NC = (
    '          + " il_satis AS (SELECT sehir il, SUM(satir_tutar) ciro, SUM(miktar) adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir IS NOT NULL AND sehir<>\'\' AND ($2::date IS NULL OR fatura_tarihi BETWEEN $2 AND $3) GROUP BY sehir),"\n'
    '          + " il_tip AS (SELECT f.sehir il, SUM(f.satir_tutar) FILTER (WHERE sm.tip=\'TUKETICI\') ciro_tuketici, SUM(f.satir_tutar) FILTER (WHERE sm.tip=\'TICARI\') ciro_ticari FROM bi_satis_faturalari f JOIN saha_musteri sm ON sm.musteri_kodu=f.musteri_kodu AND sm.tenant_id::text=$1 WHERE f.tenant_id::text=$1 AND f.sehir IS NOT NULL AND f.sehir<>\'\' AND ($2::date IS NULL OR f.fatura_tarihi BETWEEN $2 AND $3) GROUP BY f.sehir)"\n'
)
s = s.replace(C, NC, 1)

# (D) SELECT + FROM: yeni kolonlar + gecikme clamp/floor + il_tip LEFT JOIN
D = (
    '          + " SELECT COALESCE(s.il, k.il) il, COALESCE(s.ciro,0)::numeric ciro, COALESCE(s.adet,0)::numeric adet,"\n'
    '          + " k.overdue, k.bakiye, CASE WHEN COALESCE(k.bakiye,0)>0 THEN (k.overdue/k.bakiye)::numeric ELSE NULL END gecikme_orani"\n'
    '          + " FROM il_satis s FULL JOIN il_risk k ON k.il=s.il WHERE COALESCE(s.il,k.il) IS NOT NULL", [T, gFrom, gTo]);\n'
)
assert s.count(D) == 1, "SELECT/FROM anchor"
ND = (
    '          + " SELECT COALESCE(s.il, k.il) il, COALESCE(s.ciro,0)::numeric ciro, COALESCE(s.adet,0)::numeric adet,"\n'
    '          + " COALESCE(t.ciro_tuketici,0)::numeric ciro_tuketici, COALESCE(t.ciro_ticari,0)::numeric ciro_ticari,"\n'
    '          + " k.overdue, k.bakiye, COALESCE(k.net_risk,0)::numeric net_risk,"\n'
    '          + " CASE WHEN COALESCE(k.bakiye,0)>=1000 THEN LEAST(1.0,(k.overdue/k.bakiye))::numeric ELSE NULL END gecikme_orani"\n'
    '          + " FROM il_satis s FULL JOIN il_risk k ON k.il=s.il LEFT JOIN il_tip t ON t.il=COALESCE(s.il,k.il) WHERE COALESCE(s.il,k.il) IS NOT NULL", [T, gFrom, gTo]); /* HARITA_ILMETRIK_V2 */\n'
)
s = s.replace(D, ND, 1)

# (E) mapping: yeni alanlar
E = '        iller = r.rows.map(x => ({ il: x.il, ciro: Number(x.ciro||0), adet: Number(x.adet||0), gecikme_orani: x.gecikme_orani != null ? Number(x.gecikme_orani) : null }));\n'
assert s.count(E) == 1, "mapping anchor"
NE = '        iller = r.rows.map(x => ({ il: x.il, ciro: Number(x.ciro||0), adet: Number(x.adet||0), ciro_tuketici: Number(x.ciro_tuketici||0), ciro_ticari: Number(x.ciro_ticari||0), overdue: Number(x.overdue||0), bakiye: Number(x.bakiye||0), net_risk: Number(x.net_risk||0), gecikme_orani: x.gecikme_orani != null ? Number(x.gecikme_orani) : null }));\n'
s = s.replace(E, NE, 1)

write(FP, s)
print("ilmetrik-v2: net_risk + tuketici/ticari ciro + gecikme clamp/floor eklendi")
print("marker count:", s.count("HARITA_ILMETRIK_V2"))
print("DONE.")
