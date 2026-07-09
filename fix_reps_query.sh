#!/bin/bash
TARGET="/opt/krb-assessment/server.mjs"

perl -i -pe 's|SELECT u\.id, u\.name, u\.email FROM users u JOIN user_modules um ON um\.user_id = u\.id AND um\.module = .saha. WHERE u\.tenant_id = \$1 AND u\.disabled IS NOT TRUE ORDER BY u\.name|SELECT u.id, u.full_name, u.email FROM users u JOIN tenant_user_modules tum ON tum.user_id = u.id AND tum.module_id = '"'"'saha'"'"' AND tum.tenant_id = \$1 AND tum.active = true WHERE u.status != '"'"'disabled'"'"' ORDER BY u.full_name|g' "$TARGET"

echo "Verify:"
grep -n 'full_name\|tenant_user_modules' "$TARGET" | grep -i 'reps\|saha/reps' || grep -n 'full_name' "$TARGET" | tail -3
echo "Satır: $(wc -l < $TARGET)"
