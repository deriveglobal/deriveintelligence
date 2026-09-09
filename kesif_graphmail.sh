#!/usr/bin/env bash
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. sendGraphMail imzası + gövde (4428+30)"
sed -n '4428,4460p' server_container.mjs | sed 's/^/  /'

hr "2. Gerçek çağrı örneği (4061 civarı) — alıcı/konu/içerik nasıl geçiliyor"
sed -n '4061,4080p' server_container.mjs | sed 's/^/  /'

hr "3. Owner / Fatih e-postası (users tablosu)"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT email, name, role FROM users WHERE lower(email) LIKE '%fat%' OR lower(role) LIKE '%owner%' OR lower(role) LIKE '%admin%' ORDER BY role LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "BITTI"
