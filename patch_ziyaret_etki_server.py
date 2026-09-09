# -*- coding: utf-8 -*-
# ZIYARET_ETKI_V1 (server) — GET /api/saha/rapor/ziyaret-etki
#   PIVOT (retention): KRB'de kapsam ~%98 → "ziyaret vs ziyaretsiz" kontrol grubu YOK.
#   Bunun yerine: ZIYARET SIKLIGI (son 12 ay) -> TEKRAR-ALIM (H1 alan musterinin H2'de de almasi).
#   Robust metrik (tutara duyarsiz). Ciro buyumesi dagitik/konsantre oldugu icin manset DEGIL.
#   Manager/admin. Eslesme saha_musteri.musteri_kodu -> bi_satis_faturalari, ::text.
#   UPSERT: temiz dosyada ekler, endpoint zaten varsa DEGISTIRIR (yeniden calistirilabilir).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()

# 1) SAHA_DEPT_MAP (guard — zaten olabilir)
if '"/api/saha/rapor/ziyaret-etki"' not in s:
    o1 = '    "/api/saha/rapor/rep-performans": ["rapor"],'
    assert s.count(o1) == 1, "dept-map anchor=%d" % s.count(o1)
    s = s.replace(o1, o1 + '\n    "/api/saha/rapor/ziyaret-etki": ["rapor"],  /* ZIYARET_ETKI_V1 */', 1)

