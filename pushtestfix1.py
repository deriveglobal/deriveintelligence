#!/usr/bin/env python3
# PUSH_TEST endpoint — POST /api/saha/push-test sends a push to the REQUESTER'S OWN devices
# (bypasses the author-exclusion) so any user can verify push end-to-end. Needs PUSH_ENGINE_V1.
# Idempotent. Run in /opt/krb-assessment (after pushenginefix1.py).
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
anchor = '    if (method === "GET" && path === "/api/saha/araclarim") {'
route = (
    '    if (method === "POST" && path === "/api/saha/push-test") {\n'
    '      const session = await requireSahaAccess(request);\n'
    '      const rr = await pushToUsers(session.tenantId, [session.userId], "\U0001F514 Derive test", "Bildirim testi — çalışıyor ✅", { room: "reception", type: "test" });\n'
    '      sendJson(response, 200, rr);\n'
    '      return;\n'
    '    }\n'
)
if "/api/saha/push-test" in s:
    print("push-test: already present, skip")
elif anchor in s:
    s = s.replace(anchor, route + anchor, 1)
    write(FP, s)
    print("push-test: route added")
else:
    print("WARN: anchor not found")
print("DONE.")
