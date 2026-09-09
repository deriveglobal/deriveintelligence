#!/usr/bin/env bash
# Endpoint kalıbı keşif — GET (drag) + POST-body okuyan + session/sendJson helper. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
F=server_container.mjs
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. finans-marka-drag GET endpoint (kendi kalıbım) — 30 satır"
grep -n "finans-marka-drag" $F | head -3 | sed 's/^/  /'
L=$(grep -n "finans-marka-drag" $F | head -1 | cut -d: -f1); sed -n "$((L-2)),$((L+28))p" $F | sed 's/^/  /'

hr "2. POST + JSON body okuyan bir endpoint (itiraz veya saglik-alarm-karar)"
grep -n "saglik-alarm-karar\|/api/bi/itiraz'\|readBody\|readJson\|JSON.parse(body)\|for await" $F | head -12 | sed 's/^/  /'

hr "3. session/tenant + sendJson/yaz helper imzası"
grep -n "function sendJson\|const sendJson\|sendJson =\|function jsonYanit\|session.tenantId\|resolveSession\|oturumAl" $F | head -8 | sed 's/^/  /'

hr "4. yukle/durum çapası (buraya yakın ekleyeceğim)"
grep -n "yukle/durum\|'/api/bi/koken'\|finans-marka-detay" $F | head -5 | sed 's/^/  /'

hr "BITTI"
