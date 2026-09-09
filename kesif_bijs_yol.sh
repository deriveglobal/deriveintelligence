#!/usr/bin/env bash
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. _markaDragCiz hangi dosyada"
grep -rln "_markaDragCiz" . --include=*.js --include=*.mjs --include=*.html 2>/dev/null | grep -v node_modules | sed 's/^/  /'

hr "2. finans-marka-drag frontend hangi dosyada"
grep -rln "finans-marka-drag" . --include=*.js --include=*.mjs --include=*.html 2>/dev/null | grep -v node_modules | grep -v server_container | sed 's/^/  /'

hr "3. bi.js benzeri dosyalar"
find . -name "bi*.js" -not -path "*/node_modules/*" 2>/dev/null | sed 's/^/  /'
ls -la public 2>/dev/null | head -20 | sed 's/^/  /'
