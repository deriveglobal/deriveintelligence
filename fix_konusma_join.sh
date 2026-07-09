#!/bin/bash
# fix_konusma_join.sh — users.tenant_id hatası için hızlı düzeltme
set -e

TARGET="/opt/krb-assessment/server.mjs"

# 1. LEFT JOIN'den tenant_id koşulunu kaldır
perl -i -pe 's/LEFT JOIN users u ON u\.id=k\.rep_id AND u\.tenant_id=k\.tenant_id/LEFT JOIN users u ON u.id=k.rep_id/g' "$TARGET"

# 2. Yayım POST'undaki users.tenant_id WHERE'ini kaldır — user_modules üzerinden filtrele
perl -i -pe 's/WHERE u\.tenant_id=\$1 AND u\.disabled IS NOT TRUE/WHERE u.disabled IS NOT TRUE/g' "$TARGET"

echo "✓ tenant_id JOIN hatası giderildi"
echo "  Toplam satır: $(wc -l < $TARGET)"
