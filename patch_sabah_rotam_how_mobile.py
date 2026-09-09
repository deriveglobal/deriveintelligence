# -*- coding: utf-8 -*-
# SABAH_ROTAM_HOW_V1 (mobil) — rep rotasına katlanır "Rotam nasıl çalışıyor?" paneli (REP DİLİ: kişisel, motive edici).
#   Nasıl sıralanır, öncelik puanı, güne kaç durak, seni nasıl öğrenir, zamanla ne göreceksin, ipucu.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "SABAH_ROTAM_HOW_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "SABAH_ROTAM_V1" in s and "async function rpRotam" in s, "HATA: once mobil SABAH_ROTAM_V1 olmali"

# 1) CSS — katlanır panel (mobil .rt-note'tan sonra)
css_old = ".rt-note{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:16px;text-align:center;color:var(--tx-1);font-size:13px;line-height:1.6}"
css_new = css_old + ("\n      .rt-how{border:1px solid var(--cizgi);border-radius:14px;background:var(--zemin-1);margin-top:14px;overflow:hidden}"  # SABAH_ROTAM_HOW_V1
                     ".rt-how>summary{cursor:pointer;list-style:none;padding:12px 14px;font-size:13px;font-weight:800;color:var(--tx-0);display:flex;align-items:center;gap:8px;-webkit-tap-highlight-color:transparent}"
                     ".rt-how>summary::-webkit-details-marker{display:none}"
                     ".rt-how>summary:after{content:'▾';margin-left:auto;color:var(--tx-2)}"
                     ".rt-how[open]>summary:after{content:'▴'}"
                     ".rt-how-b{padding:2px 14px 14px;font-size:12px;color:var(--tx-1);line-height:1.55}"
                     ".rt-how-b p{margin:0 0 9px}.rt-how-b b{color:var(--tx-0)}"
                     ".rt-how-ip{background:var(--zemin-2);border-radius:9px;padding:9px 11px;margin:2px 0 0}")
assert s.count(css_old) == 1, "css anchor=%d" % s.count(css_old)
s = s.replace(css_old, css_new, 1)

# 2) HOW sabiti — bugunTarih'ten sonra tanımla
b_old = '    const bugunTarih = new Date().toLocaleDateString("tr-TR", { day: "numeric", month: "long", weekday: "long" });'
HOW = (b_old + '\n'
       "    const HOW = `<details class=\"rt-how\"><summary>🔍 Rotam nasıl çalışıyor?</summary>"
       "<div class=\"rt-how-b\">"
       "<p><b>Sıralama:</b> önce <b>senin sözlerin ve bugüne planladıkların</b> (📌), sonra yapay zekânın öne çıkardığı duraklar — en çok kazandıracağın ve en çok riske giren müşteriler üstte.</p>"
       "<p><b>Öncelik puanı (0–100):</b> her müşteriye 🔴 gecikmiş alacağı + 🥶 ne kadardır uğramadığın + 💰 yıllık cirosu + 📋 açık teklifi toplanır. Yükseği önce gelir.</p>"
       "<p><b>Güne kaç durak:</b> sabit sayı yok — başlangıç noktandan mesafeye ve çalışma saatine göre <b>güne sığan kadar</b>; kalanı yarına. Yakın bölgede çok, uzak bölgede az sığar.</p>"
       "<p><b>Seni tanır:</b> her akşam önerdiklerimle gerçekten gittiklerini karşılaştırır, <b>kaç durak yaptığını, ne kadar sürdüğünü, kime gittiğini</b> öğrenir, rotanı sana göre ayarlarım. Ne kadar kullanırsan o kadar isabetli.</p>"
       "<p><b>Zamanla:</b> müşteri konumlarını pinledikçe mesafe/süre netleşir, rota gerçek tempona oturur; sabah açtığında \\\"bugün kime, neden\\\" hazır olur — düşünmeden yola çık.</p>"
       "<p class=\"rt-how-ip\">💡 <b>İpucu:</b> \\\"📍 Konum sabitlenmemiş\\\" gördüğün müşteride bir kez check-in yap; o günden sonra mesafesiyle rotana girer.</p>"
       "</div></details>`;")
assert s.count(b_old) == 1, "bugunTarih anchor=%d" % s.count(b_old)
s = s.replace(b_old, HOW, 1)

# 3) no-start dalı: paneli ekle (bindKart+return'den önce)
n_old = "      bindKart();\n      return;\n    }"
n_new = "      { const _rt = box.querySelector(\".rt\"); if (_rt) _rt.insertAdjacentHTML(\"beforeend\", HOW); }  /* SABAH_ROTAM_HOW_V1 */\n      bindKart();\n      return;\n    }"
assert s.count(n_old) == 1, "no-start anchor=%d" % s.count(n_old)
s = s.replace(n_old, n_new, 1)

# 4) start-set dalı: paneli ekle (son bindKart'tan önce)
e_old = "    bindKart();\n\n    function card(c, rank, cls, sc) {"
e_new = "    { const _rt = box.querySelector(\".rt\"); if (_rt) _rt.insertAdjacentHTML(\"beforeend\", HOW); }  /* SABAH_ROTAM_HOW_V1 */\n    bindKart();\n\n    function card(c, rank, cls, sc) {"
assert s.count(e_old) == 1, "start-set anchor=%d" % s.count(e_old)
s = s.replace(e_old, e_new, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SABAH_ROTAM_HOW_V1 (mobil)")
