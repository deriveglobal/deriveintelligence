# -*- coding: utf-8 -*-
# PORTFOY_INTRO_DK_V1 — masaüstü Portföy'e kanonik "ne işe yarar?" intro kartı (üstte).
#   Ev kuralı: her sekme, şirketi tanımayan birinin bile anlayacağı bir açıklama kartı taşır.
#   Dipteki HOW ve kişisel CTX kaldırılır (intro bunları kapsar). Mevcut .pf-how sınıfı — yeni stil yok.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "PORTFOY_INTRO_DK_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)
if "PORTFOY_DK_V1" not in s:
    print("[HATA] önce PORTFOY_DK_V1 olmalı"); sys.exit(1)

old = '    box.innerHTML = CSS + `<div class="pf">${KICK}${CTX}${HERO}${BANDS}${LIST}${REP}${YOK}${HOW}${FOOT}</div>`;'
assert s.count(old) == 1, "assembly anchor=%d" % s.count(old)
new = r'''    const INTRO = `<div class="pf-how" style="margin-bottom:13px">  <!-- PORTFOY_INTRO_DK_V1 -->
      <h4>🩺 Portföy Sağlığı — ne işe yarar?</h4>
      <div>Bir temsilcinin (ya da tüm ekibin) müşteri defterinde <b>kimlerin alımdan kesildiğini</b> ve <b>ne kadar cironun risk altında</b> olduğunu gösterir. Amaç: düzenli alan bir müşteri yavaşlamaya başladığında, <b>tamamen kaybedilmeden önce yakalamak.</b></div>
      <div><b>Ritim</b> = müşterinin son 18 ayda alım yaptığı aylar arası tipik boşluk (kendi alım temposu). <b>Durum</b>, son alımın bu ritme göre neresinde olduğudur — sabit bir "6 ay" eşiği DEĞİL (aylık alan için 3 ay geç kalmak, 6 ayda bir alandan farklıdır).</div>
      <div><span class="lg">🟢 <b>Aktif</b></span> ritminde alıyor · <span class="lg">🟡 <b>Soğuyor</b></span> ritmini geçti, hâlâ yakalanabilir · <span class="lg">🔴 <b>Pasif</b></span> ritmini çok aştı ya da 12+ ay sessiz.</div>
      <div><b>Risk altındaki ciro</b> = soğuyor + pasif müşterilerin son 12 ay cirosu. <b>alım_yok</b> = ERP'de hiç alım eşleşmesi olmayan müşteri (kodsuz / hiç almamış) — <b>churn değil</b>, Kapsam'da kör nokta.</div>
      <div>Eşleşme müşteri koduyla (bi_satis_faturalari); <b>Kapsam listesindeki rozet de aynı tanımı</b> kullanır — tek kaynak.</div></div>`;
    box.innerHTML = CSS + `<div class="pf">${KICK}${INTRO}${HERO}${BANDS}${LIST}${REP}${YOK}${FOOT}</div>`;'''
s = s.replace(old, new, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] PORTFOY_INTRO_DK_V1 — intro kartı üstte, CTX+HOW kaldırıldı")
