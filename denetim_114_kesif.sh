#!/usr/bin/env bash
# DENETIM_114_KESIF — %7,1 + adet:32000 zinciri. SADECE OKUR.
#   Soru: bu blok API yaniti mi prompt metni mi? %7,1 hangi formulden? adet'ler nereden?
set -uo pipefail
cd /opt/krb-assessment || exit 1
SRC="server_container.mjs"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. BLOK — 24620-24700 tam govde (yapiyi gor)"
sed -n '24620,24700p' "$SRC" | nl -ba -v24620 | sed 's/^/  /'

hr "2. Bu blok HANGI FONKSIYON/UC icinde? (API mi, prompt mi, arac mi)"
awk 'NR<=24646 && /(async )?function |path === |name: |=> *\{/' "$SRC" | tail -4 | sed 's/^/  /'
grep -nE "finansman_maliyeti_pct|adet: 25000|adet: 32000|prim > *%7|ERKEN AL" "$SRC" | sed 's/^/  /'

hr "3. %7,1 formulu — sermaye_maliyeti_pct'ten nasil turer? (2 aylik tasima)"
grep -nE "sermaye_maliyeti|7\.1|finansman_maliyeti|65 gün|2 ay|/12|\* 2" "$SRC" | head -20 | sed 's/^/  /'

hr "4. bi_ayar'dan sermaye_maliyeti_pct kod icinde OKUNUYOR mu? (enjeksiyon icin ornek)"
grep -nE "sermaye_maliyeti_pct|bi_ayar" "$SRC" | grep -iE "SELECT|FROM bi_ayar|sermaye_maliyeti_pct" | head -15 | sed 's/^/  /'

hr "5. adet 25000/32000/40000 — aciklama neye dayaniyor? (2021-22 vs canli)"
sed -n '24644,24650p' "$SRC" | nl -ba -v24644 | sed 's/^/  /'

hr "6. Bu blok kime donuyor? asistan araci mi (tool result), ekran karti mi?"
UN=$(awk 'NR<=24646 && /name: *["'"'"']/{print NR": "$0}' "$SRC" | tail -1)
echo "  en yakin tool tanimi: $UN"
grep -nE "onsiparis|on_siparis|siparis_oner|order.*recommend|erken al" "$SRC" | head -10 | sed 's/^/  /'

hr "BITTI"
echo "  ⚠ Karar: %7,1 -> bi_ayar'dan istek aninda hesapla. adet'ler -> canli satistan mi, config mi?"
