#!/usr/bin/env python3
# HATIRLATMA_TAMAM_V1 (client) — Hata (Ali Kemal Picakci 30/31.07): "Hatirlatmalar surekli uyari
#   veriyor, okundu yapilamiyor." Ana ekran Hatirlatmalar widget'inda tamamla/okundu butonu YOKTU
#   → rep uyariyi gordugu yerden kapatamiyordu (yalniz Notlar/Plan sekmesinde vardi). Push zaten
#   tek-sefer (push_bildirildi), tekrar-push bug'i degil; sorun in-app kapatilamayan uyari.
#   Fix: her hatirlatma kartina "✓" (tamamla) butonu → PUT /api/saha/notlar/:id {tamamlandi:true};
#   kart kaldirilir, bolum rozeti guncellenir, bolum bosalinca gizlenir. Nav badge de duser.
#   HATIRLATMA_EXPAND_V1 kartinin ustune insa eder. Idempotent (marker: HATIRLATMA_TAMAM_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "HATIRLATMA_TAMAM_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# ── 1) Kart: data-hatir-id + "✓" tamamla butonu (flex layout) ──
old_card = '''          return `
          <div class="kart hatir-kart" data-hatir-kart style="padding:10px 12px;border-left:3px solid #7c3aed;margin-bottom:6px;cursor:pointer">
            <div class="hatir-icerik" style="font-size:13px;color:#0f172a;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden;white-space:pre-wrap;word-break:break-word">${esc(n.icerik)}</div>
            <div style="margin-top:2px">${n.musteri ? `<span style="font-size:11px;color:#0f766e;font-weight:600">🏢 ${esc(n.musteri)}</span>` : ""}${n.hatirlatma_tarihi ? `<span style="font-size:11px;color:#7c3aed;margin-left:${n.musteri ? "8px" : "0"}">⏰ ${n.hatirlatma_tarihi}</span>` : ""}${_uzun ? `<span class="hatir-daha" style="font-size:11px;color:#7c3aed;font-weight:600;margin-left:8px">⌄ devamını gör</span>` : ""}</div>
          </div>`;'''
new_card = '''          return `
          <div class="kart hatir-kart" data-hatir-kart data-hatir-id="${n.id}" style="padding:10px 12px;border-left:3px solid #7c3aed;margin-bottom:6px;cursor:pointer;display:flex;gap:10px;align-items:flex-start">
            <div style="flex:1;min-width:0">
              <div class="hatir-icerik" style="font-size:13px;color:#0f172a;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden;white-space:pre-wrap;word-break:break-word">${esc(n.icerik)}</div>
              <div style="margin-top:2px">${n.musteri ? `<span style="font-size:11px;color:#0f766e;font-weight:600">🏢 ${esc(n.musteri)}</span>` : ""}${n.hatirlatma_tarihi ? `<span style="font-size:11px;color:#7c3aed;margin-left:${n.musteri ? "8px" : "0"}">⏰ ${n.hatirlatma_tarihi}</span>` : ""}${_uzun ? `<span class="hatir-daha" style="font-size:11px;color:#7c3aed;font-weight:600;margin-left:8px">⌄ devamını gör</span>` : ""}</div>
            </div>
            <button type="button" class="hatir-ok" data-hatir-tamam="${n.id}" title="Tamamla / okundu" style="flex-shrink:0;background:none;border:2px solid #86efac;border-radius:50%;width:28px;height:28px;min-width:28px;cursor:pointer;color:#16a34a;font-size:15px;line-height:1;padding:0;margin-top:1px">✓</button>
          </div>`;'''
if old_card not in src:
    print("HATA: HATIRLATMA_EXPAND kart anchor bulunamadi (once EXPAND deploy edilmis olmali)"); sys.exit(1)
src = src.replace(old_card, new_card, 1)
print("[+] Kart: ✓ tamamla butonu + data-hatir-id")

# ── 2) Handler: EXPAND ac/kapat handler'inin ardina tamamla handler ──
h_anchor = '''    // hatirlatma karti → tam metni ac/kapat  (HATIRLATMA_EXPAND_V1)
    main().querySelectorAll("[data-hatir-kart]").forEach(el =>
      el.addEventListener("click", () => {
        const ic = el.querySelector(".hatir-icerik"); if (!ic) return;
        const acik = ic.style.webkitLineClamp === "unset";
        ic.style.webkitLineClamp = acik ? "2" : "unset";
        const dh = el.querySelector(".hatir-daha");
        if (dh) dh.textContent = acik ? "⌄ devamını gör" : "⌃ kısalt";
      }));'''
h_new = h_anchor + '''

    // hatirlatma → ✓ tamamla/okundu (uyariyi gordugu yerden kapat)  (''' + MARK + ''')
    main().querySelectorAll("[data-hatir-tamam]").forEach(b =>
      b.addEventListener("click", async (ev) => {
        ev.stopPropagation();
        const id = b.dataset.hatirTamam;
        b.disabled = true; b.style.opacity = ".5";
        try {
          await api(`/api/saha/notlar/${id}`, { method: "PUT", body: JSON.stringify({ tamamlandi: true }) });
          const kart = b.closest(".hatir-kart");
          const blk = kart ? kart.closest(".sec-blk") : null;
          if (kart) kart.remove();
          if (blk) {
            const kalan = blk.querySelectorAll(".hatir-kart").length;
            const bdg = blk.querySelector(".sec-badge");
            if (bdg) { if (kalan) bdg.textContent = String(kalan); else bdg.remove(); }
            if (!kalan) blk.remove();
          }
          uyari("✓ Hatırlatma tamamlandı.", true);
        } catch (e) { b.disabled = false; b.style.opacity = "1"; uyari(e.message); }
      }));'''
if h_anchor not in src:
    print("HATA: EXPAND handler anchor bulunamadi"); sys.exit(1)
src = src.replace(h_anchor, h_new, 1)
print("[+] Handler: ✓ tamamla eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