NEWEP = r'''    if (method === "GET" && path === "/api/saha/rapor/ziyaret-etki") {  /* ZIYARET_ETKI_V1 */
      const session = await requireSahaAccess(request);   /* rep + yonetici */
      const tid = session.tenantId, uid = session.userId, rol = session.sahaRole;
      const _tip = url.searchParams.get("tip");
      const tipOk = _tip === "TUKETICI" || _tip === "TICARI";
      // Anchor = en son fatura tarihi (donuk ERP feed'i notrler).
      const anc = await query(`SELECT MAX(fatura_tarihi)::date d FROM bi_satis_faturalari WHERE tenant_id::text=$1::text`, [tid]);
      const veriSonu = (anc.rows[0] && anc.rows[0].d) ? new Date(anc.rows[0].d) : new Date();
      const dstr = (dt) => new Date(dt).toISOString().slice(0, 10);
      const shift = (dt, days) => { const dd = new Date(dt); dd.setUTCDate(dd.getUTCDate() + days); return dd; };
      const d0 = veriSonu;                    // veri sonu
      const h2Start = shift(d0, -179);        // H2 (son) = [h2Start, d0]
      const h1Start = shift(d0, -359);        // H1 (onceki) = [h1Start, h2Start)
      const yilStart = shift(d0, -364);       // ziyaret sikligi: son ~12 ay
      const p = [tid, dstr(h1Start), dstr(h2Start), dstr(d0), dstr(yilStart)];
      let tipF = "";
      if (tipOk) { p.push(_tip); tipF = ` AND m.tip=$${p.length}`; }
      let repF = "";
      if (rol === "rep") { p.push(uid); repF = ` AND m.sorumlu_rep::text=$${p.length}::text`; }
      const r = await query(`
        WITH cust AS (
          SELECT m.id, m.musteri_kodu FROM saha_musteri m
           WHERE m.tenant_id::text=$1::text AND m.aktif=true AND m.musteri_kodu IS NOT NULL${tipF}${repF}
        ),
        h1 AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric v FROM bi_satis_faturalari
               WHERE tenant_id::text=$1::text AND fatura_tarihi >= $2 AND fatura_tarihi < $3 GROUP BY musteri_kodu),
        h2 AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric v FROM bi_satis_faturalari
               WHERE tenant_id::text=$1::text AND fatura_tarihi >= $3 AND fatura_tarihi <= $4 GROUP BY musteri_kodu),
        vis AS (SELECT musteri_id, COUNT(*) c FROM saha_ziyaret
                WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' AND ziyaret_tarihi >= $5 GROUP BY musteri_id),
        vev AS (SELECT DISTINCT musteri_id FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI')
        SELECT c.id::text id, COALESCE(h1.v,0)::numeric h1, COALESCE(h2.v,0)::numeric h2,
               COALESCE(vis.c,0)::int vc, (vev.musteri_id IS NOT NULL) ever
          FROM cust c
          LEFT JOIN h1 ON h1.musteri_kodu=c.musteri_kodu
          LEFT JOIN h2 ON h2.musteri_kodu=c.musteri_kodu
          LEFT JOIN vis ON vis.musteri_id=c.id
          LEFT JOIN vev ON vev.musteri_id=c.id`, p);
      const rows = r.rows.map((x) => ({ h1: Number(x.h1) || 0, h2: Number(x.h2) || 0, vc: Number(x.vc) || 0, ever: !!x.ever }));
      const matched = rows.length;
      const ziyaretEdilmis = rows.filter((x) => x.ever).length;
      const bucketOf = (vc) => vc === 0 ? 0 : vc <= 3 ? 1 : vc <= 8 ? 2 : 3;
      const defs = [
        { etiket: "Hiç ziyaret", aralik: "0" },
        { etiket: "Seyrek", aralik: "1–3" },
        { etiket: "Orta", aralik: "4–8" },
        { etiket: "Sık", aralik: "9+" }
      ];
      const r1 = (n) => Math.round(n * 10) / 10;
      const gruplar = defs.map((dfn, i) => {
        const grp = rows.filter((x) => bucketOf(x.vc) === i);
        const taban = grp.filter((x) => x.h1 > 0);
        const geri = taban.filter((x) => x.h2 > 0).length;
        const ortCiro = taban.length ? Math.round(taban.reduce((a, x) => a + x.h1, 0) / taban.length) : 0;
        return { i, etiket: dfn.etiket, aralik: dfn.aralik, n: grp.length, taban: taban.length,
                 geri, retention: taban.length ? r1(100 * geri / taban.length) : null, ort_ciro: ortCiro };
      });
      const allTaban = rows.filter((x) => x.h1 > 0);
      const allGeri = allTaban.filter((x) => x.h2 > 0).length;
      const ihmal = gruplar[0];  // hiç ziyaret cebi
      sendJson(response, 200, {
        rol: rol === "rep" ? "rep" : "yonetici",
        donem: {
          veri_sonu: dstr(d0),
          yil: [dstr(yilStart), dstr(d0)],
          h1: [dstr(h1Start), dstr(shift(h2Start, -1))],
          h2: [dstr(h2Start), dstr(d0)]
        },
        kapsam: { matched, ziyaret_edilmis: ziyaretEdilmis, pct: matched ? r1(100 * ziyaretEdilmis / matched) : 0 },
        ozet: {
          genel_retention: allTaban.length ? r1(100 * allGeri / allTaban.length) : null,
          taban_toplam: allTaban.length,
          ihmal_n: ihmal.n, ihmal_retention: ihmal.retention, ihmal_ort_ciro: ihmal.ort_ciro
        },
        gruplar
      });
      return;
    }

'''

REP = '    if (method === "GET" && path === "/api/saha/rapor/rep-performans") {'
if 'path === "/api/saha/rapor/ziyaret-etki"' in s:            # zaten var → endpoint'i DEGISTIR
    a = s.index('    if (method === "GET" && path === "/api/saha/rapor/ziyaret-etki")')
    b = s.index(REP, a)
    s = s[:a] + NEWEP + s[b:]
else:                                                         # temiz → rep-performans'tan once EKLE
    assert s.count(REP) == 1, "rep-performans anchor=%d" % s.count(REP)
    s = s.replace(REP, NEWEP + REP, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] ZIYARET_ETKI_V1 (server · retention pivot · upsert)")
