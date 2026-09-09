# -*- coding: utf-8 -*-
# YETKI_FAZ1 (client · saha.js) — kart iç bölümlerini matris-tabanlı yap: ["manager","admin"] yerine _yetki("musterikart").
#   _yetki(id): client dept-gate mantığının (_dok ile birebir) üst-seviye hâli → client==server.
#   Ön koşul: YETKI_FAZ0 uygulanmış (kart kapıları manager/admin hâlinde).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

# 1) üst-seviye _yetki yardımcısı (musteriDetayModal'dan önce)
anchor = "function musteriDetayModal(m) {"
assert s.count(anchor) == 1, "musteriDetayModal anchor=%d" % s.count(anchor)
helper = ('/* YETKI_FAZ1 — capability kontrolu: bos departments -> rol fallback (izin), degilse includes. '
          'Client==server ( _dok / _enforceSahaDept ile birebir ). */\n'
          'function _yetki(id) { const d = (S && S.departments) || []; return (!d.length) ? true : d.includes(id); }\n')
s = s.replace(anchor, helper + anchor, 1)

def rep(old, new, why):
    global s
    n = s.count(old)
    assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

# 2) kart kapıları: manager/admin -> _yetki("musterikart")
rep('''${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? '<div id="mus-skor"''',
    '''${(_yetki("musterikart") && m.musteri_kodu) ? '<div id="mus-skor"''', "skor")
rep('''${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? '<div id="mus-kiyas"''',
    '''${(_yetki("musterikart") && m.musteri_kodu) ? '<div id="mus-kiyas"''', "kiyas")
rep('''${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? `
    <details class="mk mk-acc"><summary>🎯 Akıllı''',
    '''${(_yetki("musterikart") && m.musteri_kodu) ? `
    <details class="mk mk-acc"><summary>🎯 Akıllı''', "akilli-fiyat")
rep('''    ${["manager","admin"].includes(S.role) ? `
    <div style="margin:8px 0 4px">
      <button class="btn kucuk cizgili" id="ai-ozet-btn"''',
    '''    ${_yetki("musterikart") ? `
    <div style="margin:8px 0 4px">
      <button class="btn kucuk cizgili" id="ai-ozet-btn"''', "ai-ozet")
rep('''      ${["manager","admin"].includes(S.role) ? `<button class="btn cizgili" id="md-mesaj"''',
    '''      ${_yetki("musterikart") ? `<button class="btn cizgili" id="md-mesaj"''', "mesaj")
rep('''Alım${["manager","admin"].includes(S.role)?' <span style="color:#94a3b8;font-weight:400;text-transform:none">· ödediği → önerilen</span>':''}''',
    '''Alım${_yetki("musterikart")?' <span style="color:#94a3b8;font-weight:400;text-transform:none">· ödediği → önerilen</span>':''}''', "son-alim-baslik")
rep('''</div>${["manager","admin"].includes(S.role)?`<div data-fo-oneri="''',
    '''</div>${_yetki("musterikart")?`<div data-fo-oneri="''', "son-alim-oneri")

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ1 (client) — _yetki + kart kapilari musterikart")
