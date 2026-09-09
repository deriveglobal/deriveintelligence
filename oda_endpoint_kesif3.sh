#!/usr/bin/env bash
# SON KEŞİF — tam finans handler gövdesi (DB query API) + ciz_finans commit noktası. SADECE OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TAM FİNANS HANDLER — 23680-23770 (query API + sendJson payload)"
sed -n '23680,23770p' server_container.mjs | sed 's/^/  /'

hr "2. DB QUERY API — pool/db/client hangisi (server genelinde en sık)"
grep -noE "await (pool|db|client|pg|sql)\.query" server_container.mjs | sort | uniq -c | sort -rn | head | sed 's/^/  /'

hr "3. ciz_finans COMMIT ÖNCESİ — 735-755 (trend bölümünü nereye ekleyeceğim)"
sed -n '735,755p' shells/bi.js | sed 's/^/  /'

hr "BITTI — her şey görüldü, yama yazılır."
