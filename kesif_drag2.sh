#!/usr/bin/env bash
set -uo pipefail
cd /opt/krb-assessment || exit 1
F=shells/bi.js
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. _markaDragCiz tanımı + çağrısı (satır no'ları)"
grep -n "_markaDragCiz" "$F" | sed 's/^/  /'

hr "2. _markaDragCiz gövdesi (fetch+render stili) — tanımdan 45 satır"
L=$(grep -n "function _markaDragCiz\|_markaDragCiz *=" "$F" | head -1 | cut -d: -f1)
[ -z "$L" ] && L=$(grep -n "_markaDragCiz" "$F" | head -1 | cut -d: -f1)
sed -n "$((L-2)),$((L+45))p" "$F" | sed 's/^/  /'

hr "3. çağrı bağlamı (det.innerHTML=hh sonrası)"
L2=$(grep -n "_markaDragCiz(" "$F" | tail -1 | cut -d: -f1)
sed -n "$((L2-4)),$((L2+2))p" "$F" | sed 's/^/  /'

hr "BITTI"
