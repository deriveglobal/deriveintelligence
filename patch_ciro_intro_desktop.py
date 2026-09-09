# -*- coding: utf-8 -*-
# CIRO_INTRO_DK_V1 (masaüstü) — Ciro yönetici görünümüne üstten "ne işe yarar + nasıl hesaplanır" açıklaması.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "CIRO_INTRO_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "CIRO_UI6_DK_V1" in s, "HATA: once CIRO_UI6_DK olmali"

# 1) CSS — .zc-intro kurallari (Ciro <style> içindeki .zc-empty'den sonra)
css_old = ".zc-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:13px}"
css_new = css_old + ("\n        .zc-intro{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:15px 17px;margin-bottom:14px}"
                     "/*CIRO_INTRO_DK_V1*/"
                     ".zc-intro h3{margin:0 0 6px;font-size:14px;font-weight:800;color:var(--tx-0)}"
                     ".zc-intro p{margin:0;font-size:12.5px;line-height:1.6;color:var(--tx-1)}"
                     ".zc-intro .calc{display:flex;flex-direction:column;gap:5px;margin-top:9px;padding-top:10px;border-top:1px solid var(--cizgi)}"
                     ".zc-intro .calc div{font-size:12px;color:var(--tx-1);line-height:1.5}.zc-intro .calc b{color:var(--tx-0)}"
                     ".zc-intro code{background:var(--zemin-2);padding:1px 6px;border-radius:5px;font-size:11px}")
assert s.count(css_old) == 1, "css anchor=%d" % s.count(css_old)
s = s.replace(css_old, css_new, 1)

# 2) HTML — yönetici dalının açılışına intro kartı
INTRO = ('<div class="zc-intro"><h3>💰 Ciro — ne işe yarar?</h3>'
         '<p>Saha eforunu (ziyaret) ERP sonucuyla (ciro) bağlar: her temsilcinin <b>ziyaret başına getirdiği gerçek ciroyu</b> ve ekipteki payını gösterir. Amaç eforu sonuca çevirmek ve ERP\'ye bağlı olmayan müşterileri görünür kılıp eşleştirmeye itmektir.</p>'
         '<div class="calc">'
         '<div><b>Etki ciro</b> = ziyaret edilen müşterilerin <code>musteri_kodu</code> → <code>bi_satis_faturalari</code> (dönem cirosu).</div>'
         '<div><b>₺ / ziyaret</b> = etki ciro ÷ ziyaret. <b>ERP kapsamı</b> = eşleşen ÷ ulaşılan (ziyaret edilenin ERP\'ye bağlı oranı).</div>'
         '<div><b>Saha kırılımı & ▲/▼</b> = temsilci alanı (Ticari/Tüketici, Yönetim etiketi); ₺/ziyaret kendi sahasının ortalamasıyla kıyaslanır.</div>'
         '</div></div>')
h_old = '<!--CIRO_UI6_DK_V1--><div class="zc">\n          <div class="zc-grid" style="grid-template-columns:repeat(4,1fr)">'
h_new = '<!--CIRO_UI6_DK_V1--><div class="zc">' + INTRO + '\n          <div class="zc-grid" style="grid-template-columns:repeat(4,1fr)">'
assert s.count(h_old) == 1, "html anchor=%d" % s.count(h_old)
s = s.replace(h_old, h_new, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CIRO_INTRO_DK_V1 (masaüstü)")
