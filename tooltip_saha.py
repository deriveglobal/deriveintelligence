#!/usr/bin/env python3
# TOOLTIP_SAHA_V1 — Musteri kartinda kart basliklarina ⓘ ipucu (mobil: dokun -> toast aciklama).
# KRB Kiyas + Akilli Fiyat + Finansal basliklarina .saha-help ⓘ + tek delegated dokun-dinleyici. saha.js.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "TOOLTIP_SAHA_V1" in s:
    print("tooltip-saha: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTFIYAT_UI_V1" in s and "SMARTKIYAS_CARD_UI_V1" in s, "gerekli patch'ler yok"

ICON = ('<span class="saha-help" data-help="{H}" style="cursor:pointer;color:#94a3b8;border:1px solid #e2e8f0;'
        'border-radius:50%;width:15px;height:15px;display:inline-flex;align-items:center;justify-content:center;font-size:10px;vertical-align:middle">i</span>')

def icon(h):
    return ICON.replace("{H}", h)

# (1) Tek seferlik dokun-dinleyici (modul kapsami) — musteriDetayModal'dan once
A_fn = "function musteriDetayModal(m) {\n  const [dl, dc] = DURUM_ETIKET[m.durum] || [\"\", \"#999\"];"
assert s.count(A_fn) == 1, "musteriDetayModal anchor"
LISTENER = ('/* TOOLTIP_SAHA_V1 */\n'
            '(function(){ if(window._sahaHelpBound) return; window._sahaHelpBound=1;\n'
            '  document.addEventListener("click", function(e){ var t=e.target; var h=(t && t.closest)?t.closest(".saha-help"):null;\n'
            '    if(h && h.getAttribute("data-help")){ e.stopPropagation(); var msg=h.getAttribute("data-help");\n'
            '      try{ uyari(msg); }catch(_){ try{ alert(msg); }catch(__){} } } });\n'
            '})();\n')
s = s.replace(A_fn, LISTENER + A_fn, 1)

# (2) Akilli Fiyat Onerisi basligi
A_af = '\U0001f3af Akıllı Fiyat Önerisi <small style="font-weight:400;color:#94a3b8;font-size:11px">· başka ebat sorgula</small>'
assert s.count(A_af) == 1, "akilli fiyat baslik anchor"
H_af = "Bu müşteriye, seçtiğin lastik için önerilen fiyat. Şu an ödediği ile önerilen yan yana. Fiyat = maliyet + müşterinin skoru/vadesi/riski + pazar bandı. Rakip kayıtlıysa öneri rakibi geçmez (savun)."
s = s.replace(A_af, '\U0001f3af Akıllı Fiyat Önerisi ' + icon(H_af) + ' <small style="font-weight:400;color:#94a3b8;font-size:11px">· başka ebat sorgula</small>', 1)

# (3) Finansal & Alimlar basligi
A_fin = '<h4 class="bolum-baslik">\U0001f4b0 Finansal & Alımlar</h4>'
assert s.count(A_fin) == 1, "finansal baslik anchor"
H_fin = "Müşterinin ERP finansalları: cari bakiye, vadesi geçmiş, ciro, kredi limiti, net pozisyon. Altında aylık ciro ve Son Alımlar — her üründe 'ödediği → önerilen' fiyat yan yana."
s = s.replace(A_fin, '<h4 class="bolum-baslik">\U0001f4b0 Finansal & Alımlar ' + icon(H_fin) + '</h4>', 1)

# (4) KRB Kiyas basligi (_foKiyas render)
A_kb = "📊 '+esc(d.headline)+'</div>'"
assert s.count(A_kb) == 1, "KRB kiyas headline anchor"
H_kb = "Bu müşteriyi KRB ortalamasıyla kıyaslar: tahsilat, marj, gecikme, büyüme. Kırmızı ⚠ = KRB ortalamasını düşürüyor. Her kötü metriğin yanında yapılacak aksiyon yazar."
s = s.replace(A_kb, "📊 '+esc(d.headline)+' " + icon(H_kb) + "</div>'", 1)

write(FP, s)
print("tooltip-saha: dokun-dinleyici + 3 kart ⓘ ipucu")
print("marker count:", s.count("TOOLTIP_SAHA_V1"))
print("DONE.")
