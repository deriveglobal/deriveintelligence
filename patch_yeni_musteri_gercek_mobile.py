# -*- coding: utf-8 -*-
# YENI_MUSTERI_GERCEK_V1 (mobil) — rp-yeni-mus-kut tile etiketi/tooltip'i gerçek tanıma göre güncellenir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "YENI_MUSTERI_GERCEK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '<div class="rpc-tile" id="rp-yeni-mus-kut" data-tip="Yeni Kayıt: dönemde sisteme ilk kez eklenen FARKLI müşteri (gerçek yeni edinim)."><div class="rpc-num" style="color:#16a34a">${oz.toplam}</div><div class="rpc-lbl">Yeni Kayıt</div></div>'
NEW = '<!--YENI_MUSTERI_GERCEK_V1--><div class="rpc-tile" id="rp-yeni-mus-kut" data-tip="Yeni Müşteri: ilk ziyareti UYGULAMADAN girilen ve Excel yüklemesinde OLMAYAN gerçek yeni saha müşterisi (dönemde). Toplu yüklenen müşteriler sayılmaz."><div class="rpc-num" style="color:#16a34a">${oz.toplam}</div><div class="rpc-lbl">Yeni Müşteri</div></div>'

assert s.count(OLD) == 1, "mobil anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YENI_MUSTERI_GERCEK_V1 (mobil)")
