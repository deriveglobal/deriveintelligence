# -*- coding: utf-8 -*-
# MUSTERI_KART_DK_V1 — Masaustu saha shell'inde "Müşteri Kartı" modulu stub'tan cikip
#   CANLI olur. Mevcut musteriSec(cb) (musteri-ara modal) + musteriDetay(m) (tam kart: ERP
#   finansal / son alimlar / acik teklifler / ziyaret gecmisi / AI ozet) YENIDEN KULLANILIR
#   (mobil musteriSecModal->musteriDetayModal akisinin masaustu eslesigi). Yeni kod YOK, wire-up.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "MUSTERI_KART_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = ('// diğer modüller — kabuk hazır, canlı bağlanma sırada\n'
       'VIEWS._todo = (m, dest) => {')

NEW = (
'VIEWS.musterikart = async (m) => {  /* MUSTERI_KART_DK_V1 — musteriSec + musteriDetay yeniden kullanim */\n'
'  const ac = () => musteriSec(async (r) => {\n'
'    let c = r;\n'
'    if (r && r.id) { try { const res = await api(`/api/saha/musteriler/${r.id}`); c = res.musteri || res; } catch (e) {} }\n'
'    musteriDetay(c);\n'
'  });\n'
'  m.innerHTML = `<div class="dk-wrap"><div class="dk-card"><div class="dk-empty">\n'
'    <div class="ic">🧾</div><h3>Müşteri Kartı</h3>\n'
'    <p>Bir müşteri seçin — firma bilgileri, ERP finansalları, son alımlar, açık teklifler, ziyaret geçmişi ve AI özeti tek kartta.</p>\n'
'    <button class="dk-btn" id="mk-sec" style="margin-top:14px">🔍 Müşteri Seç</button>\n'
'  </div></div></div>`;\n'
'  m.querySelector("#mk-sec")?.addEventListener("click", ac);\n'
'  ac();\n'
'};\n'
'\n'
'// diğer modüller — kabuk hazır, canlı bağlanma sırada\n'
'VIEWS._todo = (m, dest) => {'
)

assert s.count(OLD) == 1, "anchor bulunamadi (%d)" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_KART_DK_V1 (masaustu musteri karti CANLI)")
