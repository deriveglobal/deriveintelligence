# -*- coding: utf-8 -*-
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
REL  = "server_container.mjs"; MARK = "PORTFOYUM_EP_V1"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit
ANCHOR = '    if (method === "GET" && path === "/api/saha/musteriler") {'
assert orig.count(ANCHOR) == 1, "ANCHOR bulundu=%d" % orig.count(ANCHOR)
NEW = r'''    /* PORTFOYUM_EP_V1 — rep "Portföyüm": dönem(canlı)/vade/ödeme/risk, rep+tenant kapsamlı */
    if (method === "GET" && path === "/api/saha/portfoyum") {
      const session = await requireSahaAccess(request);
      const T = session.tenantId;
      const pA = [T];
      const scopeA = _sahaScopeSql(session, pA, "m");
      const baseSql = `
        SELECT DISTINCT ON (m.musteri_kodu)
          m.musteri_kodu, m.firma, m.il, m.ilce,
          mm.toplam_ciro::bigint AS ciro_tum, mm.son_bakiye::bigint AS bakiye, mm.son_fatura AS son_fatura,
          rk.kredi_limiti::bigint AS kredi_limiti, rk.toplam_risk::bigint AS toplam_risk, rk.vadesi_gecmis::bigint AS vadesi_gecmis,
          round(t.ort_gecikme_gun)::int AS ort_gecikme, round(t.gec_odeme_orani)::int AS gec_orani,
          round(t.son12_gecikme_gun)::int AS son12_gecikme, round(t.son12_gec_orani)::int AS son12_gec_orani
        FROM saha_musteri m
        LEFT JOIN master_musteri  mm ON mm.tenant_id=m.tenant_id AND mm.musteri_kodu=m.musteri_kodu
        LEFT JOIN bi_musteri_risk rk ON rk.tenant_id=m.tenant_id AND rk.muhatap_kodu=m.musteri_kodu
        LEFT JOIN bi_tahsilat      t ON t.tenant_id=m.tenant_id AND t.muhatap_kodu=m.musteri_kodu
        WHERE m.tenant_id=$1 AND m.aktif=true AND COALESCE(m.musteri_kodu,'')<>''` + scopeA + `
        ORDER BY m.musteri_kodu`;
      const baseR = await query(baseSql, pA);
      const pB = [T];
      const scopeB = _sahaScopeSql(session, pB, "m");
      const perSql = `
        WITH mine AS (
          SELECT DISTINCT m.musteri_kodu FROM saha_musteri m
          WHERE m.tenant_id=$1 AND m.aktif=true AND COALESCE(m.musteri_kodu,'')<>''` + scopeB + `
        ),
        p AS (SELECT date_trunc('month',CURRENT_DATE) AS m0, date_trunc('year',CURRENT_DATE) AS y0),
        fv AS (
          SELECT f.musteri_kodu, f.fatura_tarihi, f.satir_tutar, f.miktar,
            CASE WHEN f.odeme_kosulu ~* 'peşin|pesin|mal mukabili|vesaik|mahsuben' THEN 0
                 WHEN f.odeme_kosulu ~ '(\d+)\s*[Gg]ün' THEN (regexp_match(f.odeme_kosulu,'(\d+)\s*[Gg]ün'))[1]::int
                 WHEN f.odeme_kosulu ~* 'havale|kredi kart|sanal pos|çek|cek' THEN 0 ELSE NULL END AS vg
          FROM bi_satis_faturalari f JOIN mine ON mine.musteri_kodu=f.musteri_kodu
          WHERE f.tenant_id=$1::text AND f.satir_tutar>0
        )
        SELECT fv.musteri_kodu,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi = CURRENT_DATE))::bigint AS bugun,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= date_trunc('week',CURRENT_DATE)))::bigint AS hafta,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= p.m0))::bigint AS buay,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= date_trunc('month',CURRENT_DATE - INTERVAL '1 year') AND fv.fatura_tarihi <= CURRENT_DATE - INTERVAL '1 year'))::bigint AS buay_gy,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= p.m0 - INTERVAL '3 month'  AND fv.fatura_tarihi < p.m0))::bigint AS ciro_3ay,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= p.m0 - INTERVAL '6 month'  AND fv.fatura_tarihi < p.m0))::bigint AS ciro_6ay,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= p.y0 AND fv.fatura_tarihi < p.m0))::bigint AS ciro_ytd,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= p.m0 - INTERVAL '15 month' AND fv.fatura_tarihi < p.m0 - INTERVAL '12 month'))::bigint AS ciro_3ay_gy,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= p.m0 - INTERVAL '18 month' AND fv.fatura_tarihi < p.m0 - INTERVAL '12 month'))::bigint AS ciro_6ay_gy,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= p.y0 - INTERVAL '1 year' AND fv.fatura_tarihi < p.m0 - INTERVAL '12 month'))::bigint AS ciro_ytd_gy,
          round(SUM(fv.satir_tutar) FILTER (WHERE fv.fatura_tarihi >= p.m0 - INTERVAL '12 month'))::bigint AS ciro_12,
          round(SUM(fv.miktar)      FILTER (WHERE fv.fatura_tarihi >= p.m0 - INTERVAL '12 month'))::int    AS adet_12,
          round(SUM(fv.vg*fv.satir_tutar) FILTER (WHERE fv.vg IS NOT NULL AND fv.fatura_tarihi >= p.m0 - INTERVAL '12 month'))::bigint AS vade_x_ciro,
          round(SUM(fv.satir_tutar)       FILTER (WHERE fv.vg IS NOT NULL AND fv.fatura_tarihi >= p.m0 - INTERVAL '12 month'))::bigint AS ciro_vade,
          round(SUM(fv.satir_tutar)       FILTER (WHERE fv.vg = 0            AND fv.fatura_tarihi >= p.m0 - INTERVAL '12 month'))::bigint AS pesin_ciro
        FROM fv CROSS JOIN p GROUP BY fv.musteri_kodu`;
      const perR = await query(perSql, pB);
      const byKod = {}; for (const r of perR.rows) byKod[r.musteri_kodu] = r;
      const musteriler = baseR.rows.map(b => {
        const pp = byKod[b.musteri_kodu] || {};
        const cv=Number(pp.ciro_vade||0), vx=Number(pp.vade_x_ciro||0), c12=Number(pp.ciro_12||0), pc=Number(pp.pesin_ciro||0);
        return { musteri_kodu:b.musteri_kodu, firma:b.firma, il:b.il, ilce:b.ilce,
          ciro_tum:b.ciro_tum, bakiye:b.bakiye, son_fatura:b.son_fatura,
          kredi_limiti:b.kredi_limiti, toplam_risk:b.toplam_risk, vadesi_gecmis:b.vadesi_gecmis,
          ort_gecikme:b.ort_gecikme, gec_orani:b.gec_orani, son12_gecikme:b.son12_gecikme, son12_gec_orani:b.son12_gec_orani,
          ciro_12:c12||null, adet_12:pp.adet_12||null,
          bugun:pp.bugun||null, hafta:pp.hafta||null, buay:pp.buay||null, buay_gy:pp.buay_gy||null,
          ciro_3ay:pp.ciro_3ay||null, ciro_6ay:pp.ciro_6ay||null, ciro_ytd:pp.ciro_ytd||null,
          ciro_3ay_gy:pp.ciro_3ay_gy||null, ciro_6ay_gy:pp.ciro_6ay_gy||null, ciro_ytd_gy:pp.ciro_ytd_gy||null,
          agirlikli_vade: cv>0?Math.round(vx/cv):null, pesin_pct: c12>0?Math.round(100*pc/c12):null, segment:null };
      });
      const num=v=>Number(v)||0;
      const ozet={ musteri:musteriler.length,
        ciro_12:musteriler.reduce((a,c)=>a+num(c.ciro_12),0),
        buay:musteriler.reduce((a,c)=>a+num(c.buay),0), buay_gy:musteriler.reduce((a,c)=>a+num(c.buay_gy),0),
        hafta:musteriler.reduce((a,c)=>a+num(c.hafta),0), bugun:musteriler.reduce((a,c)=>a+num(c.bugun),0),
        vadesi_gecmis_toplam:musteriler.reduce((a,c)=>a+num(c.vadesi_gecmis),0),
        riskli_hesap:musteriler.filter(c=>num(c.vadesi_gecmis)>0).length };
      sendJson(response, 200, { rep:{ id:session.userId, ad:session.name||"" }, ozet, musteriler });
      return;
    }

'''
s = orig.replace(ANCHOR, NEW + ANCHOR, 1)
if not os.path.exists(path + ".portfoyumbak"):
    with io.open(path + ".portfoyumbak","w",encoding="utf-8") as f: f.write(orig)
with io.open(path,"w",encoding="utf-8") as f: f.write(s)
print("OK", REL, "| MARK:", s.count(MARK))
