# -*- coding: utf-8 -*-
# MUSTERI_KART_CLEAN_V1 (mobil saha.js · musteriDetayModal) — kartı beğenilen sade mock'a çek.
#   Sorun: OLAYLAR+WARM üst istihbaratı EKLEDİ ama tüm eski ağır bölümler altta kaldı → kart "eskisiyle aynı".
#   Çözüm (hiçbir şey silinmez, hiçbir şey gömülmez):
#     (a) firma adı kesik fix → env() yerine SABİT üst boşluk (iOS'ta viewport-fit=cover yok, env=0 dönüyor).
#     (b) ikincil bölümler <details> ile VARSAYILAN KAPALI akordeona sarılır → kart mock gibi sade açılır:
#         intel → takip → Tip/Durum/ERP → [Müşteri detayı & düzenle] → 💰 Finansal → [🎯 Akıllı Fiyat]
#         → Hareketler → AI → [📍 Lokasyonlar] → butonlar.  Dokunulunca açılır; veri/loader aynen çalışır.
#   Ön koşul: MUSTERI_KART_WARM_V1 uygulanmış olmalı.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "MUSTERI_KART_CLEAN_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)
if "MUSTERI_KART_WARM_V1" not in s:
    print("[HATA] önce MUSTERI_KART_WARM_V1 olmalı"); sys.exit(1)

def rep(old, new, why):
    global s
    n = s.count(old)
    assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

# ── (a) firma adı kesik fix: env() yerine sabit taban (max ile notch'ta da doğru) ──
rep(
    ".modal-kutu.mkc{padding-top:calc(14px + env(safe-area-inset-top,0px)) !important}",
    ".modal-kutu.mkc{padding-top:max(46px, calc(14px + env(safe-area-inset-top,0px))) !important}  /* MUSTERI_KART_CLEAN_V1 sabit taban */",
    "name-fix")

# ── (b) akordeon CSS (scoped style bloğunun sonuna; vars .mk üstünden gelir) ──
ACC = '''      .modal-kutu.mkc .btn.cizgili{background:#fff;color:#16161A;border:1px solid rgba(0,0,0,.14)}
      /* MUSTERI_KART_CLEAN_V1 — sade akordeon (ikincil bölümler varsayılan kapalı) */
      .mk-acc{border:1px solid var(--cz);border-radius:12px;margin:0 0 11px;background:var(--z0);overflow:hidden}
      .mk-acc>summary{list-style:none;cursor:pointer;padding:11px 13px;font-size:11px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;color:var(--t2);display:flex;align-items:center;justify-content:space-between;gap:10px}
      .mk-acc>summary::-webkit-details-marker{display:none}
      .mk-acc>summary::after{content:"▾";color:var(--t3);font-size:12px}
      .mk-acc[open]>summary::after{content:"▴"}
      .mk-acc[open]>summary{border-bottom:1px solid var(--cz)}
      .mk-acc>*:not(summary){margin-left:13px;margin-right:13px}
      .mk-acc>*:not(summary):first-of-type{margin-top:10px}
      .mk-acc>*:last-child{margin-bottom:12px}
    </style>'''
rep(
    '''      .modal-kutu.mkc .btn.cizgili{background:#fff;color:#16161A;border:1px solid rgba(0,0,0,.14)}
    </style>''',
    ACC, "acc-css")

# ── (b1) "Müşteri detayı & düzenle": ERP Kodu satırından SONRA aç, mus-kiyas'tan SONRA kapat ──
rep(
    '    ${m.musteri_kodu ? `<div class="det-satir"><span>ERP Kodu</span><b>${esc(m.musteri_kodu)}</b></div>` : ""}',
    '    ${m.musteri_kodu ? `<div class="det-satir"><span>ERP Kodu</span><b>${esc(m.musteri_kodu)}</b></div>` : ""}\n    <details class="mk mk-acc"><summary>Müşteri detayı &amp; düzenle</summary>  <!-- MUSTERI_KART_CLEAN_V1 -->',
    "detay-open")
rep(
    '''    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? '<div id="mus-kiyas" style="margin:0 0 10px"></div>' : ""}''',
    '''    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? '<div id="mus-kiyas" style="margin:0 0 10px"></div>' : ""}\n    </details>  <!-- /MUSTERI_KART_CLEAN_V1 detay -->''',
    "detay-close")

# ── (b2) "🎯 Akıllı Fiyat Önerisi": h4'ü summary yap, mus-fiyat kapanışından sonra </details> ──
FIYAT_H4 = '    <h4 class="bolum-baslik">🎯 Akıllı Fiyat Önerisi <span class="saha-help" data-help="Bu müşteriye, seçtiğin lastik için önerilen fiyat. Şu an ödediği ile önerilen yan yana. Fiyat = maliyet + müşterinin skoru/vadesi/riski + pazar bandı. Rakip kayıtlıysa öneri rakibi geçmez (savun)." style="cursor:pointer;color:#94a3b8;border:1px solid #e2e8f0;border-radius:50%;width:15px;height:15px;display:inline-flex;align-items:center;justify-content:center;font-size:10px;vertical-align:middle">i</span> <small style="font-weight:400;color:#94a3b8;font-size:11px">· başka ebat sorgula</small></h4>'
rep(FIYAT_H4,
    '    <details class="mk mk-acc"><summary>🎯 Akıllı Fiyat Önerisi</summary>  <!-- MUSTERI_KART_CLEAN_V1 -->',
    "fiyat-open")
rep(
    '      <div id="fo-kart" style="margin-top:10px"></div>\n    </div>',
    '      <div id="fo-kart" style="margin-top:10px"></div>\n    </div></details>  <!-- /MUSTERI_KART_CLEAN_V1 fiyat -->',
    "fiyat-close")

# ── (b3) "📍 Lokasyonlar": h4'ü summary yap, lok-ekle butonundan sonra kapat ──
rep(
    '    <h4 class="bolum-baslik">Lokasyonlar</h4>',
    '    <details class="mk mk-acc"><summary>📍 Lokasyonlar</summary>  <!-- MUSTERI_KART_CLEAN_V1 -->',
    "lok-open")
rep(
    '    <button class="btn kucuk cizgili" id="lok-ekle">＋ Lokasyon Ekle</button>',
    '    <button class="btn kucuk cizgili" id="lok-ekle">＋ Lokasyon Ekle</button>\n    </details>  <!-- /MUSTERI_KART_CLEAN_V1 lok -->',
    "lok-close")

open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_KART_CLEAN_V1 — sabit üst boşluk + 3 akordeon (detay/fiyat/lokasyon kapalı)")
