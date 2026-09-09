# -*- coding: utf-8 -*-
# KAPSAM_MOB_V4 (saha.js) — (a) dürüst dil: "bu ciro senin" OVER-PROMISE kaldırıldı; rakam
#   = müşterinin son 12 ay cirosu (gerçek), vaat değil. (b) kompakt/temiz aksiyon butonları
#   (tam-genişlik dev bar YOK); 🔇 -> "Sustur" (emoji render sorunu).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_MOB_V4" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "KAPSAM_MOB_V3" in s, "once KAPSAM_MOB_V3 olmali"

# 1) aksiyon butonları: kompakt, sağa hizalı, içerik-genişlik
o1 = '''      .kp-acts{display:flex;gap:6px;margin-top:10px}
      .kp-act{flex:1;text-align:center;font-size:12px;font-weight:700;padding:9px 6px;border-radius:9px;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);font-family:inherit;cursor:pointer}
      .kp-act.pri{background:var(--tx-0);color:#fff;border-color:var(--tx-0)}.kp-act.ok{background:var(--yesil-z);color:var(--yesil);border-color:rgba(16,107,74,.25)}.kp-act.dis{flex:0 0 46px;background:var(--kirmizi-z);color:var(--kirmizi);border-color:rgba(196,61,40,.2)}.kp-act.esles{background:var(--mor-z);color:var(--mor);border-color:rgba(109,90,224,.25)}'''
n1 = '''      .kp-acts{display:flex;gap:7px;margin-top:11px;justify-content:flex-end;align-items:center;flex-wrap:wrap}  /* KAPSAM_MOB_V4 */
      .kp-act{flex:0 0 auto;font-size:12.5px;font-weight:600;padding:8px 13px;border-radius:8px;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);font-family:inherit;cursor:pointer;line-height:1}
      .kp-act.pri{background:var(--tx-0);color:#fff;border-color:var(--tx-0)}.kp-act.ok{background:var(--zemin-1);color:var(--tx-1);border-color:var(--cizgi)}.kp-act.dis{padding:8px 11px;background:transparent;color:var(--tx-2);border-color:transparent;font-weight:500}.kp-act.esles{background:var(--mor-z);color:var(--mor);border-color:rgba(109,90,224,.25)}'''
assert s.count(o1) == 1, "css anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) lead başlık — nötr/dürüst
o2 = '<div class="kp-lead-k">💰 ${yon ? "Ekibi bekleyen ciro" : "Seni bekleyen ciro"}</div>  <!-- KAPSAM_MOB_V3 -->'
n2 = '<div class="kp-lead-k">💰 Ziyaret edilmemiş · değerli müşteri cirosu</div>  <!-- KAPSAM_MOB_V4 -->'
assert s.count(o2) == 1, "lead-k anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) lead cümle — vaat YOK; rakam = son 12 ay cirosu (gerçek), karar rep'in
o3 = '<div class="kp-lead-p">${(o.beyaz_sayi || 0) > 0 ? (yon ? `<b>${o.beyaz_sayi}</b> değerli müşteri bir süredir ekibi bekliyor — uğrandığında bu ciro devreye girer.` : `<b>${o.beyaz_sayi}</b> değerli müşterin bir süredir seni bekliyor — uğradığında bu ciro senin. 💪`) : (yon ? "Ekip tüm değerli müşterilere yetişmiş — tam isabet! 👏" : "Değerli müşterilerinin hepsine yetişmişsin — tam isabet! 👏")}</div>  <!-- KAPSAM_MOB_V3 -->'
n3 = '<div class="kp-lead-p">${(o.beyaz_sayi || 0) > 0 ? `Bu <b>${o.beyaz_sayi}</b> müşterinin son 12 aylık cirosu. Cirosu yüksek ama son 90 günde ziyaret edilmemişler — öncelik vermek istersen buradan.` : (yon ? "Ekip tüm değerli müşterileri ziyaret etmiş." : "Tüm değerli müşterilerini ziyaret etmişsin.")}</div>  <!-- KAPSAM_MOB_V4 -->'
assert s.count(o3) == 1, "lead-p anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

# 4) lead alt satır
o4 = '<div class="kp-lead-b"><span>📍 Kitabının %${o.kapsam || 0}\'ü canlı</span><span class="kp-dot">·</span><span>${o.ulasilan || 0}/${o.portfoy || 0} müşteri</span></div>  <!-- KAPSAM_MOB_V3 -->'
n4 = '<div class="kp-lead-b"><span>📍 Kitabının %${o.kapsam || 0}\'i ziyaret edildi</span><span class="kp-dot">·</span><span>${o.ulasilan || 0}/${o.portfoy || 0} müşteri</span></div>  <!-- KAPSAM_MOB_V4 -->'
assert s.count(o4) == 1, "lead-b anchor=%d" % s.count(o4)
s = s.replace(o4, n4, 1)

# 5) bölüm başlığı — nötr
o5 = '<div class="kp-sec">${yon ? "En değerliler — önce bunlar" : "Önce şunlar — en çok kazandıracakların"}</div>  <!-- KAPSAM_MOB_V3 -->'
n5 = '<div class="kp-sec">En yüksek cirolu müşteriler${yon ? "" : "n"}</div>  <!-- KAPSAM_MOB_V4 -->'
assert s.count(o5) == 1, "sec anchor=%d" % s.count(o5)
s = s.replace(o5, n5, 1)

# 6) 🔇 -> "Sustur" (kart aksiyon butonu etiketi; render sorunu + netlik).
#    Reason-picker'daki "🔇 Sustur" (metinli) eşleşmez.
o6 = '>🔇</button>'
n6 = '>Sustur</button>'
c = s.count(o6)
assert c >= 1, "sustur anchor=%d" % c
s = s.replace(o6, n6)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_MOB_V4 (saha.js) — dürüst dil + kompakt butonlar (%d sustur)" % c)
