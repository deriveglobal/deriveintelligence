# -*- coding: utf-8 -*-
# YORUM_BACKFILL_V1 — gecmis ziyaret yorumlari icin sahiplere TEK SEFERLIK toplu bildirim (secret'li).
#   Rep basina TEK push (yorum basina degil), en son yorumlanan ziyarete deep-link.
#   GET/POST /api/saha/yorum-backfill?key=SECRET&who=bilen[&days=N][&dry=1|&force=1]
#   dry (varsayilan) = plani doner, GONDERMEZ. force=1 = gonderir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YORUM_BACKFILL_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = """      sendJson(response, 405, { error: "yalnizca GET/POST" });
      return;
    }"""

NEW = OLD + r"""

    // YORUM_BACKFILL_V1 — gecmis yorumlar icin sahiplere tek seferlik toplu bildirim (secret'li).
    if ((method === "GET" || method === "POST") && path === "/api/saha/yorum-backfill") {
      let secret = "";
      try { secret = url.searchParams.get("key") || request.headers["x-ozet-secret"] || ""; } catch (e) {}
      let ok = false;
      try { const _s = await pool.query("SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'"); ok = !!(_s.rows[0] && _s.rows[0].value && _s.rows[0].value === secret); } catch (e) {}
      if (!ok) { sendJson(response, 403, { error: "forbidden" }); return; }
      const who = (url.searchParams.get("who") || "bilen").trim();
      const days = parseInt(url.searchParams.get("days") || "0", 10) || 0;
      const force = url.searchParams.get("force") === "1";
      try {
        const cu = await pool.query("SELECT id, full_name FROM users WHERE full_name ILIKE $1 OR email ILIKE $1", ["%" + who + "%"]);
        const cids = cu.rows.map(function (x) { return x.id; });
        if (!cids.length) { sendJson(response, 200, { ok: true, eslesen: 0, mesaj: "kullanici bulunamadi: " + who }); return; }
        const cname = cu.rows.length === 1 ? cu.rows[0].full_name : "Yönetim";
        const params = [cids];
        let dayF = "";
        if (days > 0) { params.push(days); dayF = " AND y.created_at >= now() - ($2 * INTERVAL '1 day')"; }
        const plan = await pool.query(
          "SELECT z.rep_id, u.full_name rep, count(DISTINCT y.ziyaret_id)::int ziyaret, (array_agg(y.ziyaret_id ORDER BY y.created_at DESC))[1] son_zid" +
          " FROM saha_ziyaret_yorum y JOIN saha_ziyaret z ON z.id=y.ziyaret_id LEFT JOIN users u ON u.id=z.rep_id" +
          " WHERE y.user_id = ANY($1::uuid[]) AND z.rep_id IS NOT NULL AND z.rep_id <> ALL($1::uuid[])" + dayF +
          " GROUP BY z.rep_id, u.full_name ORDER BY ziyaret DESC", params);
        const plani = plan.rows.map(function (r) { return { rep: r.rep, rep_id: r.rep_id, ziyaret: r.ziyaret, son_zid: r.son_zid }; });
        if (!force) { sendJson(response, 200, { ok: true, dry: true, commenter: cname, hedef_rep: plani.length, toplam_ziyaret: plani.reduce(function (a, b) { return a + b.ziyaret; }, 0), plan: plani }); return; }
        let gonderilen = 0;
        for (const r of plan.rows) {
          try {
            const trow = await pool.query("SELECT tenant_id FROM saha_ziyaret WHERE id=$1", [r.son_zid]);
            const T = trow.rows[0] && trow.rows[0].tenant_id; if (!T) continue;
            const n = r.ziyaret;
            const body = cname + ", " + n + " ziyaretinize yorum bıraktı" + (n > 1 ? " — açıp görün." : ".");
            await pushToUsers(T, [r.rep_id], "💬 Ziyaret yorumları", body, { room: "saha", type: "ziyaret", id: r.son_zid });
            gonderilen++;
          } catch (e) {}
        }
        sendJson(response, 200, { ok: true, commenter: cname, gonderilen: gonderilen, hedef: plani.length });
      } catch (e) { sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }"""

assert s.count(OLD) == 1, "anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YORUM_BACKFILL_V1 (server)")
