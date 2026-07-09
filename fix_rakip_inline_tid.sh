#!/bin/bash
# fix_rakip_inline_tid.sh — fix remaining inline user?.tenant_id || 1 in rakip endpoints
# These were NOT "const tid = user?.tenant_id || 1;" so the previous perl fix missed them.
# Each block already has `tid` defined (from fix_rakip_auth.sh). Just replace the inline uses.
set -e

TARGET="/opt/krb-assessment/server.mjs"

# Also update the /api/rakip/ayar endpoint to handle per-tenant settings
# (bi_rakip_izle_ayar now has composite PK: key + tenant_id)

echo "=== fix_rakip_inline_tid.sh ==="
echo "Before:"
grep -n 'user?.tenant_id' "$TARGET" | head -10

# 1. PUT /api/rakip/izle/:id — vals.push(user?.tenant_id || 1)
perl -i -pe 's/vals\.push\(user\?\.tenant_id \|\| 1\);/vals.push(tid);/g' "$TARGET"

# 2. POST /api/rakip/alarm/goruldu-hepsi — [user?.tenant_id || 1]
#    and POST /api/rakip/alarm/:id/goruldu — [alarmId, user?.tenant_id || 1]
perl -i -pe 's/\[user\?\.tenant_id \|\| 1\]/[tid]/g' "$TARGET"
perl -i -pe 's/\[alarmId, user\?\.tenant_id \|\| 1\]/[alarmId, tid]/g' "$TARGET"

echo ""
echo "After (should be 0 rakip occurrences):"
grep -n 'user?.tenant_id' "$TARGET" | head -10

echo ""
echo "Verify tid references in alarm section:"
grep -n '\btid\b' "$TARGET" | grep -E '2031[0-9]:|2032[0-9]:' | head -10

echo "Satır: $(wc -l < $TARGET)"
echo "✓ fix_rakip_inline_tid.sh tamamlandı"
