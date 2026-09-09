#!/usr/bin/env bash
# DRAG KARTI + drill çizim keşfi — sebep anlatısını nereye/nasıl ekleyeceğim. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
BIJS=$(ls -1 public/bi.js app/bi.js bi.js 2>/dev/null | head -1); echo "  bi.js: $BIJS"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. _markaDragCiz fonksiyonu (omurga_44) — ilk 40 satır"
L=$(grep -n "_markaDragCiz" "$BIJS" | head -1 | cut -d: -f1); echo "  satır: $L"
sed -n "$((L-2)),$((L+40))p" "$BIJS" | sed 's/^/  /'

hr "2. _markaDragCiz nereden ÇAĞRILIYOR (det.innerHTML sonrası)"
grep -n "_markaDragCiz\|finans-marka-drag\|det.innerHTML" "$BIJS" | head -12 | sed 's/^/  /'

hr "3. fetch kalıbı (bir örnek — nasıl auth/json)"
grep -n "fetch('/api/bi/finans-marka-drag" "$BIJS" | head -2 | sed 's/^/  /'
L2=$(grep -n "fetch('/api/bi/finans-marka-drag" "$BIJS" | head -1 | cut -d: -f1)
[ -n "$L2" ] && sed -n "$((L2-3)),$((L2+10))p" "$BIJS" | sed 's/^/  /'

hr "BITTI — kalıp görüldü; sebep endpoint'i + _markaSebepCiz aynı stille eklenir."
