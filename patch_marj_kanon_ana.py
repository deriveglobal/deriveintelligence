#!/usr/bin/env python3
# MARJ_KANON_ANA_V1 — /api/bi/ana "Bugun" odasi marj'i ERP-cikis_tutari paralel motorundan KANONA baglandi.
# ciro=bi_satis LASTIK% (retread DAHIL), marj%=bi_marj_atom akis maliyeti (Finans/Kokpit ile ayni).
# Eski: SMM=bi_stok_hareket.cikis_tutari + evren TIC+TUK (retread haric) -> marj %14,8 (sisik).
# Yeni: kanon -> %11,5 (durust). Anlati stringleri de kanona gore duzeltildi.
# 2 replace, count==1. Tek param baglami $1::text (text=uuid tuzagi yok).
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
changes = []
def apply(name, new, old):
    global src
    if new in src:
        changes.append(f"SKIP (zaten var): {name}"); return
    c = src.count(old)
    assert c == 1, f"ANCHOR COUNT != 1 ({c}) : {name}"
    src = src.replace(old, new)
    changes.append(f"OK: {name}")

# 1) query #6 -> kanon
apply(
  "ana marj query #6 -> kanon",
  """        query(`
          /* MARJ_KANON_ANA_V1 — Bugun odasi marj'i KANONA baglandi: ciro=bi_satis LASTIK% (retread DAHIL),
             marj%=bi_marj_atom akis maliyeti (Finans/Kokpit ile ayni). Eski ERP-cikis_tutari + retread-haric
             motor kaldirildi (marj %14,8 -> kanon %11,5). */
          WITH ciro AS (SELECT sum(satir_tutar) AS c, sum(miktar) AS adet FROM bi_satis_faturalari
                         WHERE tenant_id::text=$1 AND satir_tutar>0 AND fatura_tarihi >= CURRENT_DATE-365
                           AND grup_adi LIKE 'LASTIK%'),
          atom AS (SELECT sum(brut_kar) AS bk, sum(ciro) AS ac,
                          ROUND(100.0*count(*) FILTER (WHERE maliyet_kaynak='donem')/NULLIF(count(*),0)) AS kapsam
                     FROM bi_marj_atom
                    WHERE tenant_id::text=$1 AND ay >= date_trunc('month',CURRENT_DATE) - INTERVAL '12 months'),
          hiz AS (SELECT COALESCE(sum(satir_tutar),0) AS c FROM bi_satis_faturalari
                   WHERE tenant_id::text=$1 AND miktar>0 AND fatura_tarihi >= CURRENT_DATE-365
                     AND grup_adi IN ('VERILEN SERVIS HIZMET','LASTIK YENILEME')),
          prim AS (SELECT COALESCE(sum(satir_tutar),0) AS p FROM bi_satis_faturalari
                    WHERE tenant_id::text=$1 AND fatura_tarihi >= CURRENT_DATE-365
                      AND kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM'))
          SELECT ROUND(ciro.c*(1 - atom.bk/NULLIF(atom.ac,0)))        AS smm,
                 ciro.c AS ciro, ciro.adet AS satis_adet,
                 ROUND(100.0*atom.bk/NULLIF(atom.ac,0), 1)            AS marj_pct,
                 atom.kapsam                                          AS mutabakat_pct,
                 prim.p AS prim, hiz.c AS hizmet_ciro,
                 ROUND(ciro.c*(1 - atom.bk/NULLIF(atom.ac,0))/365.0)  AS gunluk_smm
            FROM ciro, atom, prim, hiz`, [T, T]),""",
  """        query(`
          WITH mus AS (SELECT DISTINCT musteri_kodu FROM bi_satis_faturalari
                        WHERE tenant_id=$1::text AND fatura_tarihi >= CURRENT_DATE-365),
          smm AS (SELECT sum(h.cikis) AS adet, sum(h.cikis_tutari) AS maliyet
                    FROM bi_stok_hareket h JOIN mus m ON m.musteri_kodu = h.muhatap_kodu
                   WHERE h.tenant_id=$2::uuid AND h.belge_tarihi >= CURRENT_DATE-365
                     AND h.hareket_sinifi IN ('SATIS_SEVK','SATIS_FATURA')
                     AND h.grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI') AND h.cikis > 0),
          ciro AS (SELECT sum(satir_tutar) AS c, sum(miktar) AS adet FROM bi_satis_faturalari
                    WHERE tenant_id=$1::text AND miktar>0 AND fatura_tarihi >= CURRENT_DATE-365
                      AND grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI')),
          hiz AS (SELECT COALESCE(sum(satir_tutar),0) AS c FROM bi_satis_faturalari
                   WHERE tenant_id=$1::text AND miktar>0 AND fatura_tarihi >= CURRENT_DATE-365
                     AND grup_adi IN ('VERILEN SERVIS HIZMET','LASTIK YENILEME')),
          prim AS (SELECT COALESCE(sum(satir_tutar),0) AS p FROM bi_satis_faturalari
                    WHERE tenant_id=$1::text AND fatura_tarihi >= CURRENT_DATE-365
                      AND kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM'))
          SELECT s.maliyet AS smm, c.c AS ciro, s.adet AS smm_adet, c.adet AS satis_adet,
                 ROUND(100.0*(1 - s.maliyet/NULLIF(c.c,0)), 1)      AS marj_pct,
                 ROUND(100.0*s.adet/NULLIF(c.adet,0))               AS mutabakat_pct,
                 p.p AS prim, h.c AS hizmet_ciro,
                 ROUND(s.maliyet/365.0)                             AS gunluk_smm
            FROM smm s, ciro c, prim p, hiz h`, [T, T]),""",
)

# 2) anlati stringleri kanona
apply(
  "ana marj anlati stringleri",
  """            kaynak: 'Kanon akış maliyeti (bi_marj_atom) — Finans ve Kokpit ile aynı', /* MARJ_KANON_ANA_V1 */
            sinir : 'Prim (teşvik) öncesi brüt marj',
            kapsam: 'Tüm lastik, retread dahil (grup_adi LIKE LASTIK%); jant/akü/servis hariç.',
            mutabakat: 'Maliyet kapsamı %' + Number(m.mutabakat_pct||0) + ' — dönem-maliyeti eşleşen kalem oranı.'""",
  """            kaynak: 'ERP maliyet kaydı (bi_stok_hareket.birim_maliyet) — modellenmiş değil',
            sinir : 'ALT SINIR: fatura maliyeti = prim öncesi brüt',
            kapsam: 'Sadece lastik ticareti. Kaplama ve servis hariç — maliyet yapısı farklı.',
            mutabakat: 'Adet oranı %' + Number(m.mutabakat_pct||0) + ' — maliyet ve ciro aynı malı ölçüyor.'""",
)

if src == orig:
    print("DEGISIKLIK YOK")
else:
    bak = PATH + ".bak_marjana_" + time.strftime("%Y%m%d_%H%M%S")
    shutil.copyfile(PATH, bak); print("YEDEK:", bak)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(src)
for c in changes: print(" ", c)
print("MARJ_KANON_ANA_V1 marker:", src.count("MARJ_KANON_ANA_V1"))
