import sys
F=sys.argv[1] if len(sys.argv)>1 else "server_container.mjs"
s=open(F,encoding="utf-8").read()
if "REP_AKTIVITE_V1" in s: print("[skip] zaten var"); sys.exit(0)
ANCHOR='    // ══ LOG / HATA ═══════════════════════════════════════════════════════════'
assert s.count(ANCHOR)==1, "anchor sorunu: %d"%s.count(ANCHOR)
BLOCK=r'''    if (path === "/api/saha/aktivite-ping" || path === "/api/saha/rep-aktivite") { /* REP_AKTIVITE_V1 */
      try {
        const session = await requireSahaAccess(request);
        const T = session.tenantId, U = session.userId;
        if (!T || !U) { sendJson(response, 401, { error: "oturum yok" }); return; }
        await pool.query("CREATE TABLE IF NOT EXISTS saha_rep_aktivite (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL, user_id uuid NOT NULL, ts timestamptz NOT NULL DEFAULT now(), oda text, platform text)").catch(function(){});
        await pool.query("CREATE INDEX IF NOT EXISTS idx_rep_akt ON saha_rep_aktivite (tenant_id, user_id, ts DESC)").catch(function(){});
        // ---- PING: her rep kendi kalp atisi (40sn debounce) ----
        if (method === "POST" && path === "/api/saha/aktivite-ping") {
          let body = {}; try { body = await readJson(request); } catch (e) {}
          const oda = String(body.oda || "").slice(0, 40);
          const platform = String(body.platform || "").slice(0, 16);
          const son = await pool.query("SELECT ts FROM saha_rep_aktivite WHERE tenant_id=$1 AND user_id=$2 ORDER BY ts DESC LIMIT 1", [T, U]);
          const tooSoon = son.rows.length && (Date.now() - new Date(son.rows[0].ts).getTime() < 40000);
          if (!tooSoon) await pool.query("INSERT INTO saha_rep_aktivite (tenant_id,user_id,oda,platform) VALUES ($1,$2,$3,$4)", [T, U, oda || null, platform || null]);
          sendJson(response, 200, { ok: true });
          return;
        }
        // ---- RAPOR: yalniz yonetim@krb.com.tr ----
        if (method === "GET" && path === "/api/saha/rep-aktivite") {
          const who = await pool.query("SELECT lower(email::text) e FROM users WHERE id=$1", [U]);
          if (!who.rows.length || who.rows[0].e !== "yonetim@krb.com.tr") { sendJson(response, 403, { error: "Bu bölüm yalnız yönetime özeldir." }); return; }
          let gun = parseInt(url.searchParams.get("gun") || "7", 10);
          if (!Number.isFinite(gun) || gun < 1) gun = 7; if (gun > 90) gun = 90;
          const reps = (await pool.query(
            "SELECT u.id, COALESCE(u.full_name,u.name,u.email::text) ad, u.last_login_at, " +
            " (SELECT max(ts) FROM saha_rep_aktivite a WHERE a.user_id=u.id) son_aktivite, " +
            " (SELECT count(DISTINCT date_trunc('minute',ts)) FROM saha_rep_aktivite a WHERE a.user_id=u.id AND ts::date=current_date) dk_bugun, " +
            " (SELECT count(DISTINCT date_trunc('minute',ts)) FROM saha_rep_aktivite a WHERE a.user_id=u.id AND ts > now()-interval '7 days') dk_hafta, " +
            " (SELECT count(*) FROM saha_ziyaret z WHERE z.rep_id=u.id AND z.created_at > now()-($2::int * interval '1 day')) ziyaret, " +
            " (SELECT count(*) FROM saha_hata_log h WHERE h.user_id=u.id AND h.ts > now()-($2::int * interval '1 day')) hata, " +
            " (SELECT oda FROM saha_rep_aktivite a WHERE a.user_id=u.id AND oda IS NOT NULL GROUP BY oda ORDER BY count(*) DESC LIMIT 1) en_cok_oda " +
            "FROM users u JOIN tenant_user_modules m ON m.user_id=u.id AND m.module_id='saha' AND m.active " +
            "WHERE m.tenant_id=$1 ORDER BY son_aktivite DESC NULLS LAST", [T, gun])).rows;
          const now = Date.now();
          const out = reps.map(function (r) {
            return { ad: r.ad, son_giris: r.last_login_at, son_aktivite: r.son_aktivite,
              online: r.son_aktivite ? (now - new Date(r.son_aktivite).getTime() < 180000) : false,
              dk_bugun: Number(r.dk_bugun), dk_hafta: Number(r.dk_hafta),
              ziyaret: Number(r.ziyaret), hata: Number(r.hata), en_cok_oda: r.en_cok_oda };
          });
          sendJson(response, 200, { repler: out, gun: gun });
          return;
        }
        sendJson(response, 405, { error: "method" });
      } catch (e) { console.error("[rep-aktivite]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }
'''
s=s.replace(ANCHOR, BLOCK+ANCHOR, 1)
open(F,"w",encoding="utf-8").write(s)
print("[ok] REP_AKTIVITE_V1 eklendi")
