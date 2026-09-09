#!/usr/bin/env bash
# ENDPOINT İSKELETİ — yanıt gönderim şekli + ciz_finans bitişi + helper'lar. SADECE OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. FİNANS ROUTE YANITI — nasıl gönderiliyor (23680'den itibaren response satırları)"
sed -n '23680,23800p' server_container.mjs | grep -nE "writeHead|\.end\(|sendJson|jsonResponse|json\(|new Response|response\.|return " | head -20 | sed 's/^/  /'

hr "2. KISA BİR GET /api/bi ROUTE — tam iskelet kopyalamak için (en yakın basit handler)"
grep -nE "url\.pathname === '/api/bi/[a-z/-]+'" server_container.mjs | head -15 | sed 's/^/  /'

hr "3. BİR HANDLER'IN TAM YANIT SATIRI — writeHead/end deseni (ilk bulunan örnek)"
LN=$(grep -n "writeHead" server_container.mjs | head -1 | cut -d: -f1)
echo "  ilk writeHead ~satır: $LN"
sed -n "$((LN-2)),$((LN+3))p" server_container.mjs | sed 's/^/  /'

hr "4. ciz_finans BİTİŞİ — h nereye yazılıyor (g.innerHTML = h) ve section eklenebilir mi"
grep -nE "finans-govde|g\.innerHTML|innerHTML = h|ciz_finans" shells/bi.js | head -12 | sed 's/^/  /'

hr "5. HELPER'LAR — _M, esc, sTL, _tl tanımlı mı (render için)"
grep -nE "function _M|const _M|function esc|const esc|function sTL|function _tl" shells/bi.js | head | sed 's/^/  /'

hr "6. requireModuleAccess imzası (intelligence yetkisi doğru mu)"
grep -nE "requireModuleAccess|intelligence" server_container.mjs | head -5 | sed 's/^/  /'

hr "BITTI — iskelet net. Endpoint + ciz_finans append yaması güvenle yazılır."
