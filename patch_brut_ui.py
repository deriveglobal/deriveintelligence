#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# BRUT_UI_V1 — ekrandaki YANLIS cumleyi duzelt + rakamin NE OLDUGUNU soyle.
#
# ⚠ DUN YAZDIGIM CUMLE YANLIS:
#     "Alış faturasındaki fiyat teşvikleri zaten içinde taşır"
#   FATIH: "Brisa incentive modeliyle calisiyor, KRB primi Brisa'ya FATURA EDIYOR."
#   OLCULDU: PRIM HAKEDISLERI = 33,49M TL (bu yil, 52 satir).
#            Kalem adlari: TIC-SKALA PRIMI Q2, TICARI-TBR SATIS DESTEK PRIM,
#                          TIC-NISAN/MAYIS/HAZIRAN BAYI DESTEK, KAPLAMA DESTEK PRIMI
#            Bayilik negatif marj acigi = 20,12M.
#            33,49M > 20,12M  -> PRIM ACIGI KAPATIYOR (%66 fazlasiyla).
#
#   SONUC: fatura fiyati = BRUT MALIYET. Prim AYRI, gelir olarak kaydediliyor.
#          -> Bu maliyetle hesaplanan marj GERCEK MARJIN ALT SINIRIDIR.
#          -> "KRB zararina satiyor" YANLIS bir okumaydi. Geri aliyorum.
#
# ⚠ TASARIM (Fatih): bu rakam MEVCUT VERIDEN TURETILMIS IKINCI KAYNAK.
#   Tesvik sistemi ayrica kurulacak. Ekran ikisini KARISTIRMAMALI:
#     • liste - tesvik  -> BIRINCIL, net maliyet, gercek marj
#     • fatura fiyati   -> IKINCIL, brut maliyet, marjin ALT SINIRI
#   Hangisine bakildigi HER ZAMAN yazili olacak.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


rep("""        <div style="font-size:11px;color:#b45309;font-weight:700">
          ⚠ Teşvik tablosu eksik — son alış fiyatı kullanıldı: <b>₺${Number(n.fiyat).toLocaleString("tr-TR")}</b>
        </div>
        <div style="font-size:11px;color:#64748b;margin-top:2px">
          ${esc(k.marka || "")} · <b>${esc(urun)}</b> teşviki sisteme yüklenmemiş.<br>
          Alış faturasındaki fiyat <b>teşvikleri zaten içinde taşır</b> (bayiye kesilen
          net fiyat = liste − teşvik), o yüzden maliyeti biliyoruz. Kaynak:
          ${esc(tar)} · ${n.gun_once} gün önce${n.tedarikci ? " · " + esc(n.tedarikci) : ""}.
          ${n.bayat ? `<br><span style="color:#b45309">Bu fiyat ${n.gun_once} günlük — zam gelmişse marj olduğundan yüksek görünür.</span>` : ""}
          <br>Teşvik tablosu yüklenirse hesap otomatik olarak liste−teşvike geçer.
        </div>""",
"""        <div style="font-size:11px;color:#b45309;font-weight:700">
          ⚠ BRÜT maliyet — <b>₺${Number(n.fiyat).toLocaleString("tr-TR")}</b> · prim hariç
        </div>
        <div style="font-size:11px;color:#64748b;margin-top:2px">
          <b>Bu rakam ne:</b> ${esc(k.marka || "")} · ${esc(urun)} için teşvik tablosu
          henüz yüklenmedi. Bu maliyet, <b>KRB'nin kendi alış faturasından türetildi</b>
          (${esc(tar)} · ${n.gun_once} gün önce${n.tedarikci ? " · " + esc(n.tedarikci) : ""}).<br>
          <b>Bu rakam ne DEĞİL:</b> nihai maliyet. Brisa/Continental teşvik modeliyle
          çalışıyor; <b>primi KRB ayrıca fatura ediyor</b>, alış faturasına girmiyor.
          Bu yıl <b>33,5M TL prim hakedişi</b> kesilmiş. Yani gerçek maliyet
          <b>bundan düşük</b>.<br>
          <b>Sonuç:</b> aşağıdaki marj <b>gerçek marjın ALT SINIRIDIR</b> — gerçeği
          daha iyidir. Negatif görünmesi zarar demek değildir.
          ${n.bayat ? `<br><span style="color:#b45309">Ayrıca bu fiyat ${n.gun_once} günlük.</span>` : ""}
          <br><span style="color:#0369a1">Teşvik tablosu yüklendiğinde hesap otomatik olarak
          liste−teşvike (net maliyet) geçer ve bu uyarı kalkar.</span>
        </div>""",
    "brut-metin")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
