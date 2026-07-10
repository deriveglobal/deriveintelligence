# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# REPBRAIN_FIX — rep Asistan was broken: front sends {message} + reads an SSE
# stream, but server read {mesaj} + replied plain JSON. Accept message, emit SSE.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) accept both field names (front sends `message`, greeting uses `message` too)
rep("      const { mesaj } = body;\n      if (!mesaj) { sendJson(response, 400, { error: 'mesaj zorunlu' }); return; }",
    "      const mesaj = (body.mesaj || body.message || '').toString().trim();\n      if (!mesaj) { sendJson(response, 400, { error: 'mesaj zorunlu' }); return; }",
    "accept-message")

# 2) reply as SSE (one event) so rbStream renders it
rep("      sendJson(response, 200, { yanit });\n      return;",
    '''      response.writeHead(200, { "Content-Type": "text/event-stream; charset=utf-8", "Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no" });
      response.write("data: " + JSON.stringify({ text: yanit }) + "\\n\\n");
      response.write("data: [DONE]\\n\\n");
      response.end();
      return;''',
    "sse-response")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
