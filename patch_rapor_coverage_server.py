# -*- coding: utf-8 -*-
# RAPOR_COVERAGE_V1 (server) — /api/saha/rapor/ozet yanitina portfoy (kapsam paydasi) ekle.
#   portfoy = tenant'taki musteri sayisi (segment=tip + rep ise kendi sorumlu_rep musterileri).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RAPOR_COVERAGE_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = "      sendJson(response, 200, { ozet: result.rows[0], gunluk: gunluk.rows });"
NEW = """      let portfoy = 0;  /* RAPOR_COVERAGE_V1: kapsam paydasi */
      try {
        let pfSql = `SELECT count(*)::int AS n FROM saha_musteri m WHERE m.tenant_id=$1`;
        const pfP = [session.tenantId];
        if (tip) { pfP.push(tip); pfSql += ` AND m.tip=$${pfP.length}`; }
        if (session.sahaRole === "rep") { pfP.push(session.userId); pfSql += ` AND m.sorumlu_rep=$${pfP.length}`; }
        portfoy = (await query(pfSql, pfP)).rows[0].n;
      } catch (e) {}
      sendJson(response, 200, { ozet: { ...result.rows[0], portfoy }, gunluk: gunluk.rows });"""
assert s.count(OLD) == 1, "sendjson anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_COVERAGE_V1")
