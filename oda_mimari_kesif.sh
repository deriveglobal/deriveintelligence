#!/usr/bin/env bash
# ODA MİMARİSİ KEŞİF — yeni anasayfa/oda yapısı: Bugün/Veri/Finans + bekleyenler. Trend NEREYE girer? SADECE OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. SHELL DOSYALARI — /shells altında ne var (oda başına dosya?)"
ls -la shells/ 2>/dev/null | sed 's/^/  /'

hr "2. ODA TANIMLARI — Bugün/Veri/Finans/Sezon/Maliyet/Teşvik/Ekip nerede tanımlı"
grep -rnE "Bugün|Bugun|Finans|Sezon|Maliyet|Teşvik|Tesvik|Ekip|'Veri'|\"Veri\"|oda|room" shells/ app.js index.html 2>/dev/null | grep -iE "oda|room|Finans|Sezon|Maliyet|Teşvik|Ekip|title|label|menu|tab" | head -40 | sed 's/^/  /'

hr "3. ANASAYFA / ODA YÖNLENDİRME — hangi dosya odaları çiziyor (home/anasayfa shell)"
ls -la shells/ 2>/dev/null | grep -iE "home|anasayfa|oda|room|finans|index" | sed 's/^/  /'
grep -rln "Finans" shells/ 2>/dev/null | sed 's/^/  /'

hr "4. FİNANS ODASI İÇERİĞİ — şu an ne gösteriyor (ilk 60 satır ilgili shell)"
FSHELL=$(grep -rln "Finans" shells/ 2>/dev/null | head -1)
echo "  finans shell adayı: $FSHELL"
if [ -n "$FSHELL" ]; then grep -nE "Finans|DSO|alacak|borc|stok|ciro|metrik|title|section|tab|card" "$FSHELL" 2>/dev/null | head -30 | sed 's/^/  /'; fi

hr "5. SUNUCUDA ODA ENDPOINT'LERİ — /api altında finans/metrik var mı"
grep -noE "/api/[a-zA-Z0-9_/-]*(finans|metrik|dso|alacak|stok|ciro)[a-zA-Z0-9_/-]*" server_container.mjs 2>/dev/null | head -20 | sed 's/^/  /'

hr "6. app.js — oda listesi / navigasyon tanımı (shell import sırası)"
grep -nE "shells/|import|oda|room|Finans|Veri|Bugün|Bugun" app.js 2>/dev/null | head -30 | sed 's/^/  /'

hr "BITTI — oda mimarisi + Finans içeriği görülünce trendin YERİ net konuşulur (varsaymadan)."
