#!/usr/bin/env python3
# ODEME_VADELERI_V1 — /api/bi/odeme-vadeleri: Tedarikçi vade vs Müşteri vade (finansman farkı).
# Müşteri: bi_satis_faturalari.odeme_kosulu (satir_tutar ağırlıklı). Tedarikçi: bi_tedarikci_faturalari.vade_turu
# (satir_kdv_haric ağırlıklı). Kova: Peşin/30/60/90/120+. Çift erişim (intelligence VEYA saha manager/admin).
# Idempotent. /opt/krb-assessment içinde çalıştır. server_container.mjs → docker build + up.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "ODEME_VADELERI_V1" in s:
    print("odeme-vade endpoint: already present, skip"); print("DONE."); raise SystemExit

anchor = "    if (request.method === 'GET' && url.pathname === '/api/bi/finans-marka-detay') {"
assert s.count(anchor) == 1, "anchor"

ep = r'''    // ODEME_VADELERI_V1 — Tedarikçi vade vs Müşteri vade (finansman farkı). Desktop + mobil.
    if (request.method === 'GET' && url.pathname === '/api/bi/odeme-vadeleri') {
      try {
        let session = await requireModuleAccess(request, "intelligence").catch(() => null);
        if (!session) {
          const _ss = await requireSahaAccess(request).catch(() => null);
          if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss;
        }
        if (!session) { sendJson(response, 403, { error: "yetki yok" }); return; }
        const T = String(session.tenantId);
        const _mus = await query(
          "SELECT COALESCE(NULLIF(TRIM(odeme_kosulu),''),'—') AS kosul, SUM(satir_tutar) AS tut " +
          "FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND satir_tutar>0 " +
          "AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months') GROUP BY 1", [T]);
        const _ted = await query(
          "SELECT COALESCE(NULLIF(TRIM(vade_turu),''),'—') AS kosul, SUM(satir_kdv_haric) AS tut " +
          "FROM bi_tedarikci_faturalari WHERE tenant_id::text=$1 AND satir_kdv_haric>0 " +
          "AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months') GROUP BY 1", [T]);
        const gun = (l) => {
          const x = String(l || "").toLocaleLowerCase("tr");
          if (/(peşin|pesin|nakit|havale|kredi kart|çek|cek|senet)/.test(x)) return 0;
          const m = x.match(/(\d+)\s*g[üu]n/);
          return m ? parseInt(m[1], 10) : null;
        };
        const kova = (d) => d == null ? null : (d <= 0 ? "Peşin" : d <= 30 ? "30 gün" : d <= 60 ? "60 gün" : d <= 90 ? "90 gün" : "120+ gün");
        const KOVALAR = ["Peşin", "30 gün", "60 gün", "90 gün", "120+ gün"];
        const isle = (rows) => {
          const dag = {}; let toplam = 0, agirGun = 0, agirTut = 0;
          for (const r of rows) {
            const t = Number(r.tut) || 0; if (t <= 0) continue;
            const d = gun(r.kosul); const k = kova(d);
            toplam += t;
            if (k) dag[k] = (dag[k] || 0) + t;
            if (d != null) { agirGun += d * t; agirTut += t; }
          }
          const dagilim = KOVALAR.map(k => ({
            kova: k, tutar: Math.round(dag[k] || 0),
            pct: toplam > 0 ? Math.round((dag[k] || 0) / toplam * 1000) / 10 : 0
          }));
          return { ort_gun: agirTut > 0 ? Math.round(agirGun / agirTut * 10) / 10 : 0, toplam: Math.round(toplam), dagilim };
        };
        const musteri = isle(_mus.rows), tedarikci = isle(_ted.rows);
        sendJson(response, 200, {
          kovalar: KOVALAR, musteri, tedarikci,
          fark_gun: Math.round((musteri.ort_gun - tedarikci.ort_gun) * 10) / 10
        });
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }

'''
s = s.replace(anchor, ep + anchor, 1)
write(FP, s)
print("odeme-vade endpoint: inserted")
print("DONE.")
