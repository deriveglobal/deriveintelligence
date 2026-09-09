# -*- coding: utf-8 -*-
# ZIYARET_CIRO_V1 (server) — /api/saha/rapor/ziyaret-ciro
#   Ziyaret edilen müşteriler → ERP cirosu (saha_musteri.musteri_kodu → bi_satis_faturalari).
#   rep: kendi ziyaret→ciro + eşleşmemiş kovası; yönetici: ekip matrisi (kapsam, ₺/ziyaret, dönüşüm, etki ₺).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "ZIYARET_CIRO_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCH = """      sendJson(response, 200, { rakipler: result.rows });
      return;
    }"""
assert s.count(ANCH) == 1, "anchor=%d" % s.count(ANCH)

NEW = ANCH + r"""

    if (method === "GET" && path === "/api/saha/rapor/ziyaret-ciro") {  /* ZIYARET_CIRO_V1 */
      const session = await requireSahaAccess(request);
      const from = url.searchParams.get("from") || "1900-01-01";
      const to   = url.searchParams.get("to")   || "2999-12-31";
      const tip  = url.searchParams.get("tip");
      const tipOk = tip && ["TUKETICI", "TICARI"].includes(tip);
      if (session.sahaRole === "rep") {
        const p = [session.tenantId, from, to, session.userId];
        let tipSql = "";
        if (tipOk) { p.push(tip); tipSql = ` AND m.tip=$${p.length}`; }
        const r = await query(`
          WITH vis AS (
            SELECT z.musteri_id, COUNT(*) ziyaret
              FROM saha_ziyaret z
             WHERE z.tenant_id=$1 AND z.durum='TAMAMLANDI' AND z.ziyaret_tarihi BETWEEN $2 AND $3 AND z.rep_id=$4
             GROUP BY z.musteri_id
          )
          SELECT m.id, m.firma, m.tip, m.musteri_kodu, v.ziyaret,
                 COALESCE((SELECT SUM(f.satir_tutar) FROM bi_satis_faturalari f
                            WHERE f.tenant_id::text=$1::text AND f.musteri_kodu=m.musteri_kodu
                              AND f.fatura_tarihi BETWEEN $2 AND $3),0)::numeric AS ciro
            FROM vis v JOIN saha_musteri m ON m.id=v.musteri_id
           WHERE 1=1${tipSql}
           ORDER BY ciro DESC, v.ziyaret DESC`, p);
        let ziyaret = 0, ciro = 0, eslesen = 0, alan = 0;
        for (const x of r.rows) { ziyaret += Number(x.ziyaret) || 0; ciro += Number(x.ciro) || 0; if (x.musteri_kodu) { eslesen++; if (Number(x.ciro) > 0) alan++; } }
        const benzersiz = r.rows.length;
        sendJson(response, 200, { rol: "rep", ozet: {
          ziyaret, benzersiz, eslesen, eslesmemis: benzersiz - eslesen, ciro,
          ciro_ziyaret: ziyaret ? Math.round(ciro / ziyaret) : 0,
          alan, donusum: eslesen ? Math.round(1000 * alan / eslesen) / 10 : null
        }, musteriler: r.rows });
        return;
      }
      // yönetici — ekip matrisi
      const p = [session.tenantId, from, to];
      let tipSql = "", portTip = "";
      if (tipOk) { p.push(tip); tipSql = ` AND m.tip=$${p.length}`; portTip = ` AND tip=$${p.length}`; }
      const r = await query(`
        WITH vis AS (
          SELECT z.rep_id, z.musteri_id, COUNT(*) ziyaret
            FROM saha_ziyaret z
           WHERE z.tenant_id=$1 AND z.durum='TAMAMLANDI' AND z.ziyaret_tarihi BETWEEN $2 AND $3
           GROUP BY z.rep_id, z.musteri_id
        ),
        enr AS (
          SELECT v.rep_id, v.ziyaret, m.musteri_kodu,
                 COALESCE((SELECT SUM(f.satir_tutar) FROM bi_satis_faturalari f
                            WHERE f.tenant_id::text=$1::text AND f.musteri_kodu=m.musteri_kodu
                              AND f.fatura_tarihi BETWEEN $2 AND $3),0)::numeric ciro
            FROM vis v JOIN saha_musteri m ON m.id=v.musteri_id
           WHERE 1=1${tipSql}
        ),
        port AS (
          SELECT sorumlu_rep rep_id, COUNT(*) portfoy FROM saha_musteri
           WHERE tenant_id=$1 AND aktif=true${portTip} GROUP BY sorumlu_rep
        )
        SELECT COALESCE(u.full_name, u.email, 'Bilinmiyor') rep, e.rep_id,
               SUM(e.ziyaret)::int ziyaret, COUNT(*)::int benzersiz,
               COUNT(*) FILTER (WHERE e.musteri_kodu IS NOT NULL)::int eslesen,
               COUNT(*) FILTER (WHERE e.ciro>0)::int alan,
               SUM(e.ciro)::numeric ciro, MAX(pt.portfoy)::int portfoy
          FROM enr e LEFT JOIN users u ON u.id=e.rep_id LEFT JOIN port pt ON pt.rep_id=e.rep_id
         GROUP BY e.rep_id, u.full_name, u.email
         ORDER BY ciro DESC NULLS LAST`, p);
      const repler = r.rows.map((x) => {
        const ziyaret = Number(x.ziyaret) || 0, ciro = Number(x.ciro) || 0, benzersiz = Number(x.benzersiz) || 0, eslesen = Number(x.eslesen) || 0, alan = Number(x.alan) || 0, portfoy = Number(x.portfoy) || 0;
        return { rep: x.rep, rep_id: x.rep_id, ziyaret, benzersiz, eslesen, ciro,
                 kapsam: portfoy ? Math.round(1000 * benzersiz / portfoy) / 10 : null,
                 ciro_ziyaret: ziyaret ? Math.round(ciro / ziyaret) : 0,
                 donusum: eslesen ? Math.round(1000 * alan / eslesen) / 10 : null };
      });
      sendJson(response, 200, { rol: "yonetici", repler });
      return;
    }"""

s = s.replace(ANCH, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] ZIYARET_CIRO_V1 (server)")
