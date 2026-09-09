# -*- coding: utf-8 -*-
# CIRO_INTRO_V1 (mobil) — Ciro yönetici görünümüne üstten açıklama kartı.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "CIRO_INTRO_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "CIRO_UI6_V1" in s, "HATA: once CIRO_UI6 (mobil) olmali"

css_old = ".zc-empty{color:var(--tx-2);text-align:center;padding:18px;font-size:12px}"
css_new = css_old + ("\n        .zc-intro{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:13px 15px;margin-bottom:12px}"
                     "/*CIRO_INTRO_V1*/"
                     ".zc-intro h3{margin:0 0 6px;font-size:13.5px;font-weight:800;color:var(--tx-0)}"
                     ".zc-intro p{margin:0;font-size:12px;line-height:1.55;color:var(--tx-1)}"
                     ".zc-intro .calc{display:flex;flex-direction:column;gap:5px;margin-top:9px;padding-top:9px;border-top:1px solid var(--cizgi)}"
                     ".zc-intro .calc div{font-size:11.5px;color:var(--tx-1);line-height:1.5}.zc-intro .calc b{color:var(--tx-0)}"
                     ".zc-intro code{background:var(--zemin-2);padding:1px 5px;border-radius:5px;font-size:10.5px}")
assert s.count(css_old) == 1, "css anchor=%d" % s.count(css_old)
s = s.replace(css_old, css_new, 1)

INTRO = ('<div class="zc-intro"><h3>💰 Ciro — ne işe yarar?</h3>'
         '<p>Saha eforunu (ziyaret) ERP sonucuyla (ciro) bağlar: her temsilcinin <b>ziyaret başına gerçek cirosunu</b> ve ekipteki payını gösterir; eşleşmemiş müşterileri görünür kılar.</p>'
         '<div class="calc">'
         '<div><b>Etki ciro</b> = ziyaret edilenin <code>musteri_kodu</code> → satış faturaları (dönem).</div>'
         '<div><b>₺/ziyaret</b> = etki ciro ÷ ziyaret. <b>ERP kapsamı</b> = eşleşen ÷ ulaşılan.</div>'
         '<div><b>Kırılım & ▲/▼</b> = temsilci alanı (Ticari/Tüketici); ₺/ziyaret saha ortalamasıyla kıyas.</div>'
         '</div></div>')
h_old = '<!--CIRO_UI6_V1--><div class="zc">\n          <div class="zc-hero"><div class="l">Toplam etki ciro · dönem</div>'
h_new = '<!--CIRO_UI6_V1--><div class="zc">' + INTRO + '\n          <div class="zc-hero"><div class="l">Toplam etki ciro · dönem</div>'
assert s.count(h_old) == 1, "html anchor=%d" % s.count(h_old)
s = s.replace(h_old, h_new, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CIRO_INTRO_V1 (mobil)")
