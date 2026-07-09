#!/bin/bash
# fix_saha_reps.sh — /api/saha/reps ve yayim broadcast sorgularını düzeltir
set -e
TARGET="/opt/krb-assessment/server.mjs"

# 1. /api/saha/reps — user_modules → tenant_user_modules, name→full_name, disabled→status
perl -i -0777 -pe '
  s|SELECT u\.id, u\.name, u\.email\s*FROM users u\s*JOIN user_modules um ON um\.user_id = u\.id AND um\.module = .saha.\s*WHERE u\.disabled IS NOT TRUE\s*ORDER BY u\.name|SELECT u.id, u.full_name, u.email\n         FROM users u\n         JOIN tenant_user_modules tum ON tum.user_id = u.id AND tum.module_id = '"'"'saha'"'"' AND tum.tenant_id = \$1 AND tum.active = true\n         WHERE u.status != '"'"'disabled'"'"'\n         ORDER BY u.full_name|sg
' "$TARGET"

# 2. Yayim broadcast — user_modules → tenant_user_modules  
perl -i -0777 -pe '
  s|FROM users u\s*JOIN user_modules um ON um\.user_id=u\.id AND um\.module=.saha.\s*WHERE u\.tenant_id=\\\$1 AND u\.disabled IS NOT TRUE|FROM users u\n         JOIN tenant_user_modules tum ON tum.user_id=u.id AND tum.module_id='"'"'saha'"'"' AND tum.tenant_id=\$1 AND tum.active=true\n         WHERE u.status != '"'"'disabled'"'"'|sg
' "$TARGET"

# 3. Alternatif yazımı da düzelt (WHERE u.disabled IS NOT TRUE sadece kaldı ise)
perl -i -pe 's/WHERE u\.disabled IS NOT TRUE/WHERE u.status != '"'"'disabled'"'"'/g' "$TARGET"

echo "✓ Reps sorguları düzeltildi"
echo "  Toplam satır: $(wc -l < $TARGET)"
