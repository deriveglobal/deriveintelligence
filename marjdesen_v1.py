#!/usr/bin/env python3
# MARJDESEN_V1 — Marj Alarmi satirini (marka×ebat) DESEN (kalem_kodu) seviyesine ac.
#   GET /api/bi/marj-alarm-desen?marka=&ebat=&hedef=&ay=  -> o ebattaki her desen: marj, ort satis,
#     yenileme maliyeti, onerilen taban, sizinti. Desen adi = kalem_tanimi. Replacement kalem basina.
# Yetki: intelligence VEYA saha manager/admin. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "MARJDESEN_V1" in s:
    print("marjdesen: already present, skip"); print("DONE."); raise SystemExit

ANCHOR = (
    '  if (request.method === "GET" && url.pathname === "/api/bi/kokpit") {\n'
    '    try {\n'
    '      const _h = await readFile("/app/shells/kokpit.html", "utf8");'
)
assert s.count(ANCHOR) == 1, "kokpit anchor"

BLK = '''    // MARJDESEN_V1 — marj alarmi desen (kalem) kirilimi
    if (request.method === "GET" && url.pathname === "/api/bi/marj-alarm-desen") {
      let _s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let _ss = _s ? null : await requireSahaAccess(request).catch(() => null);
      const _sess = _s || _ss;
      if (!_sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = _sess.tenantId;
      const marka = (url.searchParams.get("marka") || "").trim();
      const ebat = (url.searchParams.get("ebat") || "").trim();
      const hedef = Math.min(0.5, Math.max(0, parseFloat(url.searchParams.get("hedef") || "0.12")));
      const ay = Math.min(24, Math.max(1, parseInt(url.searchParams.get("ay") || "12", 10)));
      if (!marka || !ebat) { sendJson(response, 400, { error: "marka+ebat zorunlu" }); return; }
      try {
        const rows = (await query(
          `WITH sku AS (
             SELECT kalem_kodu, SUM(adet) adet, SUM(ciro) ciro, SUM(brut_kar) kar
             FROM bi_marj_atom WHERE tenant_id::text=$1 AND marka=$2 AND ebat=$3
               AND ay >= (CURRENT_DATE - ($4::int * INTERVAL '1 month')) AND kalem_kodu IS NOT NULL
             GROUP BY kalem_kodu),
           ad AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, kalem_tanimi FROM bi_satis_faturalari
             WHERE tenant_id::text=$1 AND kalem_tanimi IS NOT NULL AND kalem_kodu IN (SELECT kalem_kodu FROM sku)
             ORDER BY kalem_kodu, fatura_tarihi DESC),
           repl AS (SELECT kalem_kodu, SUM(satir_kdv_haric)/NULLIF(SUM(miktar),0) repl_cost
             FROM bi_tedarikci_faturalari WHERE tenant_id::text=$1 AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '90 days')
               AND kalem_kodu IN (SELECT kalem_kodu FROM sku) GROUP BY kalem_kodu)
           SELECT s.kalem_kodu, ad.kalem_tanimi,
             s.adet::int adet, round(s.ciro)::float8 ciro, round(s.kar)::float8 kar,
             round(s.kar/NULLIF(s.ciro,0)*100,1)::float8 marj_pct,
             round(s.ciro/NULLIF(s.adet,0))::float8 avg_satis,
             round((s.ciro-s.kar)/NULLIF(s.adet,0))::float8 avg_maliyet,
             round(r.repl_cost)::float8 repl_cost
           FROM sku s LEFT JOIN ad ON ad.kalem_kodu=s.kalem_kodu LEFT JOIN repl r ON r.kalem_kodu=s.kalem_kodu
           WHERE s.ciro > 0 ORDER BY s.ciro DESC LIMIT 60`,
          [T, marka, ebat, ay])).rows;
        const desenler = rows.map(r => {
          const taban = (Number(r.repl_cost) || Number(r.avg_maliyet) || 0);
          const floor = taban > 0 ? taban / (1 - hedef) : null;
          return {
            kalem_kodu: r.kalem_kodu, desen: r.kalem_tanimi || r.kalem_kodu,
            adet: Number(r.adet), ciro: Number(r.ciro), marj_pct: Number(r.marj_pct),
            avg_satis: Number(r.avg_satis), avg_maliyet: Number(r.avg_maliyet),
            repl_cost: r.repl_cost != null ? Number(r.repl_cost) : null,
            onerilen_taban: floor != null ? Math.round(floor / 250) * 250 : null,
            leak: Math.round(hedef * Number(r.ciro) - Number(r.kar)),
            maliyet_alti: taban > 0 && Number(r.avg_satis) < taban
          };
        });
        sendJson(response, 200, { marka, ebat, hedef, ay, desenler });
      } catch (e) { console.error("[marj-alarm-desen]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }

'''

s = s.replace(ANCHOR, BLK + ANCHOR, 1)
write(FP, s)
print("marjdesen: /api/bi/marj-alarm-desen eklendi")
print("marker count:", s.count("MARJDESEN_V1"))
print("DONE.")
