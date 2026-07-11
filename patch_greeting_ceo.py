# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# GREETING_CEO — cache the CEO daily greeting server-side.
#   * on a greeting request (is_greeting), if today's cached greeting exists,
#     stream it back with ZERO LLM cost.
#   * after generating a fresh greeting, store it in agent_greeting_cache.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) cache-check before we insert the user msg / run the LLM
rep(
"""        const userMsg = (body.message || '').trim();
        if (!userMsg) { sendJson(response, 400, { error: 'message required' }); return; }
        await query('INSERT INTO brain_conversations (tenant_id, role, content) VALUES ($1,$2,$3)', [tenantId, 'user', userMsg]);""",
"""        const userMsg = (body.message || '').trim();
        if (!userMsg) { sendJson(response, 400, { error: 'message required' }); return; }
        if (body.is_greeting) {
          try {
            const _cg = await query("SELECT content FROM agent_greeting_cache WHERE user_id=$1 AND agent='ceo' AND greet_date=CURRENT_DATE", [session.userId]);
            if (_cg.rows[0]) {
              response.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive', 'X-Accel-Buffering': 'no' });
              response.write('data: ' + JSON.stringify({ text: _cg.rows[0].content }) + '\\n\\n');
              response.write('data: ' + JSON.stringify({ done: true }) + '\\n\\n');
              response.end();
              return;
            }
          } catch (e) {}
        }
        await query('INSERT INTO brain_conversations (tenant_id, role, content) VALUES ($1,$2,$3)', [tenantId, 'user', userMsg]);""",
    "ceo-cache-check")

# 2) cache-write after the fresh greeting is produced
rep(
"""        if (fullResp.trim()) {
          await query('INSERT INTO brain_conversations (tenant_id, role, content) VALUES ($1,$2,$3)', [tenantId, 'assistant', fullResp.trim()]);
        }""",
"""        if (fullResp.trim()) {
          await query('INSERT INTO brain_conversations (tenant_id, role, content) VALUES ($1,$2,$3)', [tenantId, 'assistant', fullResp.trim()]);
          if (body.is_greeting) {
            try { await query("INSERT INTO agent_greeting_cache (tenant_id,user_id,agent,greet_date,content) VALUES ($1,$2,'ceo',CURRENT_DATE,$3) ON CONFLICT (user_id,agent,greet_date) DO UPDATE SET content=EXCLUDED.content, created_at=now()", [tenantId, session.userId, fullResp.trim()]); } catch (e) {}
          }
        }""",
    "ceo-cache-write")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
