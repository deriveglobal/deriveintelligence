#!/usr/bin/env python3
# MARKATIER_V1 — SKU marj alarmini SABIT %12 yerine MARKAYA-OZEL hedefe gecir.
#   Hedef(marka) = GREATEST(taban, LEAST(0.30, marka SKU-marj p60)). Taban = url param (vars. 0.12).
#   Sailun ~%26.5, Bridgestone/Continental %12 taban, Hubtrac/Karkas %30 tavan.
#   /api/bi/marj-alarm (per-row hedef) + /api/bi/marj-alarm-desen (marka hedefi). Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "MARKATIER_V1" in s:
    print("markatier: already present, skip"); print("DONE."); raise SystemExit

# ---- (A) marj-alarm SORGUSU ----
OLD_Q = """`WITH sku AS (
             SELECT marka, ebat, SUM(adet) adet, SUM(ciro) ciro, SUM(brut_kar) kar
             FROM bi_marj_atom WHERE tenant_id::text=$1 AND ay >= (CURRENT_DATE - ($2::int * INTERVAL '1 month'))
               AND ebat IS NOT NULL AND ebat<>'' GROUP BY marka, ebat),
           kmap AS (
             SELECT DISTINCT marka, ebat, kalem_kodu FROM bi_satis_faturalari
             WHERE tenant_id::text=$1 AND ebat IS NOT NULL AND ebat<>'' AND grup_adi LIKE 'LASTIK%'),
           repl AS (
             SELECT k.marka, k.ebat, SUM(t.satir_kdv_haric)/NULLIF(SUM(t.miktar),0) repl_cost
             FROM kmap k JOIN bi_tedarikci_faturalari t ON t.tenant_id::text=$1 AND t.kalem_kodu=k.kalem_kodu
             WHERE t.fatura_tarihi >= (CURRENT_DATE - INTERVAL '90 days')
             GROUP BY k.marka, k.ebat)
           SELECT s.marka, s.ebat, s.adet::int adet,
             round(s.ciro)::float8 ciro,
             round(s.kar/NULLIF(s.ciro,0)*100, 1)::float8 marj_pct,
             round(s.ciro/NULLIF(s.adet,0))::float8 avg_satis,
             round((s.ciro-s.kar)/NULLIF(s.adet,0))::float8 avg_maliyet,
             round(r.repl_cost)::float8 repl_cost,
             round($3::numeric*s.ciro - s.kar)::float8 leak
           FROM sku s LEFT JOIN repl r ON r.marka=s.marka AND r.ebat=s.ebat
           WHERE s.ciro>0 AND s.kar/NULLIF(s.ciro,0) < $3::numeric AND s.adet >= $4
           ORDER BY ($3::numeric*s.ciro - s.kar) DESC LIMIT 300`"""
