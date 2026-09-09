# -*- coding: utf-8 -*-
# PORTFOY_V1 + KAPSAM_SAGLIK_V1 (server) — kanonik saha_musteri_saglik view'ine bağlanır.
#   (A) Kapsam rozeti: h1r/h2r ikili retention → saha_musteri_saglik.durum (aktif/soguyor/pasif).
#   (B) Yeni endpoint /api/saha/rapor/portfoy — Portföy Sağlığı (rep + yönetici rollup); alım_yok ayrı.
#   Idempotent (marker guard). requireSahaAccess. SAHA_DEPT_MAP: ["rapor"].
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "PORTFOY_V1" in s or "KAPSAM_SAGLIK_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

# ── (A) Kapsam rozeti rewire → kanonik view ─────────────────────────────────
h1 = "        h1r AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric v FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '360 days') AND fatura_tarihi < (CURRENT_DATE - INTERVAL '180 days') GROUP BY musteri_kodu),  /* KAPSAM_RETENTION_V1 */\n"
h2 = "        h2r AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric v FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '180 days') GROUP BY musteri_kodu),\n"
assert h1 in s, "h1r anchor yok"
assert h2 in s, "h2r anchor yok"
s = s.replace(h1, "").replace(h2, "")

sel_old = "               COALESCE(h1r.v,0)::numeric h1, COALESCE(h2r.v,0)::numeric h2, COALESCE(vis12.c,0)::int vc12  /* KAPSAM_RETENTION_V1 */"
sel_new = "               COALESCE(vis12.c,0)::int vc12, sg.durum saglik, sg.guven sguven  /* KAPSAM_SAGLIK_V1 */"
assert s.count(sel_old) == 1, "SELECT anchor=%d" % s.count(sel_old)
s = s.replace(sel_old, sel_new, 1)

join_old = ("          LEFT JOIN h1r ON h1r.musteri_kodu=m.musteri_kodu\n"
            "          LEFT JOIN h2r ON h2r.musteri_kodu=m.musteri_kodu\n"
            "          LEFT JOIN vis12 ON vis12.musteri_id=m.id\n")
join_new = ("          LEFT JOIN vis12 ON vis12.musteri_id=m.id\n"
            "          LEFT JOIN saha_musteri_saglik sg ON sg.tenant_id=$1::text AND sg.musteri_kodu=m.musteri_kodu  /* KAPSAM_SAGLIK_V1 */\n")
assert join_old in s, "JOIN anchor yok"
s = s.replace(join_old, join_new, 1)

map_old = 'tk: { vc: Number(x.vc12) || 0, durum: (Number(x.h2) > 0 ? "sadik" : Number(x.h1) > 0 ? "kayiyor" : "sessiz") } });  /* KAPSAM_RETENTION_V1 */'
map_new = 'tk: { vc: Number(x.vc12) || 0, durum: x.saglik || null, guven: x.sguven || null } });  /* KAPSAM_SAGLIK_V1 */'
assert s.count(map_old) == 1, "mapRow anchor=%d" % s.count(map_old)
s = s.replace(map_old, map_new, 1)

# ── (B) SAHA_DEPT_MAP: portfoy = ["rapor"] ──────────────────────────────────
dm_anchor = '    "/api/saha/rapor/ziyaret-etki": ["rapor"],  /* ZIYARET_ETKI_V1 */'
assert s.count(dm_anchor) == 1, "dept-map anchor=%d" % s.count(dm_anchor)
s = s.replace(dm_anchor, dm_anchor + '\n    "/api/saha/rapor/portfoy": ["rapor"],  /* PORTFOY_V1 */', 1)

