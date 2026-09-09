#!/usr/bin/env python3
# HARITA_ILMETRIK_V3 — harita risk metriklerini NET bazina tasi (CEO asistaniyla ayni mantik).
#   Sorun: ham vadesi_gecmis/hesap_bakiyesi kullaniliyordu -> MUTAFLAR/ROTA gibi cift-rol (musteri+tedarikci)
#     hesaplar brutte devasa gorunuyor. Kanonik cozum zaten var: bi_cari_bakiye.tedarikci_bakiye ile
#     ayni muhataba KRB borcu mahsup edilir -> NET gecikmis = GREATEST(vg + borc, 0). grup TEDAR haric.
#   Degisiklik: 'Gecikme orani' (overdue/bakiye — kumulatif vadesi_gecmis'e dayali, bozuk) ve ham 'overdue' KALDIRILDI;
#     yerine NET gecikmis alacak (net_gecikmis) geldi. bakiye + net_risk korunur. Otomatik (kod bazli), hardcode YOK.
# server_container.mjs. Idempotent, marker-guardli. HARITA_ILMETRIK_V2 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_ILMETRIK_V3" in s:
    print("ilmetrik-v3: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_ILMETRIK_V2" in s, "HARITA_ILMETRIK_V2 yok"

# (R1) cb CTE ekle + risk CTE: overdue->vg, grup ekle
A1 = ('          "WITH cs AS (SELECT musteri_kodu, MAX(sehir) sehir FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir IS NOT NULL AND sehir<>\'\' GROUP BY musteri_kodu),"\n'
      '          + " risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(hesap_bakiyesi,0) bakiye, COALESCE(vadesi_gecmis,0) overdue, COALESCE(toplam_risk,0) net_risk FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi ORDER BY muhatap_kodu, export_date DESC),"\n')
assert s.count(A1) == 1, "cs+risk anchor"
N1 = ('          "WITH cs AS (SELECT musteri_kodu, MAX(sehir) sehir FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir IS NOT NULL AND sehir<>\'\' GROUP BY musteri_kodu),"\n'
      '          + " cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu),"\n'
      '          + " risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(hesap_bakiyesi,0) bakiye, GREATEST(COALESCE(vadesi_gecmis,0),0) vg, COALESCE(toplam_risk,0) net_risk, COALESCE(NULLIF(TRIM(grup),\'\'),\'\') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi ORDER BY muhatap_kodu, export_date DESC),"\n')
s = s.replace(A1, N1, 1)

# (R2) il_risk: NET gecikmis (vg+borc) + cb join + grup TEDAR haric
A2 = '          + " il_risk AS (SELECT cs.sehir il, SUM(GREATEST(r.overdue,0)) overdue, SUM(GREATEST(r.bakiye,0)) bakiye, SUM(GREATEST(r.net_risk,0)) net_risk FROM risk r JOIN cs ON cs.musteri_kodu=r.muhatap_kodu GROUP BY cs.sehir),"\n'
assert s.count(A2) == 1, "il_risk anchor"
N2 = '          + " il_risk AS (SELECT cs.sehir il, SUM(GREATEST(r.vg+COALESCE(cb.borc,0),0)) net_gecikmis, SUM(GREATEST(r.bakiye,0)) bakiye, SUM(GREATEST(r.net_risk,0)) net_risk FROM risk r JOIN cs ON cs.musteri_kodu=r.muhatap_kodu LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu WHERE r.grup NOT ILIKE \'%TEDAR%\' GROUP BY cs.sehir),"\n'
s = s.replace(A2, N2, 1)

# (R3) final SELECT risk kolonlari: net_gecikmis, gecikme_orani KALDIR
A3 = ('          + " k.overdue, k.bakiye, COALESCE(k.net_risk,0)::numeric net_risk,"\n'
      '          + " CASE WHEN COALESCE(k.bakiye,0)>=1000 THEN LEAST(1.0,(k.overdue/k.bakiye))::numeric ELSE NULL END gecikme_orani"\n')
assert s.count(A3) == 1, "SELECT risk cols anchor"
N3 = '          + " COALESCE(k.net_gecikmis,0)::numeric net_gecikmis, COALESCE(k.bakiye,0)::numeric bakiye, COALESCE(k.net_risk,0)::numeric net_risk"\n'
s = s.replace(A3, N3, 1)

# (R4) mapping: net_gecikmis; overdue + gecikme_orani KALDIR
A4 = '        iller = r.rows.map(x => ({ il: x.il, ciro: Number(x.ciro||0), adet: Number(x.adet||0), ciro_tuketici: Number(x.ciro_tuketici||0), ciro_ticari: Number(x.ciro_ticari||0), overdue: Number(x.overdue||0), bakiye: Number(x.bakiye||0), net_risk: Number(x.net_risk||0), gecikme_orani: x.gecikme_orani != null ? Number(x.gecikme_orani) : null }));\n'
assert s.count(A4) == 1, "mapping anchor"
N4 = '        iller = r.rows.map(x => ({ il: x.il, ciro: Number(x.ciro||0), adet: Number(x.adet||0), ciro_tuketici: Number(x.ciro_tuketici||0), ciro_ticari: Number(x.ciro_ticari||0), net_gecikmis: Number(x.net_gecikmis||0), bakiye: Number(x.bakiye||0), net_risk: Number(x.net_risk||0) })); /* HARITA_ILMETRIK_V3 */\n'
s = s.replace(A4, N4, 1)

write(FP, s)
print("ilmetrik-v3: NET gecikmis (bi_cari_bakiye mahsup) + grup TEDAR haric; gecikme orani/ham overdue kaldirildi")
print("marker:", s.count("HARITA_ILMETRIK_V3"), "| cb CTE:", s.count("cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0))"))
print("DONE.")