NEW_Q = """`WITH sku AS (
             SELECT marka, ebat, SUM(adet) adet, SUM(ciro) ciro, SUM(brut_kar) kar
             FROM bi_marj_atom WHERE tenant_id::text=$1 AND ay >= (CURRENT_DATE - ($2::int * INTERVAL '1 month'))
               AND ebat IS NOT NULL AND ebat<>'' GROUP BY marka, ebat),
           brandtgt AS (
             SELECT marka, GREATEST($3::numeric, LEAST(0.30, percentile_cont(0.6) WITHIN GROUP (ORDER BY m))) hedef
             FROM (SELECT marka, SUM(brut_kar)/NULLIF(SUM(ciro),0) m FROM bi_marj_atom
                   WHERE tenant_id::text=$1 AND ay >= (CURRENT_DATE - ($2::int * INTERVAL '1 month'))
                     AND ebat IS NOT NULL AND ebat<>'' GROUP BY marka, kalem_kodu
                   HAVING SUM(adet)>=20 AND SUM(ciro)>0) bs GROUP BY marka),
           kmap AS (
             SELECT DISTINCT marka, ebat, kalem_kodu FROM bi_satis_faturalari
             WHERE tenant_id::text=$1 AND ebat IS NOT NULL AND ebat<>'' AND grup_adi LIKE 'LASTIK%'),
           repl AS (
             SELECT k.marka, k.ebat, SUM(t.satir_kdv_haric)/NULLIF(SUM(t.miktar),0) repl_cost
             FROM kmap k JOIN bi_tedarikci_faturalari t ON t.tenant_id::text=$1 AND t.kalem_kodu=k.kalem_kodu
             WHERE t.fatura_tarihi >= (CURRENT_DATE - INTERVAL '90 days')
             GROUP BY k.marka, k.ebat)
           SELECT s.marka, s.ebat, s.adet::int adet,
             round(s.ciro)::float8 ciro,
             round(s.kar/NULLIF(s.ciro,0)*100, 1)::float8 marj_pct,
             round(s.ciro/NULLIF(s.adet,0))::float8 avg_satis,
             round((s.ciro-s.kar)/NULLIF(s.adet,0))::float8 avg_maliyet,
             round(r.repl_cost)::float8 repl_cost,
             COALESCE(bt.hedef,$3::numeric)::float8 hedef,
             round((COALESCE(bt.hedef,$3::numeric)*100)::numeric,1)::float8 hedef_pct,
             round(COALESCE(bt.hedef,$3::numeric)*s.ciro - s.kar)::float8 leak
           FROM sku s LEFT JOIN brandtgt bt ON bt.marka=s.marka LEFT JOIN repl r ON r.marka=s.marka AND r.ebat=s.ebat
           WHERE s.ciro>0 AND s.kar/NULLIF(s.ciro,0) < COALESCE(bt.hedef,$3::numeric) AND s.adet >= $4
           ORDER BY (COALESCE(bt.hedef,$3::numeric)*s.ciro - s.kar) DESC LIMIT 300`"""
assert s.count(OLD_Q) == 1, "marj-alarm sorgusu bulunamadi"
s = s.replace(OLD_Q, NEW_Q, 1)

# ---- (B) marj-alarm JS map ----
OLD_M = """        const skular = rows.map(r => {
          const taban = (Number(r.repl_cost) || Number(r.avg_maliyet) || 0);
          const floor = taban > 0 ? taban / (1 - hedef) : null;
          return {
            marka: r.marka, ebat: r.ebat, adet: Number(r.adet),
            ciro: Number(r.ciro), marj_pct: Number(r.marj_pct),
            avg_satis: Number(r.avg_satis), avg_maliyet: Number(r.avg_maliyet),
            repl_cost: r.repl_cost != null ? Number(r.repl_cost) : null,
            onerilen_taban: floor != null ? Math.round(floor / 250) * 250 : null,
            leak: Math.round(Number(r.leak) || 0),
            maliyet_alti: taban > 0 && Number(r.avg_satis) < taban
          };
        });
        sendJson(response, 200, { hedef, ay, toplam_sizinti: Math.round(toplam), sku_sayisi: skular.length, skular });"""
NEW_M = """        const skular = rows.map(r => {
          const taban = (Number(r.repl_cost) || Number(r.avg_maliyet) || 0);
          const rh = Number(r.hedef) || hedef;
          const floor = taban > 0 ? taban / (1 - rh) : null;
          return {
            marka: r.marka, ebat: r.ebat, adet: Number(r.adet),
            ciro: Number(r.ciro), marj_pct: Number(r.marj_pct),
            avg_satis: Number(r.avg_satis), avg_maliyet: Number(r.avg_maliyet),
            repl_cost: r.repl_cost != null ? Number(r.repl_cost) : null,
            hedef_pct: Number(r.hedef_pct),
            onerilen_taban: floor != null ? Math.round(floor / 250) * 250 : null,
            leak: Math.round(Number(r.leak) || 0),
            maliyet_alti: taban > 0 && Number(r.avg_satis) < taban
          };
        });
        sendJson(response, 200, { hedef, ay, marka_ozel: true /* MARKATIER_V1 */, toplam_sizinti: Math.round(toplam), sku_sayisi: skular.length, skular });"""
