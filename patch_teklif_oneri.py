# -*- coding: utf-8 -*-
# TEKLIF_ONERI_V1 — Teklif formu karar yardimcisi (sunucu ucu).
#   GET /api/bi/teklif-oneri?musteri_id=<saha_musteri.id>&kalem=<kalem_kodu>
#   Yetki: requireSahaAccess ["rep","manager","admin"] (rep DAHIL — teklifi rep yazar).
#   Matematik: musteri-fiyat-liste perKalem ile AYNI (paylasilan helper). Boylece repin
#   gordugu oneri == musteri karti == CEO onay rakami. Rol'e gore payload:
#     rep     -> oneri, vade_menu, piyasa(lo/med/hi), rakip, durum, hedef_taban  (MALIYET/MARJ YOK)
#     yonetici-> + maliyet, repl_cost, marj_oneri, taban_kritik(floorCost), brand_hedef, skor
#   Mevcut musteri-fiyat-liste endpoint'i DEGISTIRILMEZ; yalniz yeni kod eklenir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "TEKLIF_ONERI_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# ── 1) Paylasilan helper'lar (musteri-skor + perKalem matematigi, birebir) ──
HELPERS = r'''
  // ── Paylasilan akilli-fiyat helper'lari (musteri-fiyat-liste ile AYNI matematik) — TEKLIF_ONERI_V1 ──
  //     NOT: musteri-fiyat-liste icindeki mantik ile SENKRON tutulmali (kopya). Ileride o
  //     endpoint de bunlari cagiracak sekilde sadelestirilebilir.
  async function _smartSkorRaw(T, musteri) {  /* TEKLIF_ONERI_V1 */
    const out = { skor: null, bilesenler: null, vade_oneri: null, vol: null, risk: null };
    try {
      const sc = (await query(`WITH cust AS (
             SELECT musteri_kodu,
               SUM(satir_tutar) ciro, SUM(miktar) adet,
               SUM(miktar*(vade_tarihi-fatura_tarihi)::numeric)/NULLIF(SUM(miktar),0) vade,
               COUNT(DISTINCT date_trunc('month',fatura_tarihi)) ay_sayisi,
               COUNT(DISTINCT ebat) ebat_n
             FROM bi_satis_faturalari
             WHERE tenant_id::text=$1 AND grup_adi LIKE 'LASTIK%' AND miktar>0
               AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months')
               AND musteri_kodu NOT IN (SELECT f2.musteri_kodu FROM bi_satis_faturalari f2 WHERE f2.tenant_id::text=$1 AND f2.grup_adi LIKE 'LASTIK%' AND f2.fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months') AND f2.musteri_kodu IN (SELECT muhatap_kodu FROM bi_musteri_risk WHERE tenant_id::text=$1 AND grup ILIKE '%TEDAR%') GROUP BY f2.musteri_kodu HAVING SUM(f2.satir_tutar) > 5000000) /* TEDARFILT_V1 */
             GROUP BY musteri_kodu),
           risk AS (
             SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, vadesi_gecmis, kredi_limiti
             FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi
             ORDER BY muhatap_kodu, export_date DESC),
           net AS (SELECT musteri_kodu, net_pozisyon FROM bi_cari_bakiye WHERE tenant_id::text=$1),
           tah AS (SELECT muhatap_kodu, gec_odeme_orani, ort_gecikme_gun, son12_adedi, son12_gec_orani, son12_gecikme_gun FROM bi_tahsilat WHERE tenant_id::text=$1),
           base AS (
             SELECT c.*, COALESCE(r.vadesi_gecmis,0) overdue, COALESCE(r.hesap_bakiyesi,0) bakiye,
               COALESCE(r.kredi_limiti,0) kredi, COALESCE(n.net_pozisyon, r.hesap_bakiyesi, 0) net_poz,
               (t.muhatap_kodu IS NOT NULL) has_tah,
               CASE WHEN COALESCE(t.son12_adedi,0)>0 THEN t.son12_gec_orani ELSE t.gec_odeme_orani END eff_gec,
               CASE WHEN COALESCE(t.son12_adedi,0)>0 THEN t.son12_gecikme_gun ELSE t.ort_gecikme_gun END eff_gun
             FROM cust c LEFT JOIN risk r ON r.muhatap_kodu=c.musteri_kodu LEFT JOIN net n ON n.musteri_kodu=c.musteri_kodu LEFT JOIN tah t ON t.muhatap_kodu=c.musteri_kodu),
           scored AS (
             SELECT b.*, percent_rank() OVER (ORDER BY ciro) s_vol,
               (CASE WHEN has_tah THEN 0.6*(1-LEAST(GREATEST(COALESCE(eff_gec,0),0),100)/100.0)+0.4*(1-LEAST(GREATEST(COALESCE(eff_gun,0),0),60)/60.0) ELSE 0.6*(1-LEAST(COALESCE(vade,0),120)/120.0)+0.4*(CASE WHEN overdue<=0 THEN 1.0 WHEN bakiye<=0 THEN 0.3 ELSE GREATEST(0,1-overdue/bakiye) END) END) s_pay,
               (0.6*LEAST(ay_sayisi,12)/12.0 + 0.4*LEAST(ebat_n,10)/10.0) s_loyal,
               (CASE WHEN kredi>0 THEN GREATEST(0,1-GREATEST(net_poz,0)/kredi) WHEN net_poz<=0 THEN 1.0 ELSE 0.5 END) s_risk
             FROM base b)
           SELECT round(100*(0.35*s_pay+0.25*s_vol+0.20*s_loyal+0.20*s_risk))::int skor,
             round(s_pay*100)::int odeme, round(s_vol*100)::int hacim,
             round(s_loyal*100)::int sadakat, round(s_risk*100)::int risk,
             s_vol::float8 vol_raw, s_risk::float8 risk_raw
           FROM scored WHERE musteri_kodu=$2`, [T, musteri])).rows[0];
      if (sc) {
        out.skor = Number(sc.skor);
        out.bilesenler = { odeme: Number(sc.odeme), hacim: Number(sc.hacim), sadakat: Number(sc.sadakat), risk: Number(sc.risk) };
        out.vol = Number(sc.vol_raw); out.risk = Number(sc.risk_raw);
        const _comb = (Number(sc.odeme) + Number(sc.risk)) / 2;
        out.vade_oneri = _comb < 40 ? "Peşin / azami 30 gün — riskli profil" : (_comb < 65 ? "azami 60 gün" : "90 güne kadar esnek — iyi ödeyici");
      }
    } catch (e) { console.error("[teklif-oneri skor]", e && e.message); }
    return out;
  }

  async function _smartKalemFiyat(T, musteri, kalem, _vol, _risk) {  /* TEKLIF_ONERI_V1 */
    const r = { oneri: null, durum: null, gercek: null, marj_oneri: null, ad: null, marka: null, ebat: null, lo: null, med: null, hi: null, mx: null, maliyet: null, repl_cost: null, vade_menu: null, rakip: null, brand_hedef: null, floorCost: 0, hedef_taban: null };
    try {
      const p = (await query(`SELECT
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
             (SELECT max(ebat) FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2) ebat,
             (SELECT GREATEST(0.12, LEAST(0.30, percentile_cont(0.6) WITHIN GROUP (ORDER BY m))) FROM (SELECT SUM(brut_kar)/NULLIF(SUM(ciro),0) m FROM bi_marj_atom WHERE tenant_id::text=$1 AND marka=(SELECT max(marka) FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2) AND ebat IS NOT NULL AND ebat<>'' AND ay>=(CURRENT_DATE-INTERVAL '12 months') GROUP BY kalem_kodu HAVING SUM(adet)>=20 AND SUM(ciro)>0) x) brand_hedef /* MARKATIER_PRICE_V1 */`, [T, kalem])).rows[0];
      if (p) {
        const lo = p.lo != null ? Math.round(Number(p.lo)) : null, hi = p.hi != null ? Math.round(Number(p.hi)) : null;
        const cost = p.cost != null ? Math.round(Number(p.cost)) : null, repl = p.repl_cost != null ? Math.round(Number(p.repl_cost)) : null;
        const mx = p.mx != null ? Math.round(Number(p.mx)) : null;
        r.ad = p.ad || null; r.marka = p.marka || null; r.ebat = p.ebat || null;
        r.med = p.med != null ? Math.round(Number(p.med)) : null;
        r.lo = lo; r.hi = hi; r.mx = mx; r.maliyet = cost; r.repl_cost = repl;
        let gercek = null, gvade = null;
        const g = (await query(`SELECT SUM(miktar*birim_fiyat)/NULLIF(SUM(miktar),0) fiyat,
                  SUM(miktar*(vade_tarihi-fatura_tarihi)::numeric)/NULLIF(SUM(miktar),0) vade
           FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND musteri_kodu=$2 AND kalem_kodu=$3
             AND miktar>0 AND fatura_tarihi>=(CURRENT_DATE-INTERVAL '18 months')
             AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))`, [T, musteri, kalem])).rows[0];
        if (g && g.fiyat != null) { gercek = Math.round(Number(g.fiyat)); gvade = g.vade != null ? Math.round(Number(g.vade)) : null; }
        r.gercek = gercek;
        if (lo != null && hi != null) {
          const vol = _vol != null ? _vol : 0.5, risk = _risk != null ? _risk : 0.5;
          const floorCost = (repl != null ? repl : cost) || 0;
          const RATE = 0.42;
          const plBase = Math.max(0, Math.min(1, 0.62 * (1 - vol) + 0.38 * (1 - risk)));
          const bandBase = lo + plBase * (hi - lo);
          const brandH = (p.brand_hedef != null) ? Math.max(0.12, Math.min(0.30, Number(p.brand_hedef))) : 0.12; /* MARKATIER_PRICE_V1 */
          const pesin = Math.max(bandBase, floorCost > 0 ? floorCost / (1 - brandH) : bandBase);
          const fairAt = (vd) => {
            const fin = (floorCost > 0 ? floorCost : lo) * (RATE / 365) * Math.min(Math.max(vd, 0), 120);
            let f = pesin + fin;
            if (mx != null) f = Math.min(f, Math.max(mx, pesin));
            return Math.round(f / 250) * 250;
          };
          const fair = fairAt(gvade != null ? gvade : 45);
          r.oneri = fair;
          r.vade_menu = [0, 30, 60, 90].map(v => ({ vade: v, fiyat: fairAt(v) }));
          r.floorCost = floorCost;
          r.brand_hedef = Math.round(brandH * 1000) / 10;
          r.hedef_taban = Math.round(pesin);
          if (gercek == null) r.durum = "YENI";
          else if (fair > gercek * 1.03) r.durum = "LIFT";
          else if (gercek > fair * 1.12) r.durum = "WATCH";
          else r.durum = "UYGUN";
          r.marj_oneri = (floorCost > 0 && fair > 0) ? Math.round((fair - floorCost) / fair * 1000) / 10 : null;
          try { /* RAKIPWATCH_V1 */
            if (r.ebat && musteri) {
              const cmp = (await query(`SELECT st.rakip_marka, st.rakip_fiyat, st.kayip_nedeni, to_char(st.created_at,'YYYY-MM-DD') tarih FROM saha_teklif st JOIN saha_musteri sm ON sm.id=st.musteri_id WHERE st.tenant_id=$1::uuid AND sm.musteri_kodu=$2 AND st.rakip_fiyat IS NOT NULL AND st.ebat=$3 AND st.created_at >= now() - INTERVAL '9 months' ORDER BY st.created_at DESC LIMIT 1`, [T, musteri, r.ebat])).rows[0];
              if (cmp && cmp.rakip_fiyat != null) {
                const rf = Math.round(Number(cmp.rakip_fiyat));
                r.rakip = { marka: cmp.rakip_marka || null, fiyat: rf, neden: cmp.kayip_nedeni || null, tarih: cmp.tarih || null };
                const minFloor = floorCost > 0 ? floorCost / 0.88 : 0;
                if (rf < fair) {
                  r.oneri = Math.round(Math.max(rf, minFloor) / 250) * 250;
                  r.durum = (rf >= minFloor) ? 'RAKIP' : 'RAKIP_MALIYET';
                  r.marj_oneri = (floorCost > 0 && r.oneri > 0) ? Math.round((r.oneri - floorCost) / r.oneri * 1000) / 10 : null;
                }
              }
            }
          } catch (e) { console.error('[teklif-oneri rakipwatch]', e && e.message); }
        }
      }
    } catch (e) { console.error("[teklif-oneri kalem]", e && e.message); }
    return r;
  }

'''
ANCHOR1 = 'async function requireSahaAccess(req, allowedRoles = null) {'
assert s.count(ANCHOR1) == 1, "requireSahaAccess anchor count=%d" % s.count(ANCHOR1)
s = s.replace(ANCHOR1, HELPERS + "\n  " + ANCHOR1, 1)

