# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# GREETING_REP — cache the rep Asistan daily greeting (same pattern as CEO).
# The client already sends is_greeting:true. Add cache-check (return cached, no LLM)
# + cache-write (agent='rep') to /api/saha/rep-brain.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) cache-check before inserting user msg / running the LLM
rep(
"""      if (!mesaj) { sendJson(response, 400, { error: 'mesaj zorunlu' }); return; }
      // Sohbet geçmişini kaydet""",
"""      if (!mesaj) { sendJson(response, 400, { error: 'mesaj zorunlu' }); return; }
      if (body.is_greeting) {
        try {
          const _rg = await pool.query("SELECT content FROM agent_greeting_cache WHERE user_id=$1 AND agent='rep' AND greet_date=CURRENT_DATE", [session.userId]);
          if (_rg.rows[0]) {
            response.writeHead(200, { "Content-Type": "text/event-stream; charset=utf-8", "Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no" });
            response.write("data: " + JSON.stringify({ text: _rg.rows[0].content }) + "\\n\\n");
            response.write("data: [DONE]\\n\\n");
            response.end();
            return;
          }
        } catch (e) {}
      }
      // Sohbet geçmişini kaydet""",
    "rep-cache-check")

# 2) cache-write after the assistant reply is saved
rep(
"""      // AI yanıtını kaydet
      await pool.query(
        `INSERT INTO saha_rep_conversations (tenant_id, rep_id, role, content)
         VALUES ($1,$2,'assistant',$3)`,
        [session.tenantId, session.userId, yanit]
      );""",
"""      // AI yanıtını kaydet
      await pool.query(
        `INSERT INTO saha_rep_conversations (tenant_id, rep_id, role, content)
         VALUES ($1,$2,'assistant',$3)`,
        [session.tenantId, session.userId, yanit]
      );
      if (body.is_greeting && yanit && !yanit.startsWith('Hata:') && yanit !== 'Şu an yanıt veremiyorum, lütfen tekrar dene.') {
        try { await pool.query("INSERT INTO agent_greeting_cache (tenant_id,user_id,agent,greet_date,content) VALUES ($1,$2,'rep',CURRENT_DATE,$3) ON CONFLICT (user_id,agent,greet_date) DO UPDATE SET content=EXCLUDED.content, created_at=now()", [session.tenantId, session.userId, yanit]); } catch (e) {}
      }""",
    "rep-cache-write")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