assert s.count(OLD_M) == 1, "marj-alarm JS map bulunamadi"
s = s.replace(OLD_M, NEW_M, 1)

# ---- (C1) desen SORGUSU (backtick govdesi) ----
OLD_D = """`WITH sku AS (
             SELECT kalem_kodu, SUM(adet) adet, SUM(ciro) ciro, SUM(brut_kar) kar
             FROM bi_marj_atom WHERE tenant_id::text=$1 AND marka=$2 AND ebat=$3
               AND ay >= (CURRENT_DATE - ($4::int * INTERVAL '1 month')) AND kalem_kodu IS NOT NULL
             GROUP BY kalem_kodu),
           ad AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, kalem_tanimi FROM bi_satis_faturalari
             WHERE tenant_id::text=$1 AND kalem_tanimi IS NOT NULL AND kalem_kodu IN (SELECT kalem_kodu FROM sku)
             ORDER BY kalem_kodu, fatura_tarihi DESC),
           repl AS (SELECT kalem_kodu, SUM(satir_kdv_haric)/NULLIF(SUM(miktar),0) repl_cost
             FROM bi_tedarikci_faturalari WHERE tenant_id::text=$1 AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '90 days')
               AND kalem_kodu IN (SELECT kalem_kodu FROM sku) GROUP BY kalem_kodu)
           SELECT s.kalem_kodu, ad.kalem_tanimi,
             s.adet::int adet, round(s.ciro)::float8 ciro, round(s.kar)::float8 kar,
             round(s.kar/NULLIF(s.ciro,0)*100,1)::float8 marj_pct,
             round(s.ciro/NULLIF(s.adet,0))::float8 avg_satis,
             round((s.ciro-s.kar)/NULLIF(s.adet,0))::float8 avg_maliyet,
             round(r.repl_cost)::float8 repl_cost
           FROM sku s LEFT JOIN ad ON ad.kalem_kodu=s.kalem_kodu LEFT JOIN repl r ON r.kalem_kodu=s.kalem_kodu
           WHERE s.ciro > 0 ORDER BY s.ciro DESC LIMIT 60`"""
NEW_D = """`WITH sku AS (
             SELECT kalem_kodu, SUM(adet) adet, SUM(ciro) ciro, SUM(brut_kar) kar
             FROM bi_marj_atom WHERE tenant_id::text=$1 AND marka=$2 AND ebat=$3
               AND ay >= (CURRENT_DATE - ($4::int * INTERVAL '1 month')) AND kalem_kodu IS NOT NULL
             GROUP BY kalem_kodu),
           bt AS (SELECT GREATEST($5::numeric, LEAST(0.30, percentile_cont(0.6) WITHIN GROUP (ORDER BY m))) hedef
             FROM (SELECT SUM(brut_kar)/NULLIF(SUM(ciro),0) m FROM bi_marj_atom
                   WHERE tenant_id::text=$1 AND marka=$2 AND ebat IS NOT NULL AND ebat<>''
                     AND ay >= (CURRENT_DATE - ($4::int * INTERVAL '1 month')) GROUP BY kalem_kodu
                   HAVING SUM(adet)>=20 AND SUM(ciro)>0) x),
           ad AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, kalem_tanimi FROM bi_satis_faturalari
             WHERE tenant_id::text=$1 AND kalem_tanimi IS NOT NULL AND kalem_kodu IN (SELECT kalem_kodu FROM sku)
             ORDER BY kalem_kodu, fatura_tarihi DESC),
           repl AS (SELECT kalem_kodu, SUM(satir_kdv_haric)/NULLIF(SUM(miktar),0) repl_cost
             FROM bi_tedarikci_faturalari WHERE tenant_id::text=$1 AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '90 days')
               AND kalem_kodu IN (SELECT kalem_kodu FROM sku) GROUP BY kalem_kodu)
           SELECT s.kalem_kodu, ad.kalem_tanimi,
             s.adet::int adet, round(s.ciro)::float8 ciro, round(s.kar)::float8 kar,
             round(s.kar/NULLIF(s.ciro,0)*100,1)::float8 marj_pct,
             round(s.ciro/NULLIF(s.adet,0))::float8 avg_satis,
             round((s.ciro-s.kar)/NULLIF(s.adet,0))::float8 avg_maliyet,
             round(r.repl_cost)::float8 repl_cost,
             COALESCE(bt.hedef,$5::numeric)::float8 brand_hedef
           FROM sku s CROSS JOIN bt LEFT JOIN ad ON ad.kalem_kodu=s.kalem_kodu LEFT JOIN repl r ON r.kalem_kodu=s.kalem_kodu
           WHERE s.ciro > 0 ORDER BY s.ciro DESC LIMIT 60`"""
