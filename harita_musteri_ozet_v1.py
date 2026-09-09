#!/usr/bin/env python3
# HARITA_MUSTERI_OZET_V1 — pin balonu icin tek musteri metrikleri.
#   GET /api/saha/harita-musteri-ozet?id=<saha_musteri_id> -> ziyaret, teklif(win/loss), satis adet/ciro (12ay), musteri_kodu.
#   Puan ayrica /api/bi/musteri-skor?musteri=<kodu> ile cekilir (frontend).
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_MUSTERI_OZET_V1" in s:
    print("ozet-ep: already present, skip"); print("DONE."); raise SystemExit

A = '    if (method === "GET" && path === "/api/saha/harita-musteriler") { /* HARITA_MUSTERI_V1 */\n'
assert s.count(A) == 1, "harita-musteriler anchor (count!=1)"

N = (
    '    if (method === "GET" && path === "/api/saha/harita-musteri-ozet") { /* HARITA_MUSTERI_OZET_V1 */\n'
    '      const session = await requireSahaAccess(request, ["rep","manager","admin"]);\n'
    '      const osp = new URL(request.url, "http://x").searchParams;\n'
    '      const oid = osp.get("id") || "";\n'
    '      if (!oid) { sendJson(response, 400, { error: "id zorunlu" }); return; }\n'
    '      const mrow = (await query("SELECT firma, musteri_kodu FROM saha_musteri WHERE tenant_id=$1 AND id=$2", [session.tenantId, oid])).rows[0];\n'
    '      if (!mrow) { sendJson(response, 404, { error: "musteri yok" }); return; }\n'
    '      const kod = mrow.musteri_kodu || null;\n'
    '      const zi = (await query("SELECT COUNT(*)::int n, MAX(ziyaret_tarihi)::text son FROM saha_ziyaret WHERE tenant_id=$1 AND musteri_id=$2 AND durum=\'TAMAMLANDI\'", [session.tenantId, oid])).rows[0];\n'
    '      const tk = (await query("SELECT COUNT(*)::int toplam, COUNT(*) FILTER (WHERE durum=\'KAZANILDI\')::int kazan, COUNT(*) FILTER (WHERE durum=\'KAYBEDILDI\')::int kayip FROM saha_teklif WHERE tenant_id=$1 AND musteri_id=$2", [session.tenantId, oid])).rows[0];\n'
    '      let satisAdet = 0, satisCiro = 0;\n'
    '      if (kod) {\n'
    '        try {\n'
    '          const sr = (await query("SELECT COALESCE(SUM(miktar),0)::numeric adet, COALESCE(SUM(satir_tutar),0)::numeric ciro FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND musteri_kodu=$2 AND fatura_tarihi >= (CURRENT_DATE - INTERVAL \'12 months\')", [session.tenantId, kod])).rows[0];\n'
    '          satisAdet = Number(sr.adet); satisCiro = Number(sr.ciro);\n'
    '        } catch (e) { console.error("[harita-ozet satis]", e && e.message); }\n'
    '      }\n'
    '      sendJson(response, 200, { firma: mrow.firma, musteri_kodu: kod, ziyaret: Number(zi.n||0), son_ziyaret: zi.son || null, teklif: Number(tk.toplam||0), kazan: Number(tk.kazan||0), kayip: Number(tk.kayip||0), satis_adet: satisAdet, satis_ciro: satisCiro });\n'
    '      return;\n'
    '    }\n\n'
)
s = s.replace(A, N + A, 1)
write(FP, s)
print("ozet-ep: /api/saha/harita-musteri-ozet eklendi")
print("marker count:", s.count("HARITA_MUSTERI_OZET_V1"))
print("DONE.")
