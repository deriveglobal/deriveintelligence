#!/usr/bin/env python3
# COLLAPSE_V1 — Kokpit: 🩸 Marj Alarmı ve 🎯 İyileştirme Hedefleri kartlarını KATLANABİLİR yap.
#   Başlığa tıkla → gövde katlanır (yalnız h3 kalır), chevron döner, tercih localStorage'da hatırlanır.
#   Varsayılan AÇIK (mevcut haliyle). Frontend-only: shells/kokpit.html. Idempotent, assert-korumalı.
import sys
FP = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/shells/kokpit.html"
s = open(FP, encoding="utf-8").read()

if "COLLAPSE_V1" in s:
    print("zaten yamali (COLLAPSE_V1), atlandi"); print("DONE."); raise SystemExit

def rep(old, new, tag):
    global s
    assert s.count(old) == 1, "ankor yok/coklu: " + tag + " (n=" + str(s.count(old)) + ")"
    s = s.replace(old, new)
    print("  " + tag + ": ok")

# 1) Marj Alarmı kartı -> collapsible + chevron
rep('<div class="card" style="grid-column:span 12"><h3>🩸 Marj Alarmı',
    '<div class="card collapsible" data-ck="marj" style="grid-column:span 12"><h3><span class="col-cv">▾</span> 🩸 Marj Alarmı',
    "card-marjalarm")

# 2) İyileştirme Hedefleri kartı -> collapsible + chevron
rep('<div class="card" style="grid-column:span 12"><h3>🎯 İyileştirme Hedefleri',
    '<div class="card collapsible" data-ck="kiyas" style="grid-column:span 12"><h3><span class="col-cv">▾</span> 🎯 İyileştirme Hedefleri',
    "card-iyilestirme")

# 3) initCollapse fonksiyonu + tetikleyici (renderBreakdowns'tan once)
FN = '''/* COLLAPSE_V1 — agir kartlari (Marj Alarmi, Iyilestirme) katla; tercih hatirlanir */
function initCollapse(){
  document.querySelectorAll(".card.collapsible").forEach(function(card){
    var h=card.querySelector("h3"); if(!h||h._cl) return; h._cl=1;
    var key="cl_"+(card.getAttribute("data-ck")||"");
    try{ if(localStorage.getItem(key)==="1") card.classList.add("collapsed"); }catch(e){}
    var cv=h.querySelector(".col-cv"); if(cv) cv.textContent=card.classList.contains("collapsed")?"\\u25B8":"\\u25BE";
    h.style.cursor="pointer";
    h.addEventListener("click", function(ev){
      if(ev.target.closest(".i")) return;
      card.classList.toggle("collapsed");
      var c=card.classList.contains("collapsed");
      if(cv) cv.textContent=c?"\\u25B8":"\\u25BE";
      try{ localStorage.setItem(key, c?"1":"0"); }catch(e){}
    });
  });
}
if(document.readyState!=="loading") initCollapse(); else document.addEventListener("DOMContentLoaded", initCollapse);

function renderBreakdowns(){'''
rep("function renderBreakdowns(){", FN, "initCollapse-fn")

# 4) CSS
CSS = '''  /* COLLAPSE_V1 */
  .card.collapsible>h3{cursor:pointer;user-select:none}
  .card.collapsible.collapsed>*:not(h3){display:none}
  .card.collapsible .col-cv{display:inline-block;color:var(--mut);font-size:11px;margin-right:1px}
</style>'''
rep("</style>", CSS, "css")

open(FP, "w", encoding="utf-8").write(s)
print("yamalandi: COLLAPSE_V1 (Marj Alarmı + İyileştirme katlanabilir)")
print("DONE.")
