#!/bin/bash
# fix_rakip_auth.sh — rakip endpoint'lerini intelligence auth ile wrap et
# user?.tenant_id || 1  →  session.tenantId (requireModuleAccess'ten)
set -e
TARGET="/opt/krb-assessment/server.mjs"

# Her rakip endpoint bloğunun başına session al, tenant_id'yi düzelt
# Pattern: "const tid = user?.tenant_id || 1;" → proper session
perl -i -pe "s/const tid = user\?\.tenant_id \|\| 1;/const _rSess = await requireModuleAccess(request, 'intelligence').catch(()=>null) || await requireModuleAccess(request, 'saha').catch(()=>null); const tid = _rSess?.tenantId || null; if (!tid) { sendJson(response, 401, { error: 'Unauthorized' }); return; }/g" "$TARGET"

echo "Verify:"
grep -n '_rSess\|rakip.*tenantId' "$TARGET" | head -10
echo "Satır: $(wc -l < $TARGET)"
