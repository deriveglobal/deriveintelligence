# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OWNER_GATE_SERVER — error telemetry is platform-only. Hiding the tab is not a
# control; a tenant admin could still call the endpoint. requireSahaAccess maps
# BOTH platform_owner and tenant admin to sahaRole 'admin', so an allowedRoles
# check is useless here — gate on the platform role explicitly.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''    if (method === "GET" && path === "/api/saha/hata-raporu") {
      const session = await requireSahaAccess(request, ["manager", "admin"]);''',
'''    if (method === "GET" && path === "/api/saha/hata-raporu") {
      const session = await requireSahaAccess(request);
      // Platform IT only — tenants must not see the platform's error telemetry.
      if (normalizeRole(session.role) !== "platform_owner") {
        sendJson(response, 403, { error: "Bu bölüm platform yönetimine özeldir." });
        return;
      }''',
    "hata-raporu-owner-only")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
