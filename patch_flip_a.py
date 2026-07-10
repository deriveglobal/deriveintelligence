# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# FLIP_A — isolate the CEO free-SQL (biggest leak, smallest blast radius).
#   1) add a lazy app_tenant pool (NON-superuser -> RLS actually applies)
#   2) point the existing queryAsTenant() at that pool
#   3) route executeQueryTool() (CEO query_database) through queryAsTenant()
# Everything else keeps using the superuser pool (unchanged) for now.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) insert tenantPool() just before queryAsTenant, and 2) repoint queryAsTenant's pool
rep(
'''async function queryAsTenant(tenantId, sql, params = []) {
  const db = requireDatabase();
  const client = await db.pool.connect();          // checkout dedicated client''',
'''let _tenantPool = null;
async function tenantPool() {
  if (_tenantPool) return _tenantPool;
  if (!databaseUrl) throw new Error("DATABASE_URL not set");
  const u = new URL(databaseUrl);
  const _r = await query("SELECT value FROM ops_ayar WHERE key='app_tenant_pw'");
  const _pw = _r.rows[0] && _r.rows[0].value;
  if (!_pw) throw new Error("app_tenant password missing (ops_ayar.app_tenant_pw)");
  _tenantPool = new pg.Pool({
    host: u.hostname,
    port: u.port ? Number(u.port) : 5432,
    database: u.pathname.replace(/^\\//, ""),
    user: "app_tenant",
    password: _pw,
    max: 5,
    ssl: (u.searchParams.get("sslmode") === "require") ? { rejectUnauthorized: false } : false
  });
  return _tenantPool;
}

async function queryAsTenant(tenantId, sql, params = []) {
  const tp = await tenantPool();
  const client = await tp.connect();''',
    "tenantpool+queryAsTenant")

# 3) SET LOCAL cannot take a bind param ($1); use set_config() instead
rep(
"    await client.query('SET LOCAL app.current_tenant_id = $1', [tenantId]);",
"    await client.query(\"SELECT set_config('app.current_tenant_id', $1, true)\", [tenantId]);",
    "set_config-fix")

# 4) route the CEO free-SQL through the RLS-enforced path
rep(
"    const result = await query(finalSql, []);",
"    const result = await queryAsTenant(tenantId, finalSql, []);",
    "executeQueryTool-scoped")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
