#!/usr/bin/env bash
# Dönem seçici yaması için: 2 endpoint + 2 UI fonksiyonun TOOLTIP SONRASI güncel hali. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. /api/bi/finans-trend endpoint (tam)"
S=$(grep -n "url.pathname === '/api/bi/finans-trend'" server_container.mjs | head -1 | cut -d: -f1)
sed -n "${S},$((S+22))p" server_container.mjs

hr "2. /api/bi/finans-marka-detay endpoint (tam)"
S2=$(grep -n "url.pathname === '/api/bi/finans-marka-detay'" server_container.mjs | head -1 | cut -d: -f1)
sed -n "${S2},$((S2+26))p" server_container.mjs

hr "3. _finansTrendCiz (tam, güncel) — 649 civarı"
A=$(grep -n "async function _finansTrendCiz" shells/bi.js | head -1 | cut -d: -f1)
sed -n "${A},$((A+40))p" shells/bi.js

hr "4. _markaDetay (tam, güncel)"
B=$(grep -n "async function _markaDetay" shells/bi.js | head -1 | cut -d: -f1)
sed -n "${B},$((B+42))p" shells/bi.js

hr "BITTI"
