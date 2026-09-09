# -*- coding: utf-8 -*-
# KAPSAM_MOB_V3 (saha.js) — dil ısıtma: suçlayıcı değil, motive edici/fırsat odaklı.
#   "uğramadın — o para orada duruyor" (soğuk) → "seni bekliyor — uğradığında bu ciro senin".
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_MOB_V3" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "KAPSAM_MOB_V2" in s, "once KAPSAM_MOB_V2 olmali"

# 1) lead başlık — sıcak
o1 = '<div class="kp-lead-k">💰 ${yon ? "Ekibin karanlıktaki cirosu" : "Karanlıktaki paran"}</div>'
n1 = '<div class="kp-lead-k">💰 ${yon ? "Ekibi bekleyen ciro" : "Seni bekleyen ciro"}</div>  <!-- KAPSAM_MOB_V3 -->'
assert s.count(o1) == 1, "lead-k anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) lead cümle — fırsat odaklı, suçlamasız
o2 = '<div class="kp-lead-p">${(o.beyaz_sayi || 0) > 0 ? `<b>${o.beyaz_sayi}</b> değerli müşteri${yon ? "ye ekip" : "ne"} <b>90 gündür</b> uğra${yon ? "madı" : "madın"} — o para orada duruyor.` : "Değerli müşterilerinin hepsine dokunmuşsun 👏"}</div>'
n2 = '<div class="kp-lead-p">${(o.beyaz_sayi || 0) > 0 ? (yon ? `<b>${o.beyaz_sayi}</b> değerli müşteri bir süredir ekibi bekliyor — uğrandığında bu ciro devreye girer.` : `<b>${o.beyaz_sayi}</b> değerli müşterin bir süredir seni bekliyor — uğradığında bu ciro senin. 💪`) : (yon ? "Ekip tüm değerli müşterilere yetişmiş — tam isabet! 👏" : "Değerli müşterilerinin hepsine yetişmişsin — tam isabet! 👏")}</div>  <!-- KAPSAM_MOB_V3 -->'
assert s.count(o2) == 1, "lead-p anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) lead alt satır — nötr/olumlu fiil
o3 = '<div class="kp-lead-b"><span>📍 Kapsam %${o.kapsam || 0}</span><span class="kp-dot">·</span><span>${o.ulasilan || 0}/${o.portfoy || 0} müşteriye ulaştın</span></div>'
n3 = '<div class="kp-lead-b"><span>📍 Kitabının %${o.kapsam || 0}\'ü canlı</span><span class="kp-dot">·</span><span>${o.ulasilan || 0}/${o.portfoy || 0} müşteri</span></div>  <!-- KAPSAM_MOB_V3 -->'
assert s.count(o3) == 1, "lead-b anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

# 4) bölüm başlığı — davetkâr
o4 = '<div class="kp-sec">${yon ? "En değerli — harekete geçir" : "İşte en değerli · dokun, kapat"}</div>'
n4 = '<div class="kp-sec">${yon ? "En değerliler — önce bunlar" : "Önce şunlar — en çok kazandıracakların"}</div>  <!-- KAPSAM_MOB_V3 -->'
assert s.count(o4) == 1, "sec anchor=%d" % s.count(o4)
s = s.replace(o4, n4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_MOB_V3 (saha.js) — sıcak/motive edici dil")