assert s.count(OLD_D) == 1, "desen sorgusu bulunamadi"
s = s.replace(OLD_D, NEW_D, 1)

# ---- (C2) desen param array: $5 = hedef ekle ----
OLD_DC = "          [T, marka, ebat, ay])).rows;"
NEW_DC = "          [T, marka, ebat, ay, hedef])).rows;"
assert s.count(OLD_DC) == 1, "desen param array bulunamadi"
s = s.replace(OLD_DC, NEW_DC, 1)

# ---- (C3) desen JS map: hedef -> brand_hedef ----
OLD_DM = """        const desenler = rows.map(r => {
          const taban = (Number(r.repl_cost) || Number(r.avg_maliyet) || 0);
          const floor = taban > 0 ? taban / (1 - hedef) : null;
          return {
            kalem_kodu: r.kalem_kodu, desen: r.kalem_tanimi || r.kalem_kodu,
            adet: Number(r.adet), ciro: Number(r.ciro), marj_pct: Number(r.marj_pct),
            avg_satis: Number(r.avg_satis), avg_maliyet: Number(r.avg_maliyet),
            repl_cost: r.repl_cost != null ? Number(r.repl_cost) : null,
            onerilen_taban: floor != null ? Math.round(floor / 250) * 250 : null,
            leak: Math.round(hedef * Number(r.ciro) - Number(r.kar)),
            maliyet_alti: taban > 0 && Number(r.avg_satis) < taban
          };
        });
        sendJson(response, 200, { marka, ebat, hedef, ay, desenler });"""
NEW_DM = """        const bh = rows.length && rows[0].brand_hedef != null ? Number(rows[0].brand_hedef) : hedef;
        const desenler = rows.map(r => {
          const taban = (Number(r.repl_cost) || Number(r.avg_maliyet) || 0);
          const floor = taban > 0 ? taban / (1 - bh) : null;
          return {
            kalem_kodu: r.kalem_kodu, desen: r.kalem_tanimi || r.kalem_kodu,
            adet: Number(r.adet), ciro: Number(r.ciro), marj_pct: Number(r.marj_pct),
            avg_satis: Number(r.avg_satis), avg_maliyet: Number(r.avg_maliyet),
            repl_cost: r.repl_cost != null ? Number(r.repl_cost) : null,
            onerilen_taban: floor != null ? Math.round(floor / 250) * 250 : null,
            leak: Math.round(bh * Number(r.ciro) - Number(r.kar)),
            maliyet_alti: taban > 0 && Number(r.avg_satis) < taban
          };
        });
        sendJson(response, 200, { marka, ebat, hedef: bh, hedef_pct: Math.round(bh * 1000) / 10, ay, desenler });"""
assert s.count(OLD_DM) == 1, "desen JS map bulunamadi"
s = s.replace(OLD_DM, NEW_DM, 1)

write(FP, s)
print("markatier: marj-alarm + desen markaya-ozel hedefe gecti")
print("hedef_pct count:", s.count("hedef_pct"))
print("DONE.")