# ── 2) Yeni endpoint (musteri-fiyat-liste blogundan hemen sonra, SMARTKIYAS'tan once) ──
ENDPOINT = r'''    // ── Teklif formu karar yardimcisi: kalem basi akilli fiyat + saglik esikleri — TEKLIF_ONERI_V1 ──
    if (request.method === "GET" && url.pathname === "/api/bi/teklif-oneri") {
      const session = await requireSahaAccess(request, ["rep", "manager", "admin"]);
      const T = session.tenantId;
      const kalem = (url.searchParams.get("kalem") || "").trim();
      const musteriId = (url.searchParams.get("musteri_id") || "").trim();
      if (!kalem) { sendJson(response, 400, { error: "kalem zorunlu" }); return; }
      let musteriKodu = null;
      if (musteriId) {
        try {
          const mr = await query("SELECT musteri_kodu FROM saha_musteri WHERE id=$1 AND tenant_id=$2::uuid", [musteriId, T]);
          musteriKodu = mr.rows[0] ? (mr.rows[0].musteri_kodu || null) : null;
        } catch (e) {}
      }
      const isRep = session.sahaRole === "rep";
      let skor = null, bilesenler = null, vade_oneri = null, vol = null, risk = null;
      if (musteriKodu) {
        const sc = await _smartSkorRaw(T, musteriKodu);
        if (sc) { skor = sc.skor; bilesenler = sc.bilesenler; vade_oneri = sc.vade_oneri; vol = sc.vol; risk = sc.risk; }
      }
      const r = await _smartKalemFiyat(T, musteriKodu, kalem, vol, risk);
      if (!r || r.oneri == null) {
        sendJson(response, 200, { veri: false, mesaj: "Bu ebatta yeterli veri yok — öneri veremiyorum.", ad: r ? r.ad : null, marka: r ? r.marka : null, ebat: r ? r.ebat : null, erp_bagli: !!musteriKodu });
        return;
      }
      const base = { veri: true, ad: r.ad, marka: r.marka, ebat: r.ebat, oneri: r.oneri, durum: r.durum, vade_menu: r.vade_menu, hedef_taban: r.hedef_taban, piyasa: { lo: r.lo, med: r.med, hi: r.hi }, rakip: r.rakip || null, erp_bagli: !!musteriKodu };
      if (isRep) { sendJson(response, 200, base); return; }
      sendJson(response, 200, Object.assign({}, base, { maliyet: r.maliyet, repl_cost: r.repl_cost, marj_oneri: r.marj_oneri, taban_kritik: r.floorCost || null, brand_hedef: r.brand_hedef, gercek: r.gercek, skor: skor, bilesenler: bilesenler, vade_oneri: vade_oneri }));
      return;
    }

    '''
ANCHOR2 = '// ===== SMARTKIYAS_V1 — Musteri vs KRB kiyas ====='
assert s.count(ANCHOR2) == 1, "SMARTKIYAS anchor count=%d" % s.count(ANCHOR2)
s = s.replace(ANCHOR2, ENDPOINT + ANCHOR2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] TEKLIF_ONERI_V1")
