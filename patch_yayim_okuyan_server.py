# -*- coding: utf-8 -*-
# YAYIM_OKUYAN_V1 (server) — POST /api/saha/yayim-okuyanlar {icerik}
#   -> { okuyanlar:[{ad,okundu_at}], okumayanlar:[ad] } (bu Hızlı Duyuruyu kim gördü / görmedi).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YAYIM_OKUYAN_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCH = "    // POST /api/saha/konusmalar/:konusmaId — mesaj gönder"
ENDPOINT = """    // ══ YAYIM OKUYANLAR — YAYIM_OKUYAN_V1 ══
    if (method === "POST" && path === "/api/saha/yayim-okuyanlar") {
      const session = await requireSahaAccess(request, ["manager","admin"]);
      const body = await readJson(request);
      const icerik = body && body.icerik;
      if (!icerik) { sendJson(response, 400, { error: "icerik zorunlu" }); return; }
      const tid = session.tenantId;
      const okur = await pool.query(`
        SELECT DISTINCT u.id, COALESCE(u.full_name, u.email) AS ad, o.son_okunan_at
          FROM saha_konusma k
          JOIN saha_konusma_mesaj m ON m.konusma_id=k.id
          JOIN saha_konusma_okundu o ON o.konusma_id=k.id AND o.user_id=k.rep_id
          JOIN users u ON u.id=k.rep_id
         WHERE k.tenant_id=$1 AND k.tip='YAYIM' AND m.icerik=$2 AND o.son_okunan_at >= m.created_at
         ORDER BY o.son_okunan_at`, [tid, icerik]);
      const okuyanIds = okur.rows.map(function (r) { return r.id; });
      const okuyanlar = okur.rows.map(function (r) { return { ad: r.ad, okundu_at: r.son_okunan_at }; });
      const tumRep = await pool.query(`SELECT u.id, COALESCE(u.full_name, u.email) AS ad FROM users u JOIN tenant_user_modules um ON um.user_id=u.id AND um.module_id='saha' AND um.tenant_id=$1 AND um.active=true AND um.module_role='rep' WHERE u.status <> 'disabled' ORDER BY ad`, [tid]);
      const okumayanlar = tumRep.rows.filter(function (r) { return okuyanIds.indexOf(r.id) === -1; }).map(function (r) { return r.ad; });
      sendJson(response, 200, { okuyanlar, okumayanlar });
      return;
    }

"""
assert s.count(ANCH) == 1, "anchor=%d" % s.count(ANCH)
s = s.replace(ANCH, ENDPOINT + ANCH, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_OKUYAN_V1")
