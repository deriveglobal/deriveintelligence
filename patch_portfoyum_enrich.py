# -*- coding: utf-8 -*-
# PORTFOYUM_ENRICH_V1 — /api/saha/portfoyum: tam-SKU ürün karması + aylık trend + ERP eşleşmeyen
#   3 ek sorgu (saf SQL, try/catch ile zarif düşer) + musteri.ebatlar + top-level trend/eslesmeyen.
#   SKU = kalem_tanimi (sondaki AB-etiketi kırpılmış), gruplama kalem_kodu. Backslash yok (POSIX).
# Idempotent (MARK), .enrichbak yedekli. Fatih: python3 patch_portfoyum_enrich.py <dizin>
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
REL  = "server_container.mjs"
MARK = "PORTFOYUM_ENRICH_V1"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit

# 1) 3 zenginleştirme sorgusu — byKod satırından sonra (musteriler map'inden ÖNCE)
A_Q = "const byKod = {}; for (const r of perR.rows) byKod[r.musteri_kodu] = r;"
N_Q = A_Q + """
      /* PORTFOYUM_ENRICH_V1 — tam-SKU karma + trend + ERP eşleşmeyen (saf SQL, zarif düşer) */
      const ebatByKod = {}; let _pfTrend = [], _pfEslesmeyen = [];
      try {
        const pC = [T]; const scopeC = _sahaScopeSql(session, pC, "m");
        const skuR = await query(`
          WITH mine AS (SELECT DISTINCT m.musteri_kodu FROM saha_musteri m
            WHERE m.tenant_id=$1 AND m.aktif=true AND COALESCE(m.musteri_kodu,'')<>''` + scopeC + `),
          g AS (SELECT f.musteri_kodu, f.kalem_kodu,
                  max(regexp_replace(f.kalem_tanimi,'[[:space:]]+[A-Da-d]-[A-Da-d]-[0-9]+[dD][bB][[:space:]]*$','')) AS sku,
                  sum(f.miktar) AS adet
                FROM bi_satis_faturalari f JOIN mine ON mine.musteri_kodu=f.musteri_kodu
                WHERE f.tenant_id=$1::text AND f.satir_tutar>0 AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '24 months' AND COALESCE(f.kalem_kodu,'')<>''
                GROUP BY f.musteri_kodu, f.kalem_kodu),
          r AS (SELECT *, row_number() OVER (PARTITION BY musteri_kodu ORDER BY adet DESC) rn FROM g)
          SELECT musteri_kodu, sku, round(adet)::int AS adet FROM r WHERE rn<=15 ORDER BY musteri_kodu, adet DESC`, pC);
        for (const r of skuR.rows) { (ebatByKod[r.musteri_kodu] = ebatByKod[r.musteri_kodu] || []).push({ ebat: r.sku, adet: r.adet }); }
      } catch (e) {}
      try {
        const pD = [T]; const scopeD = _sahaScopeSql(session, pD, "m");
        const trR = await query(`
          WITH mine AS (SELECT DISTINCT m.musteri_kodu FROM saha_musteri m
            WHERE m.tenant_id=$1 AND m.aktif=true AND COALESCE(m.musteri_kodu,'')<>''` + scopeD + `)
          SELECT to_char(date_trunc('month',f.fatura_tarihi),'YYYY-MM') AS ay,
                 round(SUM(f.satir_tutar))::bigint AS ciro, round(SUM(f.miktar))::int AS adet
          FROM bi_satis_faturalari f JOIN mine ON mine.musteri_kodu=f.musteri_kodu
          WHERE f.tenant_id=$1::text AND f.satir_tutar>0 AND f.fatura_tarihi>=date_trunc('month',CURRENT_DATE)-INTERVAL '35 months'
          GROUP BY 1 ORDER BY 1`, pD);
        _pfTrend = trR.rows.map(r => ({ ay: r.ay, ciro: Number(r.ciro) || 0, adet: Number(r.adet) || 0 }));
      } catch (e) {}
      try {
        const pE = [T]; const scopeE = _sahaScopeSql(session, pE, "m");
        const esR = await query(`SELECT m.firma, m.il FROM saha_musteri m
          WHERE m.tenant_id=$1 AND m.aktif=true AND COALESCE(m.musteri_kodu,'')=''` + scopeE + `
          ORDER BY m.firma LIMIT 100`, pE);
        _pfEslesmeyen = esR.rows.map(r => ({ firma: r.firma, il: r.il }));
      } catch (e) {}"""
assert orig.count(A_Q) == 1, "Q anchor=%d" % orig.count(A_Q)

# 2) musteri map'e ebatlar ekle
A_MAP = "agirlikli_vade: cv>0?Math.round(vx/cv):null, pesin_pct: c12>0?Math.round(100*pc/c12):null,"
N_MAP = A_MAP + " ebatlar: ebatByKod[b.musteri_kodu]||null,"
assert orig.count(A_MAP) == 1, "MAP anchor=%d" % orig.count(A_MAP)

# 3) sendJson'a trend + eslesmeyen ekle
A_SEND = 'sendJson(response, 200, { rep:{ id:session.userId, ad:session.name||"" }, ozet, musteriler });'
N_SEND = 'sendJson(response, 200, { rep:{ id:session.userId, ad:session.name||"" }, ozet, musteriler, trend:_pfTrend, eslesmeyen:_pfEslesmeyen }); /* PORTFOYUM_ENRICH_V1 */'
assert orig.count(A_SEND) == 1, "SEND anchor=%d" % orig.count(A_SEND)

s = orig.replace(A_Q, N_Q, 1).replace(A_MAP, N_MAP, 1).replace(A_SEND, N_SEND, 1)
if not os.path.exists(path + ".enrichbak"):
    with io.open(path + ".enrichbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| MARK:", s.count(MARK))
