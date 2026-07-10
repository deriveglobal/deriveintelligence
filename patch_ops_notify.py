# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OPS_NOTIFY — add GET/POST /api/ops/notify (secret-gated, mirrors gunluk-ozet).
# Reads OPEN crit incidents not yet emailed, sends ONE digest via sendGraphMail
# to ops_ayar.alert_email, marks them emailed. Diagnose-only; no remediation.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

ANCHOR = '    if ((method === "POST" || method === "GET") && path === "/api/saha/gunluk-ozet") {'
EP = r'''    if ((method === "GET" || method === "POST") && path === "/api/ops/notify") {
      let secret = "";
      try { secret = url.searchParams.get("key") || request.headers["x-ops-secret"] || ""; } catch (e) {}
      let ok = false;
      try { const _s = await pool.query("SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'"); ok = !!(_s.rows[0] && _s.rows[0].value && _s.rows[0].value === secret); } catch (e) {}
      if (!ok) { sendJson(response, 403, { error: "forbidden" }); return; }
      let sent = 0;
      try {
        const _em = await pool.query("SELECT value FROM ops_ayar WHERE key='alert_email'");
        const to = (_em.rows[0] && _em.rows[0].value) || "fatih@deriveglobal.com";
        const inc = await pool.query("SELECT id, category, title, detail, first_seen, occurrences FROM ops_incident WHERE status='open' AND severity='crit' AND email_sent=false ORDER BY first_seen ASC");
        if (inc.rows.length) {
          const lines = inc.rows.map(r => "- [" + r.category + "] " + r.title + " - " + (r.detail || "") + " (ilk gorulme: " + new Date(r.first_seen).toLocaleString("tr-TR") + ", tekrar: " + r.occurrences + ")").join("\n");
          const subject = "Ops uyarisi: " + inc.rows.length + " kritik durum";
          const body = "Merhaba,\n\nDerive Ops izleme katmani asagidaki KRITIK durumlari tespit etti:\n\n" + lines + "\n\nBu bir teshis bildirimidir; otomatik mudahale YAPILMADI. Paneli inceleyebilirsin.\n\n-- Ops Monitor";
          await sendGraphMail({ to, subject, body });
          await pool.query("UPDATE ops_incident SET email_sent=true WHERE id = ANY($1)", [inc.rows.map(r => r.id)]);
          sent = inc.rows.length;
        }
      } catch (e) { sendJson(response, 500, { error: String((e && e.message) || e) }); return; }
      sendJson(response, 200, { ok: true, emailed: sent });
      return;
    }
'''

c = s.count(ANCHOR)
assert c == 1, "ABORT: gunluk-ozet anchor found %d" % c
s = s.replace(ANCHOR, EP + ANCHOR)
print("OK: ops-notify-endpoint")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
