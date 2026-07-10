# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OPS_DASHBOARD — owner-gated read endpoint + /ops page route (M2).
#   GET /api/ops/health : requirePlatformOwner -> {last_run, summary, checks, incidents}
#   GET /ops            : serves /app/shells/ops.html (self-contained console)
# Inserted at top-level routing, just before the /api/ops/notify block.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

ANCHOR = 'if ((request.method === "GET" || request.method === "POST") && url.pathname === "/api/ops/notify") {'
BLOCK = r'''if (request.method === "GET" && url.pathname === "/api/ops/health") {
  const session = await requirePlatformOwner(request, response);
  if (!session) return;
  try {
    const runR = await query("SELECT run_id, MAX(checked_at) AS ts FROM ops_health GROUP BY run_id ORDER BY ts DESC LIMIT 1");
    const runId = runR.rows[0] && runR.rows[0].run_id;
    const checks = runId ? (await query("SELECT category, check_key, title, status, value, detail, metric, checked_at FROM ops_health WHERE run_id=$1 ORDER BY CASE status WHEN 'crit' THEN 0 WHEN 'warn' THEN 1 ELSE 2 END, category, check_key", [runId])).rows : [];
    const openInc = (await query("SELECT id, check_key, category, title, severity, detail, first_seen, last_seen, occurrences, seen FROM ops_incident WHERE status='open' ORDER BY CASE severity WHEN 'crit' THEN 0 ELSE 1 END, first_seen")).rows;
    const resolvedInc = (await query("SELECT id, category, title, severity, first_seen, resolved_at FROM ops_incident WHERE status='resolved' AND resolved_at > now()-interval '7 days' ORDER BY resolved_at DESC LIMIT 20")).rows;
    const summary = { ok: 0, warn: 0, crit: 0 };
    for (const c of checks) { if (summary[c.status] != null) summary[c.status]++; }
    sendJson(response, 200, { last_run: runR.rows[0] ? runR.rows[0].ts : null, summary, checks, incidents: { open: openInc, resolved_recent: resolvedInc } });
  } catch (e) { sendJson(response, 500, { error: String((e && e.message) || e) }); }
  return;
}
if (request.method === "GET" && url.pathname === "/ops") {
  try {
    const _h = await readFile("/app/shells/ops.html", "utf8");
    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    response.end(_h);
  } catch (e) { sendJson(response, 404, { error: "ops paneli bulunamadi" }); }
  return;
}
'''

c = s.count(ANCHOR)
assert c == 1, "ABORT: ops/notify anchor found %d" % c
s = s.replace(ANCHOR, BLOCK + ANCHOR)
print("OK: ops-dashboard-routes")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
