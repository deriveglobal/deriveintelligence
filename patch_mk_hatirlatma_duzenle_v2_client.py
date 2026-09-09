#!/usr/bin/env python3
# MUSTERI_HATIRLATMA_DUZENLE_V2 (client) — DUZELTME: V1'de duzenleme modali `modal()` ile aciliyordu;
#   `modal()` tek `#saha-modal` konteynerinin innerHTML'ini EZIYOR → alttaki Musteri Karti kayboluyor,
#   modal kapaninca (kapatModal) her sey siliniyor, geri donus yok (Fatih: "customer card disappear").
#   Fix: V1 _mkHatDuzenle fonksiyonunu, karti EZMEYEN katmanli overlay ile degistir — #saha-modal'a
#   ikinci bir .modal-fon child EKLE (z-index:70), kapaninca yalniz kendini kaldir; kart altta kalir,
#   PUT sonrasi _mkYukle() kartin Hareketler'ini yerinde yeniler.
#   Idempotent (marker: MUSTERI_HATIRLATMA_DUZENLE_V2). Onkosul: V1 client uygulanmis olmali.
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "MUSTERI_HATIRLATMA_DUZENLE_V2"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old_fn = '''    function _mkHatDuzenle(o) {  /* MUSTERI_HATIRLATMA_DUZENLE_V1 */
      const kapandi = !!o.skapandi;
      modal(`
        <h3>${kapandi ? "Hatırlatma (tamamlandı)" : "Hatırlatmayı Düzenle"}</h3>
        <label>Not
          <textarea class="giris" id="mkd-metin" rows="4">${esc(String(o.sozet || ""))}</textarea>
        </label>
        <label style="margin-top:10px;display:block">Takip tarihi
          <input type="date" class="giris" id="mkd-tarih" value="${o.stakip || ""}">
        </label>
        <div class="modal-btnlar" style="flex-wrap:wrap;gap:8px">
          <button class="btn gri" data-kapat>Vazgeç</button>
          ${kapandi
            ? `<button class="btn" id="mkd-geriac">↩︎ Geri Aç</button>`
            : `<button class="btn" id="mkd-tamam" style="background:#106B4A;color:#fff">✓ Tamamlandı</button>`}
          <button class="btn" id="mkd-kaydet">Kaydet</button>
        </div>`);
      const put = async (body, msg) => {
        try {
          await api(`/api/saha/sinyal/${o.sid}`, { method: "PUT", body: JSON.stringify(body) });
          kapatModal(); uyari(msg, true); _mkYukle();
        } catch (e) { uyari(e.message); }
      };
      document.getElementById("mkd-kaydet")?.addEventListener("click", () => {
        const metin = (document.getElementById("mkd-metin")?.value || "").trim();
        if (!metin) { uyari("Not boş olamaz."); return; }
        const tarih = document.getElementById("mkd-tarih")?.value || "";
        put({ metin, takip_tarihi: tarih }, "✓ Güncellendi.");
      });
      document.getElementById("mkd-tamam")?.addEventListener("click", () => put({ tamamla: true }, "✓ Tamamlandı."));
      document.getElementById("mkd-geriac")?.addEventListener("click", () => put({ tamamla: false }, "↩︎ Geri açıldı."));
    }'''

new_fn = '''    function _mkHatDuzenle(o) {  /* MUSTERI_HATIRLATMA_DUZENLE_V2 — katmanli overlay: musteri kartini EZMEZ */
      const kapandi = !!o.skapandi;
      const kok = document.getElementById("saha-modal"); if (!kok) return;
      const lay = document.createElement("div");
      lay.className = "modal-fon mkd-fon";
      lay.style.zIndex = "70";
      lay.innerHTML = `<div class="modal-kutu" style="max-width:min(95vw,560px)">
        <h3>${kapandi ? "Hatırlatma (tamamlandı)" : "Hatırlatmayı Düzenle"}</h3>
        <label>Not
          <textarea class="giris" id="mkd-metin" rows="4">${esc(String(o.sozet || ""))}</textarea>
        </label>
        <label style="margin-top:10px;display:block">Takip tarihi
          <input type="date" class="giris" id="mkd-tarih" value="${o.stakip || ""}">
        </label>
        <div class="modal-btnlar" style="flex-wrap:wrap;gap:8px">
          <button class="btn gri" id="mkd-vazgec">Vazgeç</button>
          ${kapandi
            ? `<button class="btn" id="mkd-geriac">↩︎ Geri Aç</button>`
            : `<button class="btn" id="mkd-tamam" style="background:#106B4A;color:#fff">✓ Tamamlandı</button>`}
          <button class="btn" id="mkd-kaydet">Kaydet</button>
        </div></div>`;
      kok.appendChild(lay);
      const kapat = () => { lay.remove(); };
      lay.addEventListener("click", (ev) => { if (ev.target === lay) kapat(); });
      lay.querySelector("#mkd-vazgec")?.addEventListener("click", kapat);
      const put = async (body, msg) => {
        try {
          await api(`/api/saha/sinyal/${o.sid}`, { method: "PUT", body: JSON.stringify(body) });
          kapat(); uyari(msg, true); _mkYukle();
        } catch (e) { uyari(e.message); }
      };
      lay.querySelector("#mkd-kaydet")?.addEventListener("click", () => {
        const metin = (lay.querySelector("#mkd-metin")?.value || "").trim();
        if (!metin) { uyari("Not boş olamaz."); return; }
        const tarih = lay.querySelector("#mkd-tarih")?.value || "";
        put({ metin, takip_tarihi: tarih }, "✓ Güncellendi.");
      });
      lay.querySelector("#mkd-tamam")?.addEventListener("click", () => put({ tamamla: true }, "✓ Tamamlandı."));
      lay.querySelector("#mkd-geriac")?.addEventListener("click", () => put({ tamamla: false }, "↩︎ Geri açıldı."));
    }'''

if old_fn not in src:
    print("HATA: V1 _mkHatDuzenle blogu bulunamadi (V1 client uygulanmis mi?)"); sys.exit(1)
src = src.replace(old_fn, new_fn, 1)
print("[+] _mkHatDuzenle katmanli overlay'e cevrildi (kart ezilmiyor)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
