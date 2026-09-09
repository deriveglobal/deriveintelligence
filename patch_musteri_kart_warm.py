# -*- coding: utf-8 -*-
# MUSTERI_KART_WARM_V1 (mobil saha.js · musteriDetayModal) — kartı sıcak DS palete çek + firma adı kesik fix.
#   (a) .modal-kutu'ya 'mkc' işaret sınıfı + scrollTop=0. (b) scoped sıcak override (başlık/ayraç/buton) +
#       safe-area-top (firma adı kesik). (c) finansal inline: hücre kremi + bar yeşili. Yalnız bu kartı etkiler.
#   Ön koşul: MUSTERI_KART_OLAYLAR_V1 uygulanmış olmalı.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "MUSTERI_KART_WARM_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)
if "MUSTERI_KART_OLAYLAR_V1" not in s:
    print("[HATA] önce MUSTERI_KART_OLAYLAR_V1 olmalı"); sys.exit(1)

# ── (a+b) scoped sıcak override + safe-area, injected style bloğunun sonuna ──
aS = '      .mk-nf-btn{display:flex;gap:8px;justify-content:flex-end;margin-top:10px}\n    </style>'
assert s.count(aS) == 1, "style anchor=%d" % s.count(aS)
OV = '''      .mk-nf-btn{display:flex;gap:8px;justify-content:flex-end;margin-top:10px}
      /* MUSTERI_KART_WARM_V1 — kart sıcak palet + firma adı kesik fix */
      .modal-kutu.mkc{padding-top:calc(14px + env(safe-area-inset-top,0px)) !important}
      .modal-kutu.mkc h3{color:#16161A !important;font-weight:800}
      .modal-kutu.mkc h4,.modal-kutu.mkc .bolum-baslik{color:#85858C !important;letter-spacing:.08em}
      .modal-kutu.mkc .det-satir{border-bottom-color:rgba(0,0,0,.07) !important}
      .modal-kutu.mkc .det-satir span{color:#85858C !important}
      .modal-kutu.mkc .btn{background:#16161A;border-radius:11px}
      .modal-kutu.mkc .btn.gri{background:#F4F4F2;color:#5F5F66}
      .modal-kutu.mkc .btn.cizgili{background:#fff;color:#16161A;border:1px solid rgba(0,0,0,.14)}
    </style>'''
s = s.replace(aS, OV, 1)

# ── (a) modal-kutu'ya mkc sınıfı + scroll top ──
aB = '  document.getElementById("md-ziyaret")?.addEventListener("click", () => { kapatModal(); ziyaretFormModal(m, "kaydet"); });'
assert s.count(aB) == 1, "md-ziyaret anchor=%d" % s.count(aB)
s = s.replace(aB, '  { const _mkc = document.querySelector("#saha-modal .modal-kutu"); if (_mkc) { _mkc.classList.add("mkc"); _mkc.scrollTop = 0; } }  /* MUSTERI_KART_WARM_V1 */\n' + aB, 1)

# ── (c) finansal inline: hücre kremi (×2), bar yeşili (×1) ──
s = s.replace('background:#f8fafc;border-radius:8px;padding:8px 10px', 'background:#F4F4F2;border-radius:8px;padding:8px 10px')  # replace_all
s = s.replace('background:#38bdf8;border-radius:2px 2px 0 0;height', 'background:#106B4A;opacity:.78;border-radius:2px 2px 0 0;height', 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_KART_WARM_V1 — sıcak palet + safe-area + finansal krem/yeşil")
