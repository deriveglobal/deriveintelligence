#!/usr/bin/env python3
# MOBIL_DIKKAT — GET /api/bi/mobil-dikkat: mobil kokpit "Bugun ne yapmali" sentezi (IZOLE, yeni route).
#   Kaynak: bi_tenant_hafiza gozlem (kayip/buyuyen/yavas) + bi_musteri_risk (en buyuk gecikme hesabi + yogunlasma).
#   Deterministik, tenant-scoped. Mevcut hicbir seye dokunmaz. HAFIZA_FULL onkosul (bi_tenant_hafiza).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MOBIL_DIKKAT" in s:
    print("[skip] MOBIL_DIKKAT zaten var"); sys.exit(0)

ANCHOR = '  if (request.method === "GET" && url.pathname === "/api/bi/kokpit-data") {'
assert ANCHOR in s, "HATA: kokpit-data anchor yok"
assert s.count(ANCHOR) == 1, "HATA: anchor tek degil"

BLOCK = r'''  if (request.method === "GET" && url.pathname === "/api/bi/mobil-dikkat") { /* MOBIL_DIKKAT */
    try {
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss; }
      if (!session) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      // 1) Davranis gozlemleri (bi_tenant_hafiza, kaynak=gozlem)
      let kayip = [], buyuyen = [], yavas = [];
      try {
        const _g = (await query("SELECT trim(split_part(icerik, ':', 1)) ad, icerik FROM bi_tenant_hafiza WHERE tenant_id=$1 AND kaynak='gozlem' AND gecerli ORDER BY son_gorulme DESC LIMIT 80", [String(T)])).rows;
        for (const r of _g) {
          const ic = (r.icerik || "").toLowerCase(); const ad = (r.ad || "").trim();
          if (!ad) continue;
          if (ic.indexOf("azalt") >= 0 && kayip.length < 6 && !kayip.includes(ad)) kayip.push(ad);
          else if (ic.indexOf("artir") >= 0 && buyuyen.length < 6 && !buyuyen.includes(ad)) buyuyen.push(ad);
          else if ((ic.indexOf("gec odeyen") >= 0 || ic.indexOf("kronik") >= 0) && yavas.length < 6 && !yavas.includes(ad)) yavas.push(ad);
        }
      } catch (e) { console.error("[mobil-dikkat-gozlem]", e && e.message); }
      // 2) En buyuk gecikme hesabi + yogunlasma (bi_musteri_risk net, KRB borcuyla mahsup)
      let gecikme = null;
      try {
        const _oSql = "WITH ov AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, COALESCE(NULLIF(TRIM(muhatap_adi),''),muhatap_kodu) ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu), n AS (SELECT o.ad, GREATEST(o.vg+COALESCE(cb.borc,0),0) net FROM ov o LEFT JOIN cb ON cb.musteri_kodu=o.kod WHERE o.musteri_mi AND o.grup NOT ILIKE '%TEDAR%') SELECT ad, net FROM n WHERE net>0 ORDER BY net DESC";
        const _r = (await query(_oSql, [String(T)])).rows;
        if (_r.length) {
          const toplam = _r.reduce((a, x) => a + Number(x.net || 0), 0);
          const ilk5 = _r.slice(0, 5).reduce((a, x) => a + Number(x.net || 0), 0);
          gecikme = { ad: _r[0].ad, net_m: +(Number(_r[0].net) / 1e6).toFixed(1), ilk5_pct: toplam > 0 ? Math.round(ilk5 / toplam * 100) : null, toplam_m: +(toplam / 1e6).toFixed(1) };
        }
      } catch (e) { console.error("[mobil-dikkat-gecikme]", e && e.message); }
      sendJson(response, 200, { kayip: kayip, buyuyen: buyuyen, yavas: yavas, gecikme: gecikme });
    } catch (e) { console.error("[mobil-dikkat]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }
'''

s = s.replace(ANCHOR, BLOCK + ANCHOR, 1) + "\n/* MOBIL_DIKKAT */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] MOBIL_DIKKAT — /api/bi/mobil-dikkat (gozlem sentezi + gecikme kaynagi) eklendi")
