#!/usr/bin/env bash
# ENDPOINT + UI DESEN KEŞFİ — yama atmadan önce route + ciz_finans + grafik deseni. SADECE OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ROUTE DESENİ — /api/bi/finans nasıl açılıyor (method, path eşleşme, T, res)"
L=$(grep -n "/api/bi/finans'" server_container.mjs | head -1 | cut -d: -f1)
[ -z "$L" ] && L=$(grep -n "/api/bi/finans" server_container.mjs | head -1 | cut -d: -f1)
echo "  finans route ~satır: $L"
sed -n "$((L-8)),$((L+2))p" server_container.mjs | sed 's/^/  /'

hr "2. RES/JSON HELPER — yanıt nasıl gönderiliyor (finans handler sonu)"
sed -n "$((L+40)),$((L+75))p" server_container.mjs | grep -nE "res\.|json|end\(|write|sendJSON|reply|return" | head -12 | sed 's/^/  /'

hr "3. TENANT nasıl türetiliyor route içinde (T = ...)"
sed -n "$((L-8)),$((L+40))p" server_container.mjs | grep -nE "tenant|req\.|session|T ?=|const T|cookie" | head -8 | sed 's/^/  /'

hr "4. bi.js — ciz_finans() render yapısı (ilk 40 satır)"
F=$(grep -n "async function ciz_finans" shells/bi.js | head -1 | cut -d: -f1)
echo "  ciz_finans ~satır: $F"
sed -n "${F},$((F+42))p" shells/bi.js | sed 's/^/  /'

hr "5. GRAFİK KÜTÜPHANESİ — bi.js'te d3/chart/svg var mı (trend grafiği için)"
grep -noE "d3\.[a-zA-Z]+|Chart\.|chart\.js|createElementNS|<svg|sparkline|drawChart|miniChart" shells/bi.js | sort | uniq -c | sort -rn | head | sed 's/^/  /'

hr "6. FİNANS ODASI SEKME/BÖLÜM — govde tek mi, sub-tab var mı"
grep -nE "finans-govde|vmo-stab|data-section|finans.*tab" shells/bi.js | head -12 | sed 's/^/  /'

hr "7. index.html — head'de yüklü script'ler (d3/chart CDN var mı)"
grep -nE "script src|cdn|d3|chart" index.html 2>/dev/null | head -10 | sed 's/^/  /'

hr "BITTI — route + render + grafik deseni görüldü. Yama buna göre uyumlu yazılır."
