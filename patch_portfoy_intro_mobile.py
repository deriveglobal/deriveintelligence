# -*- coding: utf-8 -*-
# PORTFOY_INTRO_MOB_V1 — mobil Portföy'e kanonik "ne işe yarar?" intro kartı (üstte, kompakt).
#   Dipteki HOW ve kişisel CTX kaldırılır (intro kapsar). Mevcut .pf-how sınıfı — yeni stil yok.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "PORTFOY_INTRO_MOB_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)
if "PORTFOY_MOB_V1" not in s:
    print("[HATA] önce PORTFOY_MOB_V1 olmalı"); sys.exit(1)

old = '    box.innerHTML = CSS + `<div class="pf">${KICK}${CTX}${HERO}${BANDS}${LIST}${YOK}${HOW}${FOOT}</div>`;'
assert s.count(old) == 1, "assembly anchor=%d" % s.count(old)
new = r'''    const INTRO = `<div class="pf-how" style="margin-bottom:11px">  <!-- PORTFOY_INTRO_MOB_V1 -->
      <h4>🩺 Portföy Sağlığı — ne işe yarar?</h4>
      <div>Defterinde <b>kimin alımdan kesildiğini</b> ve <b>ne kadar cironun risk altında</b> olduğunu gösterir. Amaç: yavaşlayan müşteriyi <b>kaybetmeden yakalamak.</b></div>
      <div><b>Ritim</b> = son 18 ayda alım aylarının tipik boşluğu (kendi temposu). Durum bu ritme göredir — sabit "6 ay" eşiği değil.</div>
      <div>🟢 <b>Aktif</b> ritminde · 🟡 <b>Soğuyor</b> geçti (yakalanabilir) · 🔴 <b>Pasif</b> çok aştı / 12+ ay.</div>
      <div><b>Risk cirosu</b> = soğuyor+pasif son 12 ay. <b>alım_yok</b> = ERP eşleşmesi yok — churn değil, Kapsam kör noktası. Kapsam rozeti aynı tanımı kullanır.</div></div>`;
    box.innerHTML = CSS + `<div class="pf">${KICK}${INTRO}${HERO}${BANDS}${LIST}${YOK}${FOOT}</div>`;'''
s = s.replace(old, new, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] PORTFOY_INTRO_MOB_V1 — intro kartı üstte, CTX+HOW kaldırıldı")
