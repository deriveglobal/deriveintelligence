#!/usr/bin/env bash
# GUARD HOOK KEŞİF — ingest nasıl tetikleniyor/bitiyor, guard çağrısı nereye. SADECE OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. /api/bi/yukle endpoint — ingest'i nasıl çalıştırıyor (spawn python? tenant?)"
L=$(grep -n "url.pathname === '/api/bi/yukle'" server_container.mjs | head -1 | cut -d: -f1)
echo "  yukle route ~satır: $L"
[ -n "$L" ] && sed -n "${L},$((L+55))p" server_container.mjs | grep -nE "spawn|exec|erp_ingest|python|tenant|await|child|then|finally|res|sendJson" | head -20 | sed 's/^/  /'

hr "2. erp_ingest.py — SON 35 satır (main/bitiş yapısı)"
tail -35 erp_ingest.py | sed 's/^/  /'

hr "3. erp_ingest.py — main / __main__ / tenant / psycopg2 / commit noktaları"
grep -nE "def main|__main__|psycopg2|conn|\.commit\(\)|tenant|sys.argv|def ingest" erp_ingest.py | head -25 | sed 's/^/  /'

hr "4. erp_ingest.py — DB bağlantısı nasıl kuruluyor (guard çağrısı için lazım)"
grep -nE "connect\(|DATABASE|DB_|host=|dbname|getenv|environ" erp_ingest.py | head -10 | sed 's/^/  /'

hr "BITTI — hook noktası (erp_ingest.py sonu ya da yukle endpoint) görülünce guard bağlanır."
