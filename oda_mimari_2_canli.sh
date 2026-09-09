#!/usr/bin/env bash
# CANLI bi.js oda yapısı + Finans odası içeriği + /api/bi/finans şekli. SADECE OKUR. Sadece AKTİF dosyalar.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ODA/DEPT LİSTESİ — canlı bi.js'te odalar nasıl tanımlı (dept dizisi)"
grep -nE "data-dept|activeDept|id:.?['\"](bugun|veri|finans|sezon|maliyet|tesvik|ekip)|Sezon|Maliyet|Teşvik|Ekip" shells/bi.js | head -30 | sed 's/^/  /'

hr "2. FİNANS ODASI — canlı bi.js'te 'finans' geçen yerler (bölümler/sekmeler)"
grep -nE "finans|Finans" shells/bi.js | head -30 | sed 's/^/  /'

hr "3. FİNANS içindeki KART/BÖLÜM başlıkları (DSO/alacak/borç/stok/net şu an var mı)"
grep -noE "DSO|[Aa]lacak|[Bb]or[çc]|[Ss]tok|net i̇?[şs]letme|[Cc]iro| tahsil" shells/bi.js | sort | uniq -c | sort -rn | head | sed 's/^/  /'

hr "4. /api/bi/finans — sunucu ne hesaplıyor/döndürüyor (endpoint gövdesi başı)"
L=$(grep -n "/api/bi/finans" server_container.mjs | head -1 | cut -d: -f1)
echo "  endpoint satırı: $L"
if [ -n "$L" ]; then sed -n "${L},$((L+45))p" server_container.mjs | grep -nE "SELECT|FROM|alacak|borc|stok|ciro|dso|hesap_bakiye|tedarikci|json|res\.|=>" | head -30 | sed 's/^/  /'; fi

hr "5. DEPT RENDER — bir odanın içi nasıl çiziliyor (section/sub-tab deseni)"
grep -nE "renderDept|loadDept|dept ===|switch.?\(.?dept|vmo-stab|data-section" shells/bi.js | head -20 | sed 's/^/  /'

hr "6. metrik_gecmis okuyan endpoint VAR MI (yoksa yeni gerekir)"
grep -noE "metrik_gecmis|bi_metrik_gecmis|/api/[a-z/-]*trend[a-z/-]*|/api/[a-z/-]*gecmis" server_container.mjs 2>/dev/null | head | sed 's/^/  /'
echo "  (boşsa: trend için yeni /api/bi/finans-trend endpoint + Finans odasına bölüm gerekir)"

hr "BITTI — Finans odasının GERÇEK yapısı görüldü. Trendin yeri buna göre net."
