#!/usr/bin/env python3
# SMARTPRICE_V2 — toplu ic: GET /api/bi/musteri-fiyat-liste?musteri=&kalemler=k1,k2,...
# Musteri skorunu BIR KEZ hesaplar, verilen kalemlerin her biri icin onerilen fiyat + durum doner.
# Musteri kartinda "son alimlar" satirlarinin yanina onerilen fiyat basmak icin. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "SMARTPRICE_V2" in s:
    print("smartprice2: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTPRICE_V1" in s, "once SMARTPRICE_V1 uygulanmali"

ANCHOR = (
    '  if (request.method === "GET" && url.pathname === "/api/bi/kokpit") {\n'
    '    try {\n'
    '      const _h = await readFile("/app/shells/kokpit.html", "utf8");'
)
assert s.count(ANCHOR) == 1, "kokpit anchor"

SCOREQ = r'''`WITH cust AS (
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
           FROM scored WHERE musteri_kodu=$2`'''

SKUQ = r'''`SELECT
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
             (SELECT max(ebat) FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2) ebat`'''

GERCEKQ = r'''`SELECT SUM(miktar*birim_fiyat)/NULLIF(SUM(miktar),0) fiyat,
                  SUM(miktar*(vade_tarihi-fatura_tarihi)::numeric)/NULLIF(SUM(miktar),0) vade
           FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND musteri_kodu=$2 AND kalem_kodu=$3
             AND miktar>0 AND fatura_tarihi>=(CURRENT_DATE-INTERVAL '18 months')
             AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))`'''

BLK2 = '''    // SMARTPRICE_V2 — sadece musteri skoru (kart ustu skor karti)
    if (request.method === "GET" && url.pathname === "/api/bi/musteri-skor") {
      let _s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let _ss = _s ? null : await requireSahaAccess(request).catch(() => null);
      const _sess = _s || _ss;
      if (!_sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = _sess.tenantId;
      const musteri = (url.searchParams.get("musteri") || "").trim();
      if (!musteri) { sendJson(response, 400, { error: "musteri zorunlu" }); return; }
      const out = { skor: null, bilesenler: null, vade_oneri: null };
      try {
        const sc = (await query(''' + SCOREQ + ''', [T, musteri])).rows[0];
        if (sc) {
          out.skor = Number(sc.skor);
          out.bilesenler = { odeme: Number(sc.odeme), hacim: Number(sc.hacim), sadakat: Number(sc.sadakat), risk: Number(sc.risk) };
          const _comb = (Number(sc.odeme) + Number(sc.risk)) / 2;
          out.vade_oneri = _comb < 40 ? "Peşin / azami 30 gün — riskli profil" : (_comb < 65 ? "azami 60 gün" : "90 güne kadar esnek — iyi ödeyici");
        }
      } catch (e) { console.error("[musteri-skor]", e && e.message); }
      sendJson(response, 200, out);
      return;
    }

    // SMARTPRICE_V2 — toplu musteri-fiyat (son alimlar satir-ici oneri)
    if (request.method === "GET" && url.pathname === "/api/bi/musteri-fiyat-liste") {
      let _s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let _ss = _s ? null : await requireSahaAccess(request).catch(() => null);
      const _sess = _s || _ss;
      if (!_sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = _sess.tenantId;
      const musteri = (url.searchParams.get("musteri") || "").trim();
      const kalemlerRaw = (url.searchParams.get("kalemler") || "").trim();
      const kalems = kalemlerRaw ? Array.from(new Set(kalemlerRaw.split(",").map(x => x.trim()).filter(Boolean))).slice(0, 20) : [];
      if (!musteri || !kalems.length) { sendJson(response, 400, { error: "musteri+kalemler zorunlu" }); return; }
      const out = { skor: null, bilesenler: null, kalemler: {} };
      let _vol = null, _risk = null;
      try {
        const sc = (await query(''' + SCOREQ + ''', [T, musteri])).rows[0];
        if (sc) {
          out.skor = Number(sc.skor);
          out.bilesenler = { odeme: Number(sc.odeme), hacim: Number(sc.hacim), sadakat: Number(sc.sadakat), risk: Number(sc.risk) };
          _vol = Number(sc.vol_raw); _risk = Number(sc.risk_raw);
          const _comb = (Number(sc.odeme) + Number(sc.risk)) / 2;
          out.vade_oneri = _comb < 40 ? "Peşin / azami 30 gün — riskli profil" : (_comb < 65 ? "azami 60 gün" : "90 güne kadar esnek — iyi ödeyici");
        }
      } catch (e) { console.error("[mfl skor]", e && e.message); }
      const perKalem = async (kalem) => {
        const r = { oneri: null, durum: null, gercek: null, marj_oneri: null, ad: null, marka: null, ebat: null, lo: null, med: null, hi: null, maliyet: null, repl_cost: null, vade_menu: null };
        try {
          const p = (await query(''' + SKUQ + ''', [T, kalem])).rows[0];
          if (p) {
            const lo = p.lo != null ? Math.round(Number(p.lo)) : null, hi = p.hi != null ? Math.round(Number(p.hi)) : null;
            const cost = p.cost != null ? Math.round(Number(p.cost)) : null, repl = p.repl_cost != null ? Math.round(Number(p.repl_cost)) : null;
            const mx = p.mx != null ? Math.round(Number(p.mx)) : null;
            r.ad = p.ad || null; r.marka = p.marka || null; r.ebat = p.ebat || null;
            r.med = p.med != null ? Math.round(Number(p.med)) : null;
            r.lo = lo; r.hi = hi; r.maliyet = cost; r.repl_cost = repl;
            let gercek = null, gvade = null;
            const g = (await query(''' + GERCEKQ + ''', [T, musteri, kalem])).rows[0];
            if (g && g.fiyat != null) { gercek = Math.round(Number(g.fiyat)); gvade = g.vade != null ? Math.round(Number(g.vade)) : null; }
            r.gercek = gercek;
            if (lo != null && hi != null) {
              const vol = _vol != null ? _vol : 0.5, risk = _risk != null ? _risk : 0.5;
              const floorCost = (repl != null ? repl : cost) || 0;
              const fairAt = (vd) => {
                let pl = 0.45 * (1 - vol) + 0.35 * Math.min(Math.max(vd, 0), 120) / 120 + 0.20 * (1 - risk);
                pl = Math.max(0, Math.min(1, pl));
                let f = lo + pl * (hi - lo);
                if (floorCost > 0) f = Math.max(f, floorCost / 0.88);
                if (mx != null) f = Math.min(f, Math.max(mx, floorCost / 0.88));
                return Math.round(f / 250) * 250;
              };
              const fair = fairAt(gvade != null ? gvade : 45);
              r.oneri = fair;
              r.vade_menu = [0, 30, 60, 90].map(v => ({ vade: v, fiyat: fairAt(v) }));
              if (gercek == null) r.durum = "YENI";
              else if (fair > gercek * 1.03) r.durum = "LIFT";
              else if (gercek > fair * 1.12) r.durum = "WATCH";
              else r.durum = "UYGUN";
              r.marj_oneri = (floorCost > 0 && fair > 0) ? Math.round((fair - floorCost) / fair * 1000) / 10 : null;
            }
          }
        } catch (e) { console.error("[mfl kalem]", e && e.message); }
        return [kalem, r];
      };
      try {
        const res = await Promise.all(kalems.map(perKalem));
        res.forEach(([k, r]) => { out.kalemler[k] = r; });
      } catch (e) { console.error("[mfl]", e && e.message); }
      sendJson(response, 200, out);
      return;
    }

'''

s = s.replace(ANCHOR, BLK2 + ANCHOR, 1)
write(FP, s)
print("smartprice2: /api/bi/musteri-fiyat-liste eklendi")
print("marker count:", s.count("SMARTPRICE_V2"))
print("DONE.")
