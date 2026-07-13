#!/usr/bin/env bash
# Salt okuma. Yamalayacagim 2 yerin TAM metni.
S=/opt/krb-assessment/server_container.mjs

echo "═════════ A) ONAY ANALIZ endpoint (27754 civari) ═════════"
sed -n '27754,27816p' $S

echo
echo "═════════ B) CEO araci: bekleyen_teklifler (25175 civari) ═════════"
sed -n '25175,25215p' $S

echo
echo "═════════ C) teklif listesi endpoint (27642) ═════════"
sed -n '27642,27680p' $S

echo
echo "═════════ D) BI kabugunda onay ekrani var mi? ═════════"
grep -n "analiz\|onay\|Onay" /opt/krb-assessment/shells/bi.js | head -12
echo "  -- saha kabugunda teklif ekrani --"
grep -n "vTeklif\|teklif" /opt/krb-assessment/shells/saha.js | grep -i "function\|analiz" | head -8
