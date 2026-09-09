#!/usr/bin/env python3
# ZIYARET_FOTO_KAMERA_V1 + TEXTAREA_SCROLL_V2 (client) — Ali Kemal ziyaret girisi:
#   (1) Foto: tek input accept=image/* MULTIPLE → iOS'ta kamera KAPALI (sadece galeri). FIX: iki input:
#       📷 Çek (capture=environment, kamera) + 🖼 Galeri (multiple), tek isleyici.
#   (2) Text box "halen kaymiyor": global autogrow zaten var ama scrollIntoView(nearest) klavye altini
#       kurtarmiyor. FIX: block "nearest"→"center" + focus geciksmesi 60→300ms (klavye animasyonu sonrasi).
#   Idempotent (markerlar: ZIYARET_FOTO_KAMERA_V1 / TEXTAREA_SCROLL_V2).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
if "ZIYARET_FOTO_KAMERA_V1" in src and "TEXTAREA_SCROLL_V2" in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) foto markup: tek label -> Çek + Galeri
old1 = '''        <label class="btn cizgili dosya-btn">📷 Foto Ekle<input type="file" id="zf-foto" accept="image/*" multiple hidden></label>'''
new1 = '''        <label class="btn cizgili dosya-btn">📷 Çek<input type="file" id="zf-foto-cam" accept="image/*" capture="environment" hidden></label><!-- ZIYARET_FOTO_KAMERA_V1 -->
        <label class="btn cizgili dosya-btn">🖼 Galeri<input type="file" id="zf-foto" accept="image/*" multiple hidden></label>'''
if old1 not in src:
    print("HATA: zf-foto markup anchor bulunamadi"); sys.exit(1)
src = src.replace(old1, new1, 1)
print("[+] foto: kamera + galeri iki input")

# 2) foto handler: iki input tek isleyici
old2 = '''  document.getElementById("zf-foto")?.addEventListener("change", async ev => {
    for (const file of ev.target.files) {
      const kucuk = await kucult(file);
      fotolar.push(kucuk);
      document.getElementById("zf-foto-liste").insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ev.target.value = "";
  });'''
new2 = '''  const _zfFotoEkle = async ev => {  /* ZIYARET_FOTO_KAMERA_V1 — kamera + galeri tek isleyici */
    for (const file of ev.target.files) {
      const kucuk = await kucult(file);
      fotolar.push(kucuk);
      document.getElementById("zf-foto-liste").insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ev.target.value = "";
  };
  document.getElementById("zf-foto")?.addEventListener("change", _zfFotoEkle);
  document.getElementById("zf-foto-cam")?.addEventListener("change", _zfFotoEkle);'''
if old2 not in src:
    print("HATA: zf-foto handler anchor bulunamadi"); sys.exit(1)
src = src.replace(old2, new2, 1)
print("[+] foto: tek isleyici iki input'a bagli")

# 3) scroll: nearest -> center + gecikme
old3 = '''    const t = e.target;
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
  }, true);'''
new3 = '''    const t = e.target;
    if (t && t.tagName === "TEXTAREA") {
      _sahaTaGrow(t);
      if (t.style.resize !== "none") { try { t.scrollIntoView({ block: "center" }); } catch (_) {} }  /* TEXTAREA_SCROLL_V2 */
    }
  }, true);
  document.addEventListener("focusin", function (e) {
    const t = e.target;
    if (t && t.tagName === "TEXTAREA") {
      _sahaTaGrow(t);
      setTimeout(function () { try { t.scrollIntoView({ block: "center" }); } catch (_) {} }, 300);  /* TEXTAREA_SCROLL_V2 — klavye animasyonu sonrasi ortala */
    }
  }, true);'''
if old3 not in src:
    print("HATA: scrollIntoView anchor bulunamadi"); sys.exit(1)
src = src.replace(old3, new3, 1)
print("[+] scroll: center + 300ms")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f: f.write(src)
    print("[ok] yazildi:", path)
