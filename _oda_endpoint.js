  // === FINANS_ODA_LIVE_V6 — tek kanonik uc: odanin HER sayisi canli kaynaktan; hardcoded YOK, kaynagi olmayan alan null(->"—"). V6: Bu ay marj = KANON v_marj_cari_ay (akis maliyeti, cari ay canli view — kokpit ile ayni kaynak, tesvik oncesi brut) ===
  if (request.method === "GET" && url.pathname === "/api/bi/finans/oda") {
    if (response.headersSent) return;
    try {
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss; }
      if (!session) { if (!response.headersSent) sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = session && session.tenantId; if (!T) { if (!response.headersSent) sendJson(response, 401, { error: "oturum yok" }); return; }
      const N = x => (x === null || x === undefined) ? null : Number(x);
      const M1 = x => (x === null || x === undefined) ? null : Math.round(Number(x) / 1e5) / 10;
      const W = "ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - 12*INTERVAL '1 month') AND ay <= (SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1)";
      // CORE — v_finans_ticari_sermaye
      const v = (await query("SELECT * FROM v_finans_ticari_sermaye WHERE tenant_id = $1::uuid", [String(T)])).rows[0] || {};
      const dio = N(v.dio);
      const core = {
        net_satis_lastik: M1(v.net_satis_lastik), ciro_sirket: M1(v.ciro_tum_sirket), smm: M1(v.smm),
        brut_kar: M1(v.brut_kar), marj_pct: N(v.marj_pct), ticari_alacaklar: M1(v.ar_net),
        ticari_borclar: M1(v.ap_borc), finansman_yil: M1(v.finansman_yil),
        dso: N(v.dso), dio: dio, dpo: N(v.dpo), ccc: N(v.ccc), twc: M1(v.twc),
        bagli_sermaye_pct: N(v.bagli_sermaye_oran), devir: (dio && dio > 0) ? Math.round(365 / dio * 10) / 10 : null
      };
      // STOK — bi_stok_durumu LASTIK, en son export
      const _sk = (await query("SELECT grup_adi, sum(toplam_deger) d FROM bi_stok_durumu WHERE tenant_id::text=$1 AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=$1) AND grup_adi ILIKE 'LASTIK%' GROUP BY grup_adi ORDER BY d DESC", [String(T)])).rows;
      const stok = { toplam: Math.round(_sk.reduce((a, r) => a + Number(r.d || 0), 0) / 1e5) / 10, kirilim: _sk.map(r => ({ grup: r.grup_adi, deger: M1(r.d) })) };
      // GECIKMIS — bi_musteri_risk + cari
      const _g = (await query("WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, muhatap_adi ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu) SELECT r.ad, GREATEST(r.vg+COALESCE(cb.borc,0),0) net, r.vg gross FROM r LEFT JOIN cb ON cb.musteri_kodu=r.kod WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%'", [String(T)])).rows;
      let gBrut = 0, gNet = 0; _g.forEach(r => { gBrut += Number(r.gross || 0); gNet += Number(r.net || 0); });
      const top = _g.map(r => ({ ad: r.ad, net: Number(r.net || 0) })).filter(x => x.net > 0).sort((a, b) => b.net - a.net).slice(0, 6).map(x => ({ ad: x.ad, net: Math.round(x.net / 1e5) / 10 }));
      const gecikmis = { brut: Math.round(gBrut / 1e5) / 10, net: Math.round(gNet / 1e5) / 10, top: top };
      // MARKA MARJ — bi_marj_atom 12 ay
      const marka = (await query("SELECT marka, round(sum(ciro)/1e6,1)::float8 ciro, round(sum(brut_kar)/nullif(sum(ciro),0)*100,1)::float8 marj, sum(adet)::int adet FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W + " GROUP BY marka HAVING sum(ciro)>0 ORDER BY ciro DESC LIMIT 14", [String(T)])).rows.map(r => ({ marka: r.marka, ciro: N(r.ciro), marj: N(r.marj), adet: N(r.adet) }));
      // CATAL — tuketici(PSR)/ticari(non-PSR) ciro+marj
      const _cat = (await query("SELECT CASE WHEN kategori_segment(kategori)='PSR' THEN 'TUK' ELSE 'TIC' END umb, round(sum(ciro)/1e6,1)::float8 c, round(sum(brut_kar)/nullif(sum(ciro),0)*100,1)::float8 mj FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W + " GROUP BY 1", [String(T)])).rows;
      const _pick = u => _cat.find(r => r.umb === u) || {};
      const catal = { tuk: { ciro: N(_pick('TUK').c), marj: N(_pick('TUK').mj) }, tic: { ciro: N(_pick('TIC').c), marj: N(_pick('TIC').mj) } };
      // KAR HARITASI — tuketici sezon + ticari kategori-segment
      const kar_tuk = (await query("SELECT kategori_sezon(kategori) s, round(sum(ciro)/1e6,1)::float8 c, round(sum(brut_kar)/nullif(sum(ciro),0)*100,1)::float8 mj FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W + " AND kategori_segment(kategori)='PSR' GROUP BY 1 ORDER BY 2 DESC", [String(T)])).rows.map(r => ({ ad: r.s, ciro: N(r.c), marj: N(r.mj) }));
      const kar_tic = (await query("SELECT kategori_segment(kategori) s, round(sum(ciro)/1e6,1)::float8 c, round(sum(brut_kar)/nullif(sum(ciro),0)*100,1)::float8 mj FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W + " AND kategori_segment(kategori)<>'PSR' GROUP BY 1 ORDER BY 2 DESC", [String(T)])).rows.map(r => ({ ad: r.s, ciro: N(r.c), marj: N(r.mj) }));
      const kar = { tuk: kar_tuk, tic: kar_tic };
      // TREND — 12 ay aylik marj + ciro + brut kar (zaman seciciyi client tarafinda pencereler; hepsi canli tek kaynak)
      const trend = (await query("SELECT to_char(ay,'YYYY-MM') ay, round(sum(brut_kar)/nullif(sum(ciro),0)*100,1)::float8 marj, round(sum(ciro)/1e6,2)::float8 ciro, round(sum(brut_kar)/1e6,2)::float8 bk FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + W + " GROUP BY ay ORDER BY ay", [String(T)])).rows.map(r => ({ ay: r.ay, marj: N(r.marj), ciro: N(r.ciro), bk: N(r.bk) }));
      const _a = (await query("SELECT to_char(max(ay),'YYYY-MM') a FROM bi_marj_atom WHERE tenant_id::text=$1", [String(T)])).rows[0];
      // PENCERE — zaman secici KOKPITLE AYNI KAYNAK: ciro = bi_satis_faturalari (satir_tutar>0, fatura_tarihi), marj = bi_marj_atom (lastik). Takvim pencereleri.
      const _pc = (await query(
        "SELECT " +
        "round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE))/1e6,1)::float8 buay, " +
        "round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '2 month')/1e6,1)::float8 m3, " +
        "round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '5 month')/1e6,1)::float8 m6, " +
        "round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('month',CURRENT_DATE)-INTERVAL '11 month')/1e6,1)::float8 m12, " +
        "round(sum(satir_tutar) FILTER (WHERE fatura_tarihi >= date_trunc('year',CURRENT_DATE))/1e6,1)::float8 yb " +
        "FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND satir_tutar>0", [String(T)])).rows[0] || {};
      const _pm = (await query(
        "SELECT " +
        "round(sum(brut_kar) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE))/nullif(sum(ciro) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE)),0)*100,1)::float8 buay, " +
        "round(sum(brut_kar) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '2 month')/nullif(sum(ciro) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '2 month'),0)*100,1)::float8 m3, " +
        "round(sum(brut_kar) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '5 month')/nullif(sum(ciro) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '5 month'),0)*100,1)::float8 m6, " +
        "round(sum(brut_kar) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '11 month')/nullif(sum(ciro) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '11 month'),0)*100,1)::float8 m12, " +
        "round(sum(brut_kar) FILTER (WHERE ay >= date_trunc('year',CURRENT_DATE))/nullif(sum(ciro) FILTER (WHERE ay >= date_trunc('year',CURRENT_DATE)),0)*100,1)::float8 yb " +
        "FROM bi_marj_atom WHERE tenant_id::text=$1", [String(T)])).rows[0] || {};
      // BU AY CANLI MARJ (V6) — KANON: v_marj_cari_ay (akis maliyeti, cari ay, canli view). Finans + kokpit AYNI kaynak.
      // marj = cari-ay lastik ciro-agirlikli (tesvik oncesi brut). kapsam = maliyeti bilinen lastik cirosunun cari-ay toplam lastik cirosuna orani.
      const _am = (await query(
        "WITH cov AS (SELECT round(100*sum(brut_kar)/nullif(sum(ciro),0),1)::float8 marj, sum(ciro) ck FROM v_marj_cari_ay WHERE tenant_id=$1::uuid), " +
        "tot AS (SELECT sum(satir_tutar) ct FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND ebat IS NOT NULL AND miktar>0 AND satir_tutar>0 AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)) " +
        "SELECT cov.marj, round(100*cov.ck/nullif(tot.ct,0))::float8 kapsam FROM cov, tot", [String(T)])).rows[0] || {};
      const _buayMarj = N(_am.marj);
      const _buayKaps = (_am.kapsam != null) ? Math.round(Number(_am.kapsam)) : null;
      const pencere = {
        buay: { ciro: N(_pc.buay), marj: (_buayMarj != null ? _buayMarj : N(_pm.buay)), marj_tahmin: (_buayMarj != null), kapsam: _buayKaps },
        m3: { ciro: N(_pc.m3), marj: N(_pm.m3) },
        m6: { ciro: N(_pc.m6), marj: N(_pm.m6) }, m12: { ciro: N(_pc.m12), marj: N(_pm.m12) },
        yb: { ciro: N(_pc.yb), marj: N(_pm.yb) }
      };
      const data = { as_of: _a ? _a.a : null, core, stok, gecikmis, marka, catal, kar, trend, pencere, aging: null, sizinti: null, motor_trend: null };
      if (!response.headersSent) sendJson(response, 200, { data: data });
    } catch (e) { console.error("[finans-oda]", e && e.message); if (!response.headersSent) sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }
