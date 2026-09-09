# -*- coding: utf-8 -*-
# MUSTERI_KART_DK2_V1 (Slice 1) — Masaustu musteri karti: dar 640px modal -> GENIS 1060px + 2-KOLON.
#   Sadece LAYOUT: tum element id'leri (md-fin/md-skor/md-fo-q/md-gecmis/md-ai/md-lok...) AYNEN kalir,
#   alttaki JS handler'lari degismez. Header full-genis (ust), 2 kolon (sol: kimlik+skor+finansal,
#   sag: fiyat+ziyaret+AI+lokasyon), aksiyonlar full-genis (alt). (Olaylar timeline + aksiyonlar = Slice 2.)
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "MUSTERI_KART_DK2_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# --- A) style + grid ac + col1 ac (kimlik gridinden hemen once; ERP Kodu satiri benzersiz) ---
OLD_A = ('    <div class="dk-det-grid">\n'
         '      ${satir("ERP Kodu", m.musteri_kodu)}')
NEW_A = ('    <style>/* MUSTERI_KART_DK2_V1 */ #dk-modal .dk-kutu:has(#md-fin){max-width:1060px;padding:22px 26px} '
         '.mk-dk-grid{display:grid;grid-template-columns:1.05fr 1fr;gap:0 30px;align-items:start} '
         '@media(max-width:900px){.mk-dk-grid{grid-template-columns:1fr}} .mk-dk-col{min-width:0}</style>\n'
         '    <div class="mk-dk-grid"><div class="mk-dk-col">\n'
         '    <div class="dk-det-grid">\n'
         '      ${satir("ERP Kodu", m.musteri_kodu)}')
assert s.count(OLD_A) == 1, "A anchor (%d)" % s.count(OLD_A)
s = s.replace(OLD_A, NEW_A, 1)

# --- C) col1 kapat + col2 ac (finansal bittikten sonra) ---
OLD_C = '    <div id="md-fin" class="sub2">Yükleniyor…</div>'
NEW_C = ('    <div id="md-fin" class="sub2">Yükleniyor…</div>\n'
         '    </div><div class="mk-dk-col">')
assert s.count(OLD_C) == 1, "C anchor (%d)" % s.count(OLD_C)
s = s.replace(OLD_C, NEW_C, 1)

# --- D) col2 + grid kapat (aksiyonlardan hemen once) ---
OLD_D = ('    <div id="md-lok" class="sub2">Yükleniyor…</div>\n'
         '    <div class="dk-det-alt">')
NEW_D = ('    <div id="md-lok" class="sub2">Yükleniyor…</div>\n'
         '    </div></div>\n'
         '    <div class="dk-det-alt">')
assert s.count(OLD_D) == 1, "D anchor (%d)" % s.count(OLD_D)
s = s.replace(OLD_D, NEW_D, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_KART_DK2_V1 (genis 2-kolon masaustu kart)")
