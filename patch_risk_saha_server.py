# -*- coding: utf-8 -*-
# RISK_SAHA_V1 (server) — GET /api/saha/rapor/risk-saha
#   Gecikmiş alacak (bi_musteri_risk.vadesi_gecmis, FIFO) × ziyaret güncelliği.
#   saha_musteri.musteri_kodu = bi_musteri_risk.muhatap_kodu; son ziyaret = en son TAMAMLANDI.
#   yönetici: tüm eşleşmiş+gecikmiş müşteriler; rep: kendi sorumlu müşterileri. Rep alanı = saha_tip.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RISK_SAHA_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCH = """      sendJson(response, 200, { rol: "yonetici", repler });
      return;
    }"""
assert s.count(ANCH) == 1, "anchor=%d" % s.count(ANCH)

NEW = ANCH + r"""

    if (method === "GET" && path === "/api/saha/rapor/risk-saha") {  /* RISK_SAHA_V1 */
      const session = await requireSahaAccess(request);
      const tip = url.searchParams.get("tip");
      const tipOk = tip && ["TUKETICI", "TICARI"].includes(tip);
      const p = [session.tenantId];
      let tipSql = "";
      if (tipOk) { p.push(tip); tipSql = ` AND m.tip=$${p.length}`; }
      let repSql = "";
      if (session.sahaRole === "rep") { p.push(session.userId); repSql = ` AND m.sorumlu_rep=$${p.length}`; }
      const r = await query(`
        WITH risk AS (
          SELECT muhatap_kodu,
                 MAX(vadesi_gecmis)::numeric AS vadesi_gecmis,
                 MAX(COALESCE(limit_asimi, 0))::numeric AS limit_asimi
            FROM bi_musteri_risk
           WHERE tenant_id::text = $1::text AND COALESCE(musteri_mi, true) = true AND vadesi_gecmis > 0
           GROUP BY muhatap_kodu
        )
        SELECT m.id, m.firma, m.tip, m.musteri_kodu,
               rk.vadesi_gecmis AS overdue,
               (rk.limit_asimi > 0) AS limit_asan,
               COALESCE(u.full_name, u.email, 'Atanmamış') AS rep, m.sorumlu_rep AS rep_id,
               (SELECT tum.permissions_json->>'saha_tip' FROM tenant_user_modules tum
                  WHERE tum.user_id = m.sorumlu_rep AND tum.tenant_id = m.tenant_id AND tum.module_id = 'saha' LIMIT 1) AS saha_tip,
               (SELECT MAX(z.ziyaret_tarihi) FROM saha_ziyaret z
                  WHERE z.tenant_id = m.tenant_id AND z.musteri_id = m.id AND z.durum = 'TAMAMLANDI') AS son_ziyaret
          FROM saha_musteri m
          JOIN risk rk ON rk.muhatap_kodu = m.musteri_kodu
          LEFT JOIN users u ON u.id = m.sorumlu_rep
         WHERE m.tenant_id = $1 AND m.aktif = true AND m.musteri_kodu IS NOT NULL${tipSql}${repSql}
         ORDER BY rk.vadesi_gecmis DESC`, p);
      const now = Date.now();
      const musteriler = r.rows.map((x) => {
        let gun = null;
        if (x.son_ziyaret) { const dd = new Date(x.son_ziyaret); if (!isNaN(dd)) gun = Math.max(0, Math.floor((now - dd.getTime()) / 86400000)); }
        return { id: x.id, firma: x.firma, tip: x.tip, musteri_kodu: x.musteri_kodu,
                 overdue: Number(x.overdue) || 0, limit: x.limit_asan ? 1 : 0,
                 rep: x.rep, rep_id: x.rep_id, saha_tip: x.saha_tip, gun };
      });
      sendJson(response, 200, { rol: session.sahaRole === "rep" ? "rep" : "yonetici", musteriler });
      return;
    }"""

s = s.replace(ANCH, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] RISK_SAHA_V1 (server)")
