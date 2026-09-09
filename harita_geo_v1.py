#!/usr/bin/env python3
# HARITA_GEO_V1 (Faz 4a) — il choropleth altyapisi:
#   GET /api/saha/tr-geo            -> Turkiye il sinirlari GeoJSON (/app/tr-cities.json okur; compose ile mount).
#   GET /api/saha/harita-il-metrikler?from=&to= -> TUM iller icin ciro/adet (donem) + gecikme_orani (anlik snapshot)
#                                       + krb_gecikme_orani. Choropleth renklendirme icin.
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_GEO_V1" in s:
    print("harita-geo: already present, skip"); print("DONE."); raise SystemExit

A = '    if (method === "GET" && path === "/api/saha/harita-il-ozet") { /* HARITA_IL_OZET_V1 */\n'
assert s.count(A) == 1, "harita-il-ozet anchor (count!=1)"

N = (
    '    if (method === "GET" && path === "/api/saha/tr-geo") { /* HARITA_GEO_V1 */\n'
    '      await requireSahaAccess(request, ["rep","manager","admin"]);\n'
    '      try {\n'
    '        const geo = await readFile("/app/tr-cities.json", "utf8");\n'
    '        response.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "max-age=86400", ...HTML_SECURITY_HEADERS });\n'
    '        response.end(geo);\n'
    '      } catch (e) { sendJson(response, 404, { error: "il haritasi bulunamadi (tr-cities.json mount edilmemis olabilir)" }); }\n'
    '      return;\n'
    '    }\n\n'
    '    if (method === "GET" && path === "/api/saha/harita-il-metrikler") { /* HARITA_GEO_V1 */\n'
    '      const session = await requireSahaAccess(request, ["manager","admin"]);\n'
    '      const gsp = new URL(request.url, "http://x").searchParams;\n'
    '      const gFrom = gsp.get("from") || null, gTo = gsp.get("to") || null;\n'
    '      const T = session.tenantId;\n'
    '      let iller = [], krb = null;\n'
    '      try {\n'
    '        const r = await query(\n'
    '          "WITH cs AS (SELECT musteri_kodu, MAX(sehir) sehir FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir IS NOT NULL AND sehir<>\'\' GROUP BY musteri_kodu),"\n'
    '          + " risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(hesap_bakiyesi,0) bakiye, COALESCE(vadesi_gecmis,0) overdue FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi ORDER BY muhatap_kodu, export_date DESC),"\n'
    '          + " il_risk AS (SELECT cs.sehir il, SUM(GREATEST(r.overdue,0)) overdue, SUM(GREATEST(r.bakiye,0)) bakiye FROM risk r JOIN cs ON cs.musteri_kodu=r.muhatap_kodu GROUP BY cs.sehir),"\n'
    '          + " il_satis AS (SELECT sehir il, SUM(satir_tutar) ciro, SUM(miktar) adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir IS NOT NULL AND sehir<>\'\' AND ($2::date IS NULL OR fatura_tarihi BETWEEN $2 AND $3) GROUP BY sehir)"\n'
    '          + " SELECT COALESCE(s.il, k.il) il, COALESCE(s.ciro,0)::numeric ciro, COALESCE(s.adet,0)::numeric adet,"\n'
    '          + " k.overdue, k.bakiye, CASE WHEN COALESCE(k.bakiye,0)>0 THEN (k.overdue/k.bakiye)::numeric ELSE NULL END gecikme_orani"\n'
    '          + " FROM il_satis s FULL JOIN il_risk k ON k.il=s.il WHERE COALESCE(s.il,k.il) IS NOT NULL", [T, gFrom, gTo]);\n'
    '        iller = r.rows.map(x => ({ il: x.il, ciro: Number(x.ciro||0), adet: Number(x.adet||0), gecikme_orani: x.gecikme_orani != null ? Number(x.gecikme_orani) : null }));\n'
    '        const kr = await query("SELECT SUM(GREATEST(COALESCE(vadesi_gecmis,0),0)) overdue, SUM(GREATEST(COALESCE(hesap_bakiyesi,0),0)) bakiye FROM (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, vadesi_gecmis FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi ORDER BY muhatap_kodu, export_date DESC) z", [T]);\n'
    '        const kb = Number(kr.rows[0] && kr.rows[0].bakiye || 0), ko = Number(kr.rows[0] && kr.rows[0].overdue || 0);\n'
    '        krb = kb > 0 ? ko / kb : null;\n'
    '      } catch (e) { console.error("[il-metrikler]", e && e.message); sendJson(response, 500, { error: "metrik alinamadi" }); return; }\n'
    '      sendJson(response, 200, { krb_gecikme_orani: krb, iller });\n'
    '      return;\n'
    '    }\n\n'
)
s = s.replace(A, N + A, 1)
write(FP, s)
print("harita-geo: /api/saha/tr-geo + /api/saha/harita-il-metrikler eklendi")
print("marker count:", s.count("HARITA_GEO_V1"))
print("DONE.")
