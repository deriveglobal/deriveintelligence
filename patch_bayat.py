#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# BAYAT_V2 — 13 Temmuz gecesi ERP tamamen yuklendikten SONRA.
#
# Iki metin artik YALAN soyluyor ve ikisi de Fatih Bilen'in yuzune cikacak:
#
#   1) BILINEN_SORUNLAR: "ERP 29 GUNDUR OLU ... sistem 69.1M gosteriyor"
#      -> ERP yuklendi. 6 yil, 364.785 satis + 146.680 alis satiri.
#         Haziran 2026 = 121,76M — Fatih Bilen'in 09.07'de verdigi 121,79M.
#
#   2) BRISA_V1 brifingi: "hala BOZUK olani ILK soyle: ERP olu, ciro eksik"
#      -> Fatih Bilen bunu HENUZ GORMEDI. Metin, sistem hala bozukken
#         yazilmisti. Simdi hikaye degisti: soz verildi VE tutuldu.
#         Sakanin ("Brisa'li gibi konusursun, sonuc gelmez") artik bir cevabi var.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# ── 1) BILINEN_SORUNLAR — bayat ERP uyarisi
rep("""                'ERP AKTARIMI 29 GUNDUR OLU. Ciro/stok/bakiye rakamlari EKSIK. ' +
                'Fatih Bilen 09.07\\'de "haziran cirosu 121.79M" dedi; sistem 69.1M gosteriyor (~yarisi). ' +
                'Bu, pilotun 1 numarali riskidir — temsilciler Pazartesi bir aylik eski bakiye/stok gorecek.',""",
"""                'ERP VERISI 13.07 GECESI TAMAMEN YENIDEN YUKLENDI (BAYAT_V2). ' +
                'Satis: 364.785 satir (2021-10 .. 2026-07). Alis: 146.680 satir. ' +
                'Haziran 2026 cirosu = 121,76 M TL — Fatih Bilen\\'in 09.07\\'de soyledigi 121,79M ile ORTUSUYOR. ' +
                'ESKI SORUN NEYDI: (a) SAP tarihleri GG/AA yazar, Excel AA/GG okuyordu; gunu <=12 olan ' +
                'faturalar Agustos-Aralik\\'a savruluyordu — Haziran yarim gorunuyordu. (b) Export SADECE ' +
                'lastik kalem gruplarini iceriyordu; servis/jant/aku/yedek parca (cironun ~%26\\'si) hic yoktu. ' +
                'IKISI DE DUZELTILDI. Artik ciro rakamlarina guvenilebilir.',
                'ALIS VADESI ARTIK HESAPLANIYOR: onceden 28.252 satirin TAMAMINDA vade_tarihi NULL\\'du. ' +
                'Ortalama alis vadesi 2021\\'de 66,7 gun iken 2025\\'te 40,7 gune dusmus — tedarikciler ' +
                'KRB\\'nin vadesini 4 yilda 26 gun kismis. Bu, sistemin ilk kez gorebildigi bir sey.',""",
    "bilinen-sorunlar")

# ── 2) BRISA brifingi — "hala bozuk" premisi artik yanlis
rep("""2) SONRA HEMEN DURUSTLUK — hala BOZUK olani ILK soyle:
   ERP aktarimi 30 gundur olu. Ciro rakamin EKSIK: sistem ~69,1M gosteriyor,
   o 121,79M biliyor. "Bu duzelene kadar benden ciro/stok rakami almayin" de.
   Bunu ESPRIYLE gecistirme. En zor cumle bu, ve ilk soylenmeli.""",
"""2) SONRA: SOZ VERILDI VE TUTULDU — ama once NE OLDUGUNU durustce soyle.
   O sana "haziran cirosu 121,79M" dedi; sistem 19M gosteriyordu. Ben o zaman
   "ERP akisi olmus" diye TESHIS KOYDUM ve YANILDIM. Gercek sebep baskaydi:
   • SAP tarihi GG/AA yazar, Excel AA/GG okudu. 10/02 (10 Subat) -> 2 Ekim oldu.
     Gunu 12'den kucuk olan faturalar Agustos-Aralik'a savruldu. Haziran'in
     yarisi kayboldu — veri hep oradaydi, YANLIS AYA yazilmisti.
   • Ayrica export SADECE lastik kalemlerini iceriyordu. Servis, jant, aku,
     yedek parca — cironun dortte biri — sisteme HIC girmemisti.
   Ikisi de duzeltildi. 6 yil yeniden yuklendi: 364.785 satis satiri.
   HAZIRAN 2026 = 121,76 M TL. Senin rakamin. Artik ayni seyi konusuyoruz.

   Bunu ovunerek degil, HESAP VERIR gibi soyle. Yanlis teshis koydugunu da
   sakla-ma. Onemli olan: bu sefer konusmadi, YAPILDI.""",
    "brisa-brifing-guncel")

# ── 3) Brisa brifinginin kapanisi da "soz veriyorum" diyordu; artik "yapildi"
rep("""4) KAPAT: bugun ne yapmak istedigini sor. Kucuk bir soz ver:
   "bakiyorum deyip kaybolmayacagim" gibi — ama kendi cumlenle.""",
"""4) KAPAT: bugun ne yapmak istedigini sor.
   Soz VERME — soz vermeyi zaten cok yaptin. Bunun yerine kontrol etmesini iste:
   "Haziran'i sor bana. 121,76 diyorsam dogrudur; degilse yuzume vur."
   Kendi cumlenle kur, ama TON bu olsun: guven talep etme, DOGRULANMAYI iste.""",
    "brisa-kapanis")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
