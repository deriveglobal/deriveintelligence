#!/usr/bin/env python3
# TEXTAREA_AUTOGROW_V1 (client) — Hata (Ali Kemal Picakci 30/31.07): "Text box satir sayisi az ve
#   yazdikca ekran kaymiyor, birkac satir sonrasi ne yazdigini goremiyorsun."
#   Sebep: textarea'lar sabit rows ile kucuk; icerik buyuyunce buyumuyor, caret gorunmuyor.
#   Fix: tum textarea'lar icerige gore otomatik buyur (ust sinir: form 45vh / chat-bar 140px);
#   yazarken/odaklaninca caret gorus alanina kaydirilir (scrollIntoView block:nearest).
#   Baslangic min-yuksekligi (rows) korunur → bos rows=6 kutusu kuculmez. Modal acilinca on-boyutlanir.
#   SpeechRecognition'a bagimli DEGIL (sesGirisBagla iOS'ta erken donuyor). Idempotent (marker: TEXTAREA_AUTOGROW_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "TEXTAREA_AUTOGROW_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# ── 1) Auto-grow blogu: function modal(html) oncesine ekle ──
anchor1 = "function modal(html) {\n  const kok = document.getElementById(\"saha-modal\");"
if anchor1 not in src:
    print("HATA: modal() anchor bulunamadi"); sys.exit(1)
block = '''// ── ''' + MARK + ''' — textarea otomatik buyume + caret gorunur tutma ──
function _sahaTaGrow(ta) {
  if (!ta || ta.tagName !== "TEXTAREA") return;
  if (ta.dataset.agMin == null) ta.dataset.agMin = String(ta.offsetHeight || 0);
  const minH    = Number(ta.dataset.agMin) || 0;
  const compact = ta.style.resize === "none";               // sohbet/yorum barlari
  const cap     = compact ? 140 : Math.round((window.innerHeight || 700) * 0.45);
  ta.style.height = "auto";
  const h = Math.max(minH, Math.min(ta.scrollHeight, cap));
  ta.style.height = h + "px";
  ta.style.overflowY = ta.scrollHeight > cap ? "auto" : "hidden";
}
function _sahaTaAutoGrowBagla(kok) {
  (kok || document).querySelectorAll("textarea").forEach(_sahaTaGrow);
}
if (typeof window !== "undefined" && !window.__sahaTaAutoGrow) {
  window.__sahaTaAutoGrow = 1;
  document.addEventListener("input", function (e) {
    const t = e.target;
    if (t && t.tagName === "TEXTAREA") {
      _sahaTaGrow(t);
      if (t.style.resize !== "none") { try { t.scrollIntoView({ block: "nearest" }); } catch (_) {} }
    }
  }, true);
  document.addEventListener("focusin", function (e) {
    const t = e.target;
    if (t && t.tagName === "TEXTAREA") {
      _sahaTaGrow(t);
      setTimeout(function () { try { t.scrollIntoView({ block: "nearest" }); } catch (_) {} }, 60);
    }
  }, true);
}

'''
src = src.replace(anchor1, block + anchor1, 1)
print("[+] Auto-grow blogu eklendi")

# ── 2) modal() icinde on-boyutlandirma cagrisi ──
anchor2 = "  cipleriBagla(kok);\n  sesGirisBagla(kok);\n}"
if anchor2 not in src:
    print("HATA: modal() sesGirisBagla anchor bulunamadi"); sys.exit(1)
src = src.replace(anchor2, "  cipleriBagla(kok);\n  sesGirisBagla(kok);\n  _sahaTaAutoGrowBagla(kok);  // " + MARK + "\n}", 1)
print("[+] modal() on-boyutlandirma cagrisi eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
