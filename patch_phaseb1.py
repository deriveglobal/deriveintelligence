# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# PHASE B1 (additive, no behavior change) — tenant-context plumbing.
#   * import AsyncLocalStorage
#   * query() checks an ALS store: if a request has set {tenantId} (and not elevated),
#     route through queryAsTenant (app_tenant pool + SET LOCAL); otherwise use the
#     admin pool exactly as today.
# Nothing sets the ALS store yet, so tenantALS.getStore() is always undefined ->
# query() behaves identically. Enabling per-module happens in B2.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) import AsyncLocalStorage
rep(
'import { createServer } from "node:http";',
'import { createServer } from "node:http";\nimport { AsyncLocalStorage } from "node:async_hooks";',
    "import-als")

# 2) tenant-aware query() (dormant until a request sets the ALS store)
rep(
'''async function query(sql, params = []) {
  return requireDatabase().query(sql, params);
}''',
'''const tenantALS = new AsyncLocalStorage();
async function query(sql, params = []) {
  const _ctx = tenantALS.getStore();
  if (_ctx && _ctx.tenantId && !_ctx.elevated) {
    return queryAsTenant(_ctx.tenantId, sql, params);
  }
  return requireDatabase().query(sql, params);
}''',
    "query-tenant-aware")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
