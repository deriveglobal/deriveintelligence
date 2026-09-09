#!/usr/bin/env python3
# SMARTPRICE_V1 — Akilli Fiyatlandirma motoru (server_container.mjs).
# Iki uc ekler, /api/bi/kokpit HTML ucundan ONCE:
#   GET /api/bi/marj-alarm            -> Seviye 1: SKU marj sizintisi (yenileme-maliyeti tabani)
#   GET /api/bi/musteri-fiyat?musteri=&kalem= -> Seviye 2: kisiye ozel onerilen fiyat + Musteri Skoru
# Yetki: intelligence VEYA saha manager/admin (ebat-kart deseni). Tenant her tabloda tenant_id::text=$1.
# Idempotent. node --check ile dogrulanir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "SMARTPRICE_V1" in s:
    print("smartprice: already present, skip"); print("DONE."); raise SystemExit

ANCHOR = (
    '  if (request.method === "GET" && url.pathname === "/api/bi/kokpit") {\n'
    '    try {\n'
    '      const _h = await readFile("/app/shells/kokpit.html", "utf8");'
)
assert s.count(ANCHOR) == 1, "kokpit anchor bulunamadi (count!=1)"

BLK = r'''    // ===== SMARTPRICE_V1 — Akilli Fiyatlandirma motoru =====
    if (request.method === "GET" && url.pathname === "/api/bi/marj-alarm") {
      let _s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let _ss = _s ? null : await requireSahaAccess(request).catch(() => null);
      const _sess = _s || _ss;
      if (!_sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = _sess.tenantId;
      const hedef = Math.min(0.5, Math.max(0, parseFloat(url.searchParams.get("hedef") || "0.12")));
      const ay = Math.min(24, Math.max(1, parseInt(url.searchParams.get("ay") || "12", 10)));
      const minAdet = Math.max(1, parseInt(url.searchParams.get("min_adet") || "50", 10));
      try {
        const rows = (await query(
          `WITH sku AS (
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
           ORDER BY ($3::numeric*s.ciro - s.kar) DESC LIMIT 300`,
          [T, ay, hedef, minAdet])).rows;
        const toplam = rows.reduce((a, r) => a + (Number(r.leak) || 0), 0);
        const skular = rows.map(r => {
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
        sendJson(response, 200, { hedef, ay, toplam_sizinti: Math.round(toplam), sku_sayisi: skular.length, skular });
      } catch (e) { console.error("[marj-alarm]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/bi/musteri-fiyat") {
      let _s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let _ss = _s ? null : await requireSahaAccess(request).catch(() => null);
      const _sess = _s || _ss;
      if (!_sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = _sess.tenantId;
      const musteri = (url.searchParams.get("musteri") || "").trim();
      const kalem = (url.searchParams.get("kalem") || "").trim();
      if (!musteri || !kalem) { sendJson(response, 400, { error: "musteri+kalem zorunlu" }); return; }
      const out = { skor: null, bilesenler: null, sku: null, musteri_gercek: null, oneri: null, durum: null, marj_oneri: null };
      let _vol = null, _risk = null;
      try {
        const sc = (await query(
          `WITH cust AS (
             SELECT musteri_kodu,
               SUM(satir_tutar) ciro, SUM(miktar) adet,
               SUM(miktar*(vade_tarihi-fatura_tarihi)::numeric)/NULLIF(SUM(miktar),0) vade,
               COUNT(DISTINCT date_trunc('month',fatura_tarihi)) ay_sayisi,
               COUNT(DISTINCT ebat) ebat_n
             FROM bi_satis_faturalari
             WHERE tenant_id::text=$1 AND grup_adi LIKE 'LASTIK%' AND miktar>0
               AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months')
             GROUP BY musteri_kodu),
           risk AS (
             SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, vadesi_gecmis, kredi_limiti
             FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi
             ORDER BY muhatap_kodu, export_date DESC),
           net AS (SELECT musteri_kodu, net_pozisyon FROM bi_cari_bakiye WHERE tenant_id::text=$1),
           base AS (
             SELECT c.*, COALESCE(r.vadesi_gecmis,0) overdue, COALESCE(r.hesap_bakiyesi,0) bakiye,
               COALESCE(r.kredi_limiti,0) kredi, COALESCE(n.net_pozisyon, r.hesap_bakiyesi, 0) net_poz
             FROM cust c LEFT JOIN risk r ON r.muhatap_kodu=c.musteri_kodu LEFT JOIN net n ON n.musteri_kodu=c.musteri_kodu),
           scored AS (
             SELECT b.*, percent_rank() OVER (ORDER BY ciro) s_vol,
               (0.6*(1-LEAST(COALESCE(vade,0),120)/120.0)
                +0.4*(CASE WHEN overdue<=0 THEN 1.0 WHEN bakiye<=0 THEN 0.3 ELSE GREATEST(0,1-overdue/bakiye) END)) s_pay,
               (0.6*LEAST(ay_sayisi,12)/12.0 + 0.4*LEAST(ebat_n,10)/10.0) s_loyal,
               (CASE WHEN kredi>0 THEN GREATEST(0,1-GREATEST(net_poz,0)/kredi) WHEN net_poz<=0 THEN 1.0 ELSE 0.5 END) s_risk
             FROM base b)
           SELECT round(100*(0.35*s_pay+0.25*s_vol+0.20*s_loyal+0.20*s_risk))::int skor,
             round(s_pay*100)::int odeme, round(s_vol*100)::int hacim,
             round(s_loyal*100)::int sadakat, round(s_risk*100)::int risk,
             s_vol::float8 vol_raw, s_risk::float8 risk_raw
           FROM scored WHERE musteri_kodu=$2`,
          [T, musteri])).rows[0];
        if (sc) {
          out.skor = Number(sc.skor);
          out.bilesenler = { odeme: Number(sc.odeme), hacim: Number(sc.hacim), sadakat: Number(sc.sadakat), risk: Number(sc.risk) };
          _vol = Number(sc.vol_raw); _risk = Number(sc.risk_raw);
        }
      } catch (e) { console.error("[musteri-fiyat skor]", e && e.message); }
      try {
        const p = (await query(
          `SELECT
             (SELECT (SUM(ciro)-SUM(brut_kar))/NULLIF(SUM(adet),0) FROM bi_marj_atom
                WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND ay>=(CURRENT_DATE-INTERVAL '12 months')) cost,
             (SELECT SUM(satir_kdv_haric)/NULLIF(SUM(miktar),0) FROM bi_tedarikci_faturalari
                WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND fatura_tarihi>=(CURRENT_DATE-INTERVAL '90 days')) repl_cost,
             (SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY birim_fiyat) FROM bi_satis_faturalari
                WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND grup_adi LIKE 'LASTIK%' AND miktar>0
                  AND fatura_tarihi>=(CURRENT_DATE-INTERVAL '12 months') AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))) lo,
             (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat) FROM bi_satis_faturalari
                WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND grup_adi LIKE 'LASTIK%' AND miktar>0
                  AND fatura_tarihi>=(CURRENT_DATE-INTERVAL '12 months') AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))) med,
             (SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY birim_fiyat) FROM bi_satis_faturalari
                WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND grup_adi LIKE 'LASTIK%' AND miktar>0
                  AND fatura_tarihi>=(CURRENT_DATE-INTERVAL '12 months') AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))) hi,
             (SELECT MAX(birim_fiyat) FROM bi_satis_faturalari
                WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND grup_adi LIKE 'LASTIK%' AND miktar>0
                  AND fatura_tarihi>=(CURRENT_DATE-INTERVAL '12 months') AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))) mx,
             (SELECT kalem_tanimi FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND kalem_tanimi IS NOT NULL ORDER BY fatura_tarihi DESC LIMIT 1) ad,
             (SELECT max(marka) FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2) marka,
             (SELECT max(ebat) FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2) ebat`,
          [T, kalem])).rows[0];
        if (p) out.sku = {
          ad: p.ad || null, marka: p.marka || null, ebat: p.ebat || null,
          maliyet: p.cost != null ? Math.round(Number(p.cost)) : null,
          repl_cost: p.repl_cost != null ? Math.round(Number(p.repl_cost)) : null,
          lo: p.lo != null ? Math.round(Number(p.lo)) : null,
          med: p.med != null ? Math.round(Number(p.med)) : null,
          hi: p.hi != null ? Math.round(Number(p.hi)) : null,
          mx: p.mx != null ? Math.round(Number(p.mx)) : null
        };
      } catch (e) { console.error("[musteri-fiyat sku]", e && e.message); }
      try {
        const g = (await query(
          `SELECT SUM(miktar*birim_fiyat)/NULLIF(SUM(miktar),0) fiyat,
                  SUM(miktar*(vade_tarihi-fatura_tarihi)::numeric)/NULLIF(SUM(miktar),0) vade,
                  SUM(miktar)::int adet, to_char(MAX(fatura_tarihi),'YYYY-MM-DD') son
           FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND musteri_kodu=$2 AND kalem_kodu=$3
             AND miktar>0 AND fatura_tarihi>=(CURRENT_DATE-INTERVAL '18 months')
             AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))`,
          [T, musteri, kalem])).rows[0];
        if (g && g.fiyat != null) out.musteri_gercek = { fiyat: Math.round(Number(g.fiyat)), vade: g.vade != null ? Math.round(Number(g.vade)) : null, adet: Number(g.adet), son: g.son };
      } catch (e) { console.error("[musteri-fiyat gercek]", e && e.message); }
      try {
        const sku = out.sku;
        if (sku && sku.lo != null && sku.hi != null) {
          const vol = _vol != null ? _vol : 0.5;
          const risk = _risk != null ? _risk : 0.5;
          const vade = (out.musteri_gercek && out.musteri_gercek.vade != null) ? out.musteri_gercek.vade : 45;
          let placement = 0.45 * (1 - vol) + 0.35 * Math.min(Math.max(vade, 0), 120) / 120 + 0.20 * (1 - risk);
          placement = Math.max(0, Math.min(1, placement));
          const floorCost = (sku.repl_cost != null ? sku.repl_cost : sku.maliyet) || 0;
          let fair = sku.lo + placement * (sku.hi - sku.lo);
          if (floorCost > 0) fair = Math.max(fair, floorCost / 0.88);
          if (sku.mx != null) fair = Math.min(fair, Math.max(sku.mx, floorCost / 0.88));
          fair = Math.round(fair / 250) * 250;
          out.oneri = fair;
          const gercek = out.musteri_gercek ? out.musteri_gercek.fiyat : null;
          if (gercek == null) out.durum = "YENI";
          else if (fair > gercek * 1.03) out.durum = "LIFT";
          else if (gercek > fair * 1.12) out.durum = "WATCH";
          else out.durum = "UYGUN";
          out.marj_oneri = (floorCost > 0 && fair > 0) ? Math.round((fair - floorCost) / fair * 1000) / 10 : null;
        }
      } catch (e) { console.error("[musteri-fiyat hesap]", e && e.message); }
      sendJson(response, 200, out);
      return;
    }

'''

s = s.replace(ANCHOR, BLK + ANCHOR, 1)
write(FP, s)
print("smartprice: /api/bi/marj-alarm + /api/bi/musteri-fiyat eklendi")
print("marker count:", s.count("SMARTPRICE_V1"))
print("DONE.")
