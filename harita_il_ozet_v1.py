#!/usr/bin/env python3
# HARITA_IL_OZET_V1 — sehir (il) bazinda 6 metrik. GET /api/saha/harita-il-ozet?il=<il>
#   -> musteri, ziyaret, satis adet/ciro (12ay), teklif win/loss. Sehir AI = mevcut saha-sesi?kapsam=sehir.
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_IL_OZET_V1" in s:
    print("il-ozet: already present, skip"); print("DONE."); raise SystemExit

A = '    if (method === "GET" && path === "/api/saha/harita-musteri-brief") { /* HARITA_BRIEF_V1 */\n'
assert s.count(A) == 1, "harita-musteri-brief anchor (count!=1)"

N = (
    '    if (method === "GET" && path === "/api/saha/harita-il-ozet") { /* HARITA_IL_OZET_V1 */\n'
    '      const session = await requireSahaAccess(request, ["manager","admin"]);\n'
    '      const il = (new URL(request.url, "http://x").searchParams.get("il") || "").trim();\n'
    '      if (!il) { sendJson(response, 400, { error: "il zorunlu" }); return; }\n'
    '      const zi = (await query("SELECT COUNT(*) FILTER (WHERE z.durum=\'TAMAMLANDI\')::int ziyaret, COUNT(DISTINCT sm.id)::int musteri FROM saha_musteri sm LEFT JOIN saha_ziyaret z ON z.musteri_id=sm.id AND z.tenant_id=sm.tenant_id WHERE sm.tenant_id=$1 AND sm.il=$2 AND sm.aktif=true", [session.tenantId, il])).rows[0];\n'
    '      const tk = (await query("SELECT COUNT(*)::int toplam, COUNT(*) FILTER (WHERE t.durum=\'KAZANILDI\')::int kazan, COUNT(*) FILTER (WHERE t.durum=\'KAYBEDILDI\')::int kayip FROM saha_teklif t JOIN saha_musteri sm ON sm.id=t.musteri_id WHERE t.tenant_id=$1 AND sm.il=$2", [session.tenantId, il])).rows[0];\n'
    '      let satisAdet = 0, satisCiro = 0;\n'
    '      try {\n'
    '        const sr = (await query("SELECT COALESCE(SUM(miktar),0)::numeric adet, COALESCE(SUM(satir_tutar),0)::numeric ciro FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir ILIKE $2 AND fatura_tarihi >= (CURRENT_DATE - INTERVAL \'12 months\')", [session.tenantId, il])).rows[0];\n'
    '        satisAdet = Number(sr.adet); satisCiro = Number(sr.ciro);\n'
    '      } catch (e) { console.error("[il-ozet satis]", e && e.message); }\n'
    '      sendJson(response, 200, { il, musteri: Number(zi.musteri||0), ziyaret: Number(zi.ziyaret||0), teklif: Number(tk.toplam||0), kazan: Number(tk.kazan||0), kayip: Number(tk.kayip||0), satis_adet: satisAdet, satis_ciro: satisCiro });\n'
    '      return;\n'
    '    }\n\n'
)
s = s.replace(A, N + A, 1)
write(FP, s)
print("il-ozet: /api/saha/harita-il-ozet eklendi")
print("marker count:", s.count("HARITA_IL_OZET_V1"))
print("DONE.")
