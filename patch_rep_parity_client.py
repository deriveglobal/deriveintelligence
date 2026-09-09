# -*- coding: utf-8 -*-
# REP_PARITE_V1 (client · saha.js musteriDetayModal) — karttaki manager/admin kapılarını kaldırır,
#   böylece saha temsilcisi de yöneticiyle aynı bölümleri görür:
#     Müşteri Skoru, Kıyas, Akıllı Fiyat Önerisi, 'ödediği→önerilen' sütunu, AI Özeti, Mesaj butonu.
#   Sadece rol koşulunu düşürür; m.musteri_kodu gibi veri koşulları korunur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "REP_PARITE_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

def rep(old, new, why):
    global s
    n = s.count(old)
    assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

# 1) mus-skor — rol kapısı kalksın, kodu koşulu kalsın
rep(
    '''    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? '<div id="mus-skor" style="margin:6px 0 10px"></div>' : ""}''',
    '''    ${m.musteri_kodu ? '<div id="mus-skor" style="margin:6px 0 10px"></div>' : ""}  /* REP_PARITE_V1 */''',
    "mus-skor")

# 2) mus-kiyas
rep(
    '''    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? '<div id="mus-kiyas" style="margin:0 0 10px"></div>' : ""}''',
    '''    ${m.musteri_kodu ? '<div id="mus-kiyas" style="margin:0 0 10px"></div>' : ""}  /* REP_PARITE_V1 */''',
    "mus-kiyas")

# 3) Akıllı Fiyat — dış koşuldaki rol kapısı kalksın (backtick + 🎯 details ile eşle)
rep(
    '''${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? `
    <details class="mk mk-acc"><summary>🎯 Akıllı''',
    '''${m.musteri_kodu ? `
    <details class="mk mk-acc"><summary>🎯 Akıllı''',
    "akilli-fiyat")

# 4) AI Özeti — rol kapısı kalksın (hep göster)
rep(
    '''    ${["manager","admin"].includes(S.role) ? `
    <div style="margin:8px 0 4px">
      <button class="btn kucuk cizgili" id="ai-ozet-btn"''',
    '''    ${true ? `
    <div style="margin:8px 0 4px">
      <button class="btn kucuk cizgili" id="ai-ozet-btn"''',
    "ai-ozet")

# 5) Mesaj butonu — hep göster
rep(
    '''      ${["manager","admin"].includes(S.role) ? `<button class="btn cizgili" id="md-mesaj" style="border-color:#0284c7;color:#0284c7">💬 Mesaj</button>` : ""}''',
    '''      ${true ? `<button class="btn cizgili" id="md-mesaj" style="border-color:#0284c7;color:#0284c7">💬 Mesaj</button>` : ""}  /* REP_PARITE_V1 */''',
    "md-mesaj")

# 6) Son Alım 'ödediği → önerilen' — iki rol ternary'si de hep true
rep(
    '''Alım${["manager","admin"].includes(S.role)?' <span style="color:#94a3b8;font-weight:400;text-transform:none">· ödediği → önerilen</span>':''}''',
    '''Alım${true?' <span style="color:#94a3b8;font-weight:400;text-transform:none">· ödediği → önerilen</span>':''}''',
    "son-alim-baslik")
rep(
    '''</div>${["manager","admin"].includes(S.role)?`<div data-fo-oneri="''',
    '''</div>${true?`<div data-fo-oneri="''',
    "son-alim-oneri")

open(F, "w", encoding="utf-8").write(s)
print("[done] REP_PARITE_V1 (client) — 6 kapı kaldirildi")
