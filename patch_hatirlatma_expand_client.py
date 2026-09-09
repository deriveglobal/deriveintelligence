#!/usr/bin/env python3
# HATIRLATMA_EXPAND_V1 (client) — Hata (Ali Kemal Picakci 30/31.07): "Hatirlatmalar telefon
#   uygulamasinda sadece 2 satir onizleme veriyor, kalanini acmiyor."
#   Sebep: Ana ekran (bugun) Hatirlatmalar widget'inda metin n.icerik.slice(0,80) ile sert kesiliyor,
#   kart tiklanabilir degil → uzun hatirlatmanin gerisi hic gorunmuyor. (Notlar sekmesi tam metin gosteriyor, sorun yok.)
#   Fix: tam metin 2 satir CSS clamp ile onizlenir; karta dokun → tam metin acilir/kapanir.
#   Idempotent (marker: HATIRLATMA_EXPAND_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "HATIRLATMA_EXPAND_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# ── 1) Kart render: slice(0,80) yerine tam metin + 2-satir clamp + tiklanabilir ──
old_block = (
'    const hatirlatmaHtml = hatirlatmalar.length\n'
'      ? hatirlatmalar.map(n => `\n'
'          <div class="kart" style="padding:10px 12px;border-left:3px solid #7c3aed;margin-bottom:6px">\n'
'            <div style="font-size:13px;color:#0f172a">${esc(n.icerik.slice(0, 80))}${n.icerik.length > 80 ? "…" : ""}</div>\n'
'            <div style="margin-top:2px">${n.musteri ? `<span style="font-size:11px;color:#0f766e;font-weight:600">🏢 ${esc(n.musteri)}</span>` : ""}${n.hatirlatma_tarihi ? `<span style="font-size:11px;color:#7c3aed;margin-left:${n.musteri ? "8px" : "0"}">⏰ ${n.hatirlatma_tarihi}</span>` : ""}</div>\n'
'          </div>`).join("")\n'
'      : "";'
)
new_block = (
'    const hatirlatmaHtml = hatirlatmalar.length\n'
'      ? hatirlatmalar.map(n => {  /* ' + MARK + ' */\n'
'          const _uzun = (n.icerik || "").length > 80 || /\\n/.test(n.icerik || "");\n'
'          return `\n'
'          <div class="kart hatir-kart" data-hatir-kart style="padding:10px 12px;border-left:3px solid #7c3aed;margin-bottom:6px;cursor:pointer">\n'
'            <div class="hatir-icerik" style="font-size:13px;color:#0f172a;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden;white-space:pre-wrap;word-break:break-word">${esc(n.icerik)}</div>\n'
'            <div style="margin-top:2px">${n.musteri ? `<span style="font-size:11px;color:#0f766e;font-weight:600">🏢 ${esc(n.musteri)}</span>` : ""}${n.hatirlatma_tarihi ? `<span style="font-size:11px;color:#7c3aed;margin-left:${n.musteri ? "8px" : "0"}">⏰ ${n.hatirlatma_tarihi}</span>` : ""}${_uzun ? `<span class="hatir-daha" style="font-size:11px;color:#7c3aed;font-weight:600;margin-left:8px">⌄ devamını gör</span>` : ""}</div>\n'
'          </div>`;\n'
'        }).join("")\n'
'      : "";'
)
if old_block not in src:
    print("HATA: hatirlatmaHtml anchor bulunamadi"); sys.exit(1)
src = src.replace(old_block, new_block, 1)
print("[+] Kart: tam metin + 2-satir clamp + tiklanabilir")

# ── 2) Handler: karta dokun → clamp ac/kapat ──
h_anchor = (
'    // duyuru card → detail\n'
'    main().querySelectorAll("[data-did]").forEach(el =>\n'
'      el.addEventListener("click", () => duyuruDetayModal(el.dataset.did)));'
)
h_new = h_anchor + '''

    // hatirlatma karti → tam metni ac/kapat  (''' + MARK + ''')
    main().querySelectorAll("[data-hatir-kart]").forEach(el =>
      el.addEventListener("click", () => {
        const ic = el.querySelector(".hatir-icerik"); if (!ic) return;
        const acik = ic.style.webkitLineClamp === "unset";
        ic.style.webkitLineClamp = acik ? "2" : "unset";
        const dh = el.querySelector(".hatir-daha");
        if (dh) dh.textContent = acik ? "⌄ devamını gör" : "⌃ kısalt";
      }));'''
if h_anchor not in src:
    print("HATA: duyuru handler anchor bulunamadi"); sys.exit(1)
src = src.replace(h_anchor, h_new, 1)
print("[+] Handler: hatirlatma ac/kapat eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
