#!/usr/bin/env bash
# LLM yardımcısı + #113 taslak deseni + bi_icgoru→carousel yolu. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. LLM çağrı yardımcısı (fonksiyon adı + imza)"
grep -noE "async function [a-zA-Z_]*[Ll]lm[a-zA-Z_]*|async function [a-zA-Z_]*[Aa]nthropic[a-zA-Z_]*|async function callClaude|async function [a-zA-Z_]*[Aa]jan[a-zA-Z_]*|function [a-zA-Z_]*[Ss]ohbet" server_container.mjs | head -15 | sed 's/^/  /'
grep -noiE "api.anthropic.com|claude-[a-z0-9-]+|ANTHROPIC_API_KEY|model:" server_container.mjs | head -10 | sed 's/^/  /'

hr "2. LLM çağrısı örnek blok (ilk eşleşme çevresi)"
L=$(grep -n "api.anthropic.com\|messages.create\|ANTHROPIC" server_container.mjs | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-8)),$((L+14))p" server_container.mjs | sed 's/^/  /'

hr "3. #113 — LLM taslak + rakam güvenliği deseni (taslak/AI işareti)"
grep -niE "taslak|ai-yaz|llm.yaz|rakam|sayı uydur|prompt" server_container.mjs | grep -iE "llm|taslak|ai|rakam|prompt" | head -12 | sed 's/^/  /'

hr "4. bi_icgoru → ekran: okuyan endpoint"
grep -noE "url.pathname === '[^']*'" server_container.mjs | grep -iE "icgoru|insight|ozet|brief|ana|kart" | head; echo "  --- bi_icgoru select satırları:"
grep -n "bi_icgoru" server_container.mjs | head | sed 's/^/  /'

hr "5. carousel render + icgoru_uret çağrı yeri"
grep -niE "icgoru|surpriz" shells/bi.js | head -10 | sed 's/^/  /'
grep -rn "icgoru_uret_finans" *.sh server_container.mjs 2>/dev/null | head | sed 's/^/  /'

hr "BITTI"