# ── (B) Portföy endpoint — kapsam endpoint'inden önce ───────────────────────
ep_anchor = '    if (method === "GET" && path === "/api/saha/rapor/kapsam") {  /* KAPSAM_V1 */'
assert s.count(ep_anchor) == 1, "endpoint anchor=%d" % s.count(ep_anchor)
EP = r'''    if (method === "GET" && path === "/api/saha/rapor/portfoy") {  /* PORTFOY_V1 */
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, uid = session.userId, rol = session.sahaRole;
      const p = [tid];
      let repF = "", tipF = "";
      if (rol === "rep") { p.push(uid); repF = ` AND m.sorumlu_rep::text=$${p.length}::text`; }
      const _tip = url.searchParams.get("tip");
      if (_tip === "TUKETICI" || _tip === "TICARI") { p.push(_tip); tipF = ` AND m.tip=$${p.length}`; }
      const r = await query(`
        WITH ciro AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari
                       WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_kodu),
             son AS (SELECT musteri_id, MAX(ziyaret_tarihi) mx FROM saha_ziyaret
                       WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' GROUP BY musteri_id)
        SELECT m.id::text id, m.firma, m.il, m.ilce, m.tip, to_jsonb(m)->>'segment' segment,
               m.musteri_kodu, m.sorumlu_rep::text rid,
               COALESCE(c.yil,0)::numeric ciro, s.mx son,
               sg.durum, sg.guven, sg.ritim, sg.recency_ay
          FROM saha_musteri m
          LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu
          LEFT JOIN son s ON s.musteri_id=m.id
          LEFT JOIN saha_musteri_saglik sg ON sg.tenant_id=$1::text AND sg.musteri_kodu=m.musteri_kodu
         WHERE m.tenant_id::text=$1::text AND m.aktif=true${repF}${tipF}`, p);
      const nm = await query(`SELECT u.id::text id, COALESCE(u.full_name,u.email,'—') ad
          FROM users u JOIN tenant_users tu ON tu.user_id=u.id WHERE tu.tenant_id::text=$1::text`, [tid]);
      const nameMap = {}; for (const x of nm.rows) nameMap[x.id] = x.ad;
      const now = Date.now();
      const gunOf = (mx) => { if (!mx) return null; const d = new Date(mx); return isNaN(d) ? null : Math.max(0, Math.floor((now - d.getTime()) / 86400000)); };
      const rows = r.rows;
      const say = { aktif: 0, soguyor: 0, pasif: 0, alim_yok: 0 };
      let riskCiro = 0, aktifCiro = 0;
      const bandDefs = [["0-3 ay", 0, 3], ["3-6 ay", 3, 6], ["6-12 ay", 6, 12], ["12+ ay", 12, 100000]];
      const band = {}; bandDefs.forEach(([k]) => band[k] = { etiket: k, n: 0, ciro: 0 });
      const liste = [], repMap = {};
      for (const x of rows) {
        const d = x.durum || null, ciro = Number(x.ciro) || 0;
        if (!d) { say.alim_yok++; continue; }
        say[d] = (say[d] || 0) + 1;
        if (d === "aktif") aktifCiro += ciro; else riskCiro += ciro;
        const rc = Number(x.recency_ay);
        if (Number.isFinite(rc)) { const bd = bandDefs.find(([, lo, hi]) => rc >= lo && rc < hi) || bandDefs[bandDefs.length - 1]; band[bd[0]].n++; band[bd[0]].ciro += ciro; }
        if (d === "soguyor" || d === "pasif") {
          liste.push({ id: x.id, firma: x.firma, il: x.il, tip: x.tip, segment: x.segment || null, ciro, gun: gunOf(x.son), durum: d, guven: x.guven, ritim: x.ritim != null ? Number(x.ritim) : null, recency: Number.isFinite(rc) ? rc : null, rep: x.rid ? (nameMap[x.rid] || null) : null, rep_id: x.rid || null });
          if (rol !== "rep" && x.rid) { const g = repMap[x.rid] || (repMap[x.rid] = { rep_id: x.rid, rep: nameMap[x.rid] || "—", soguyor: 0, pasif: 0, risk_ciro: 0 }); g[d]++; g.risk_ciro += ciro; }
        }
      }
      liste.sort((a, b) => b.ciro - a.ciro);
      const temsilci = Object.values(repMap).sort((a, b) => b.risk_ciro - a.risk_ciro);
      sendJson(response, 200, {
        rol: rol === "rep" ? "rep" : "yonetici",
        ozet: { toplam: rows.length, alimli: say.aktif + say.soguyor + say.pasif, aktif: say.aktif, soguyor: say.soguyor, pasif: say.pasif, alim_yok: say.alim_yok, risk_ciro: riskCiro, aktif_ciro: aktifCiro },
        bantlar: bandDefs.map(([k]) => band[k]),
        liste: liste.slice(0, 300), liste_toplam: liste.length,
        temsilci
      });
      return;
    }

'''
s = s.replace(ep_anchor, EP + ep_anchor, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] PORTFOY_V1 + KAPSAM_SAGLIK_V1 (server) — Kapsam rozeti view'e, Portföy endpoint eklendi")
