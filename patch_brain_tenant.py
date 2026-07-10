# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# BRAIN_TENANT — CEO brain 500s for a pure platform_owner because session.tenantId
# is null (platform owners have no single tenant) and brain_conversations.tenant_id
# is NOT NULL. Resolve a default active tenant when none is set (no hardcoded UUID);
# mutate session.tenantId so downstream tool calls (executeQueryTool) also get it.
# Pre-existing bug, independent of the RLS flip.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = (
"        const tenantId = session.tenantId;\n"
"        await _ensureBrainDb();"
)
NEW = (
"        if (!session.tenantId) {\n"
"          const _dt = await query(\"SELECT id FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1\");\n"
"          if (_dt.rows[0]) session.tenantId = _dt.rows[0].id;\n"
"        }\n"
"        const tenantId = session.tenantId;\n"
"        await _ensureBrainDb();"
)

c = s.count(OLD)
assert c == 3, "ABORT: expected 3 brain tenant anchors, found %d" % c
s = s.replace(OLD, NEW)   # fix all brain handlers (chat + tasks/notes/prefs)
print("OK: brain-tenant-resolve x%d" % c)
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
