# -*- coding: utf-8 -*-
# YETKI_FAZ0 (client · saha.js) — REP_PARITE_V1 + FIX1'i GERİ AL. Kartı son-iyi hâle (CLEAN_V1 durumu) döndürür:
#   gömülü `true`/kaldırılan kapılar yerine tekrar `["manager","admin"]`. Görünür yorum kalıntıları da temizlenir.
#   (Faz 1'de bu kapılar matris-tabanlı `_dok("musterikart")` ile düzgün kurulacak.)
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "REP_PARITE_V1" not in s and "REP_PARITE_FIX1" not in s:
    print("[skip] REP_PARITE izi yok — zaten temiz"); sys.exit(0)

def rep(old, new, why):
    global s
    n = s.count(old)
    assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

# 1) skor — FIX1 durumundan (HTML yorumlu) son-iyi manager/admin kapısına
rep(
    '''    ${m.musteri_kodu ? '<div id="mus-skor" style="margin:6px 0 10px"></div>' : ""}  <!-- REP_PARITE_V1 FIX1 -->''',
    '''    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? '<div id="mus-skor" style="margin:6px 0 10px"></div>' : ""}''',
    "skor")
# 2) kiyas
rep(
    '''    ${m.musteri_kodu ? '<div id="mus-kiyas" style="margin:0 0 10px"></div>' : ""}  <!-- REP_PARITE_V1 FIX1 -->''',
    '''    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? '<div id="mus-kiyas" style="margin:0 0 10px"></div>' : ""}''',
    "kiyas")
# 3) mesaj butonu
rep(
    '''      ${true ? `<button class="btn cizgili" id="md-mesaj" style="border-color:#0284c7;color:#0284c7">💬 Mesaj</button>` : ""}  <!-- REP_PARITE_V1 FIX1 -->''',
    '''      ${["manager","admin"].includes(S.role) ? `<button class="btn cizgili" id="md-mesaj" style="border-color:#0284c7;color:#0284c7">💬 Mesaj</button>` : ""}''',
    "mesaj")
# 4) Akıllı Fiyat dış koşulu
rep(
    '''${m.musteri_kodu ? `
    <details class="mk mk-acc"><summary>🎯 Akıllı''',
    '''${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? `
    <details class="mk mk-acc"><summary>🎯 Akıllı''',
    "akilli-fiyat")
# 5) AI Özeti
rep(
    '''    ${true ? `
    <div style="margin:8px 0 4px">
      <button class="btn kucuk cizgili" id="ai-ozet-btn"''',
    '''    ${["manager","admin"].includes(S.role) ? `
    <div style="margin:8px 0 4px">
      <button class="btn kucuk cizgili" id="ai-ozet-btn"''',
    "ai-ozet")
# 6) Son Alım başlık ternary
rep(
    '''Alım${true?' <span style="color:#94a3b8;font-weight:400;text-transform:none">· ödediği → önerilen</span>':''}''',
    '''Alım${["manager","admin"].includes(S.role)?' <span style="color:#94a3b8;font-weight:400;text-transform:none">· ödediği → önerilen</span>':''}''',
    "son-alim-baslik")
# 7) Son Alım öneri ternary
rep(
    '''</div>${true?`<div data-fo-oneri="''',
    '''</div>${["manager","admin"].includes(S.role)?`<div data-fo-oneri="''',
    "son-alim-oneri")
# 8) FIX1 dosya-sonu yorumunu kaldır
rep("\n/* REP_PARITE_FIX1 — gorunur sablon yorumlari HTML yorumuna cevrildi */\n", "", "fix1-trailer")

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ0 (client) — REP_PARITE geri alindi, kart son-iyi halde")
