#!/usr/bin/env bash
# YUKLE ENDPOINT tam gövde — execFile sonrası sonuç işleme + sendJson. Guard'ı nereye ekleyeceğim. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. /api/bi/yukle — execFile'dan sendJson'a kadar (sonuç işleme)"
L=$(grep -n "url.pathname === '/api/bi/yukle'" server_container.mjs | head -1 | cut -d: -f1)
echo "  yukle route: $L"
sed -n "$((L+43)),$((L+95))p" server_container.mjs | sed 's/^/  /'

hr "BITTI — sonuç işleme + sendJson görüldü, guard çağrısı buraya eklenir."
