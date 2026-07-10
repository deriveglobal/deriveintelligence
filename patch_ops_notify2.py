# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OPS_NOTIFY2 — place /api/ops/notify at TOP-LEVEL routing (next to /api/bi/ingest),
# NOT inside the /api/saha/ prefix router (that caused a 404). Top-level scope uses
# `query(...)` + `sendJson(response,...)` + `url.pathname`. Apply to a fresh restore
# of the pre-ops backup so the misplaced block is gone.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

ANCHOR = 'if (request.method === "POST" && url.pathname === "/api/bi/ingest") {'
EP = r'''if ((request.method === "GET" || request.method === "POST") && url.pathname === "/api/ops/notify") {
  let secret = "";
  try { secret = url.searchParams.get("key") || request.headers["x-ops-secret"] || ""; } catch (e) {}
  let ok = false;
  try { const _s = await query("SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'"); ok = !!(_s.rows[0] && _s.rows[0].value && _s.rows[0].value === secret); } catch (e) {}
  if (!ok) { sendJson(response, 403, { error: "forbidden" }); return; }
  let sent = 0;
  try {
    const _em = await query("SELECT value FROM ops_ayar WHERE key='alert_email'");
    const to = (_em.rows[0] && _em.rows[0].value) || "fatih@deriveglobal.com";
    const inc = await query("SELECT id, category, title, detail, first_seen, occurrences FROM ops_incident WHERE status='open' AND severity='crit' AND email_sent=false ORDER BY first_seen ASC");
    if (inc.rows.length) {
      const lines = inc.rows.map(r => "- [" + r.category + "] " + r.title + " - " + (r.detail || "") + " (ilk gorulme: " + new Date(r.first_seen).toLocaleString("tr-TR") + ", tekrar: " + r.occurrences + ")").join("\n");
      const subject = "Ops uyarisi: " + inc.rows.length + " kritik durum";
      const body = "Merhaba,\n\nDerive Ops izleme katmani asagidaki KRITIK durumlari tespit etti:\n\n" + lines + "\n\nBu bir teshis bildirimidir; otomatik mudahale YAPILMADI. Paneli inceleyebilirsin.\n\n-- Ops Monitor";
      await sendGraphMail({ to, subject, body });
      await query("UPDATE ops_incident SET email_sent=true WHERE id = ANY($1)", [inc.rows.map(r => r.id)]);
      sent = inc.rows.length;
    }
  } catch (e) { sendJson(response, 500, { error: String((e && e.message) || e) }); return; }
  sendJson(response, 200, { ok: true, emailed: sent });
  return;
}

'''

c = s.count(ANCHOR)
assert c == 1, "ABORT: bi/ingest anchor found %d" % c
# guard: make sure the misplaced saha-scoped block is not present (fresh restore expected)
assert s.count('path === "/api/ops/notify"') == 0, "ABORT: misplaced ops/notify still present — restore bak_ops first"
s = s.replace(ANCHOR, EP + ANCHOR)
print("OK: ops-notify-toplevel")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
