  // === FINANS_TICARI_SERMAYE_V1 — Finans odasi kanonik veri ucu (v_finans_ticari_sermaye) ===
  if (request.method === "GET" && url.pathname === "/api/bi/finans/ticari-sermaye") {
    try {
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss; }
      if (!session) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      const { rows } = await query("SELECT * FROM v_finans_ticari_sermaye WHERE tenant_id = $1::uuid", [String(T)]);
      const r = rows[0] || {};
      const MN = x => (x === null || x === undefined) ? null : Math.round(Number(x) / 1e5) / 10;
      const NM = x => (x === null || x === undefined) ? null : Number(x);
      const dio = NM(r.dio);
      let asOf; try { asOf = new Date().toLocaleDateString("tr-TR", { day: "2-digit", month: "short", year: "numeric" }); } catch (e) { asOf = null; }
      const data = {
        as_of: asOf, donem: "son 12 ay · Tem'25–Haz'26",
        net_satis_lastik: MN(r.net_satis_lastik), ciro_sirket: MN(r.ciro_tum_sirket),
        smm: MN(r.smm), brut_kar: MN(r.brut_kar), brut_marj_pct: NM(r.marj_pct),
        ticari_alacaklar: MN(r.ar_net), net_gecikmis: MN(r.net_gecikmis), finansman_yillik: MN(r.finansman_yil),
        stok_lastik: MN(r.stok_deger), ticari_borclar: MN(r.ap_borc),
        dso: NM(r.dso), dio: dio, dpo: NM(r.dpo), ccc: NM(r.ccc),
        devir: (dio && dio > 0) ? Math.round(365 / dio * 10) / 10 : null,
        twc: MN(r.twc), bagli_sermaye_pct: NM(r.bagli_sermaye_oran)
      };
      sendJson(response, 200, { data });
    } catch (e) { console.error("[finans-ticari-sermaye]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }
  if (request.method === "GET" && url.pathname === "/api/bi/finans") { /* FINANS_SHELL_V1 */
    try {
      const _h = await readFile("/app/shells/finans.html", "utf8");
      response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      response.end(_h);
    } catch (e) { sendJson(response, 404, { error: "finans bulunamadi" }); }
    return;
  }
