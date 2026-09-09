#!/usr/bin/env bash
# Finans odası ne gösteriyor + ok-navigasyonlu carousel var mı + /api/bi/ana içeriği. OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi.js: 'içgörü/bulgu/kâr sız/akıllı/kart' benzeri bölümler"
grep -niE "bulgu|kâr sız|kar siz|sızıntı|akıllı kart|akilli|öneri kart|insight|carousel|kaydır|swipe|slayt|slide" shells/bi.js | head -20 | sed 's/^/  /'

hr "2. bi.js: ok/index navigasyonu (carousel deseni: idx++/idx--/currentSlide)"
grep -niE "idx\+\+|idx--|_idx|aktifKart|currentSlide|slideIndex|goNext|goPrev|showCard\(" shells/bi.js | head -15 | sed 's/^/  /'

hr "3. server /api/bi/ana handler — içinde içgörü/kâr sızıntısı var mı (40 satır)"
L=$(grep -n "url.pathname === '/api/bi/ana'" server_container.mjs | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L)),$((L+45))p" server_container.mjs | sed 's/^/  /'

hr "4. Finans odası ana çizim fonksiyonu (ilk ekranda ne var)"
grep -niE "finansCiz|renderFinans|finansAna|_finansGoster|function.*[Ff]inans" shells/bi.js | head -12 | sed 's/^/  /'

hr "BITTI — insight'lar nerede/ nasıl gösteriliyor netleşince doğru yere bağlarım."
