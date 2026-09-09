#!/usr/bin/env bash
# ciz_veri gövdesi + endpoint iskeleti + POST route örneği. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ciz_veri() TAM gövde (799-945)"
sed -n '799,945p' shells/bi.js

hr "2. Endpoint iskeleti — account-health (session/query/sendJson deseni, 21555-21600)"
sed -n '21555,21605p' server_container.mjs

hr "3. Bir POST /api/bi route örneği (body okuma deseni)"
grep -nE "method === 'POST' && url.pathname === '/api/bi/" server_container.mjs | head -5 | sed 's/^/  /'

hr "BITTI"
