#!/usr/bin/env python3
# KOKPIT_UMBRELLA_V1 — additive, idempotent, geri-alinabilir.
# Yeni READ-ONLY uc: GET /api/bi/kokpit-umbrella?ay=N (veya ?ytd=1)
# PSR=tuketici / geri kalan=ticari urun-split; SQL = verify_umbrella.sql v2 ile birebir.
# Mevcut hicbir kod DEGISMEZ; sadece kokpit-data route'unun ONUNE yeni bir if-blogu eklenir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "KOKPIT_UMBRELLA_V1" in s:
    print("[skip] KOKPIT_UMBRELLA_V1 zaten var — degisiklik yok")
    sys.exit(0)
anchor = 'if (request.method === "GET" && url.pathname === "/api/bi/kokpit-data") {'
i = s.find(anchor)
assert i != -1, "HATA: kokpit-data anchor bulunamadi — patch guvenli degil, iptal."
ls = s.rfind("\n", 0, i) + 1  # kokpit-data satirinin basi

BLOCK = r'''  // === KOKPIT_UMBRELLA_V1 — per-umbrella (PSR=tuketici / rest=ticari) urun-split, donem parametreli ===
  if (request.method === "GET" && url.pathname === "/api/bi/kokpit-umbrella") {
    try {
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss; }
      if (!session) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      const ytd = url.searchParams.get("ytd") === "1";
      let ayN = parseInt(url.searchParams.get("ay") || "12", 10); if (!(ayN >= 1 && ayN <= 24)) ayN = 12;
      const winSql = ytd ? "ay >= date_trunc('year', CURRENT_DATE)" : "ay >= (CURRENT_DATE - ($2 * INTERVAL '1 month'))";
      const params = ytd ? [String(T)] : [String(T), ayN];
      const UMB = "CASE WHEN kategori_segment(kategori)='PSR' THEN 'TUK' ELSE 'TIC' END";
      const tot = (await query("SELECT " + UMB + " umb, round(sum(ciro)/1e6,1)::float8 c, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 mj, sum(adet)::int adet FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + winSql + " GROUP BY 1", params)).rows;
      const psrSezon = (await query("SELECT kategori_sezon(kategori) s, round(sum(ciro)/1e6,1)::float8 c, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 mj FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + winSql + " AND kategori_segment(kategori)='PSR' GROUP BY 1 ORDER BY 2 DESC", params)).rows;
      const ticSegment = (await query("SELECT kategori_segment(kategori) s, round(sum(ciro)/1e6,1)::float8 c, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 mj FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + winSql + " AND kategori_segment(kategori)<>'PSR' GROUP BY 1 ORDER BY 2 DESC", params)).rows;
      const marka = (await query("SELECT marka m, " + UMB + " umb, round(sum(ciro)/1e6,1)::float8 c, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 mj, sum(adet)::int adet FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + winSql + " GROUP BY 1,2 HAVING sum(ciro)>0 ORDER BY c DESC", params)).rows;
      const pick = (u) => tot.find((r) => r.umb === u) || { c: 0, mj: null, adet: 0 };
      const tk = pick("TUK"), tc = pick("TIC");
      const cc = (tk.c || 0) + (tc.c || 0);
      const wmarj = cc ? +(((tk.c * (tk.mj || 0)) + (tc.c * (tc.mj || 0))) / cc).toFixed(1) : null;
      sendJson(response, 200, {
        ay: ytd ? "ytd" : ayN,
        toplam: { ciro: +cc.toFixed(1), marj: wmarj, adet: (tk.adet || 0) + (tc.adet || 0) },
        tuketici: { ciro: tk.c, marj: tk.mj, adet: tk.adet, sezon: psrSezon, marka: marka.filter((m) => m.umb === "TUK") },
        ticari: { ciro: tc.c, marj: tc.mj, adet: tc.adet, segment: ticSegment, marka: marka.filter((m) => m.umb === "TIC") }
      });
    } catch (e) { console.error("[kokpit-umbrella]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }

'''

s = s[:ls] + BLOCK + s[ls:]
open(F, "w", encoding="utf-8").write(s)
print("[ok] KOKPIT_UMBRELLA_V1 eklendi @ offset", ls)
