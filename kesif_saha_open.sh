#!/usr/bin/env bash
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
S=/opt/krb-assessment/server_container.mjs
J=/opt/krb-assessment/shells/saha.js
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ACIK RAPORLAR (durum=YENI, TAM metin)"
$PSQL -xc "SELECT baslik, mesaj FROM saha_oneri WHERE durum='YENI' ORDER BY ts DESC;"

hr "2. HATIRLATMA / NOTLAR kodu (musteri ismi eksik)"
grep -n "hatirlatma\|hatırlatma\|rep_not\|vNotlarim\|Notlar" "$J" | head -20

hr "3. YENI ZIYARET / autofill (vkn/tc/yetkili gelmiyor)"
grep -n "yeniZiyaret\|ziyaretModal\|vkn\|tc_no\|yetkili\|telefon\|musteriSec\|firmaSec" "$J" | head -25

hr "4. CROSS-REP musteri secim (server + js)"
grep -n "sorumlu_rep\|atanmam\|size atan" "$S" | head -12
grep -n "sorumlu_rep\|musteriSec\|digerRep\|onceki" "$J" | head -12

hr "5. ziyaretler endpoint (yavaslik — sorgu govdesi)"
grep -n "path === \"/api/saha/ziyaretler\"\|/api/saha/ziyaretler'" "$S" | head
