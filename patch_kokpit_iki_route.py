#!/usr/bin/env python3
# KOKPIT_IKI_ROUTE_V1 — yeni onizleme kabugunu servis eden route (additive, idempotent).
#   GET /api/bi/kokpit-iki  ->  /app/shells/kokpit_iki.html  (eski /api/bi/kokpit DOKUNULMAZ)
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "KOKPIT_IKI_ROUTE_V1" in s:
    print("[skip] KOKPIT_IKI_ROUTE_V1 zaten var"); sys.exit(0)
anchor = 'if (request.method === "GET" && url.pathname === "/api/bi/kokpit") {'
i = s.find(anchor)
assert i != -1, "HATA: /api/bi/kokpit route anchor bulunamadi"
ls = s.rfind("\n", 0, i) + 1
BLOCK = r'''  if (request.method === "GET" && url.pathname === "/api/bi/kokpit-iki") { /* KOKPIT_IKI_ROUTE_V1 */
    try {
      const _h = await readFile("/app/shells/kokpit_iki.html", "utf8");
      response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      response.end(_h);
    } catch (e) { sendJson(response, 404, { error: "kokpit-iki bulunamadi" }); }
    return;
  }
'''
s = s[:ls] + BLOCK + s[ls:]
open(F, "w", encoding="utf-8").write(s)
print("[ok] KOKPIT_IKI_ROUTE_V1 eklendi @ offset", ls)
