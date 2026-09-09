#!/usr/bin/env python3
# ZIYARET_TASLAK_V1 (client) — Hata (Ali Kemal Picakci 30/31.07): "Ziyaret uzun surunce aktivite
#   girisinde uygulamadan atabiliyor; taslak kaydedip sonra gonder olmali."
#   Cozum (kullanici karari): OTOMATIK yerel taslak + geri yukle; fotograflar DAHIL.
#   ziyaretFormModal alanlari (chip/sayi/not/foto/konum) yazarken debounce'lu localStorage'a yazilir.
#   Logout yalniz auth anahtarlarini siler → taslak sag kalir. Ayni musteride form acilinca
#   "Kaydedilmis taslak var → Geri yukle / Sil" banner'i cikar. Basarili kayitta taslak silinir.
#   Kota asilirsa fotosuz yazilir (alan verisi korunur). Idempotent (marker: ZIYARET_TASLAK_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "ZIYARET_TASLAK_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# ── 1) Taslak modulunu kaydet() oncesine ekle ──
anchor1 = "  const kaydet = async (planla) => {"
if anchor1 not in src:
    print("HATA: kaydet() anchor bulunamadi"); sys.exit(1)
block = r'''  // ── ''' + MARK + r''' — otomatik yerel taslak (ani cikis/oturum dusmesine karsi) ──
  const _tasKey = "saha-ziy-taslak-" + mus.id + "-" + (mod === "planla" ? "planla" : "kaydet");
  const _tasAlan = tuketici
    ? ["zf-lokasyon","zf-tarih","zf-katilimci","zf-not","zf-kis","zf-yaz"]
    : ["zf-lokasyon","zf-tarih","zf-katilimci","zf-not","zf-cekici","zf-dorse","zf-kamyon","zf-ismak","zf-potansiyel"];
  const _tasCip = tuketici ? ["zf-raf","zf-bayilik","zf-rakip"] : ["zf-sektorler","zf-marka","zf-tedarikci"];
  let _tasHazir = true, _tasTimer = null;
  function _tasSil() { try { localStorage.removeItem(_tasKey); } catch (e) {} }
  function _tasTopla() {
    const o = { ts: Date.now(), alan: {}, cip: {}, foto: fotolar.slice(), konum: { lat: konum.lat, lng: konum.lng } };
    _tasAlan.forEach(function (id) { const el = document.getElementById(id); if (el) o.alan[id] = el.value; });
    _tasCip.forEach(function (id) { o.cip[id] = cipDegerler(id); });
    return o;
  }
  function _tasYaz() {
    if (!_tasHazir) return;
    try { localStorage.setItem(_tasKey, JSON.stringify(_tasTopla())); }
    catch (e) { try { const o = _tasTopla(); o.foto = []; o._fotosuz = true; localStorage.setItem(_tasKey, JSON.stringify(o)); } catch (e2) {} }
  }
  function _tasZamanla() { clearTimeout(_tasTimer); _tasTimer = setTimeout(_tasYaz, 700); }
  function _tasYukle(d) {
    _tasAlan.forEach(function (id) { const el = document.getElementById(id); if (el && d.alan && d.alan[id] != null) el.value = d.alan[id]; });
    _tasCip.forEach(function (id) { const set = new Set((d.cip && d.cip[id]) || []); document.querySelectorAll("#" + id + " .cip").forEach(function (b) { if (set.has(b.dataset.v)) b.classList.add("on"); }); });
    if (Array.isArray(d.foto) && d.foto.length) { const liste = document.getElementById("zf-foto-liste"); d.foto.forEach(function (f) { fotolar.push(f); if (liste) liste.insertAdjacentHTML("beforeend", '<img src="' + f + '" alt="">'); }); }
    if (d.konum && d.konum.lat != null) { konum.lat = d.konum.lat; konum.lng = d.konum.lng; const st = document.getElementById("zf-konum-durum"); if (st) st.textContent = "✓ Konum (taslaktan)"; const pin = document.getElementById("zf-pin-label"); if (pin) pin.style.display = "flex"; }
  }
  const _tasKok = document.querySelector("#saha-modal .modal-kutu");
  if (_tasKok) {
    _tasKok.addEventListener("input", _tasZamanla);
    _tasKok.addEventListener("change", _tasZamanla);
    _tasKok.addEventListener("click", function (e) { if (e.target.closest && e.target.closest(".cip")) _tasZamanla(); });
  }
  (function () {
    let raw = null; try { raw = localStorage.getItem(_tasKey); } catch (e) {}
    if (!raw) return;
    let d = null; try { d = JSON.parse(raw); } catch (e) { _tasSil(); return; }
    if (!d || !d.ts) { _tasSil(); return; }
    if (Date.now() - d.ts > 7 * 86400000) { _tasSil(); return; }
    _tasHazir = false;  // kullanici karar verene kadar ustune yazma
    const dk = Math.max(1, Math.round((Date.now() - d.ts) / 60000));
    const ne = dk < 60 ? (dk + " dk") : (Math.round(dk / 60) + " saat");
    const ban = document.createElement("div");
    ban.style.cssText = "background:#ecfdf5;border:1px solid #6ee7b7;border-radius:9px;padding:10px 12px;margin:0 0 10px;font-size:13px;color:#065f46;display:flex;gap:8px;align-items:center;flex-wrap:wrap";
    ban.innerHTML = '💾 <b>Kaydedilmiş taslak var</b> (' + ne + ' önce' + (d._fotosuz ? ", fotosuz" : "") + '). <button type="button" id="zf-tas-yukle" class="btn kucuk" style="margin-left:auto">↩︎ Geri yükle</button> <button type="button" id="zf-tas-sil" class="btn kucuk gri">Sil</button>';
    const kutu = _tasKok || document.querySelector("#saha-modal .modal-kutu");
    const h3 = kutu && kutu.querySelector("h3");
    if (h3 && h3.nextSibling) h3.parentNode.insertBefore(ban, h3.nextSibling); else if (kutu) kutu.insertBefore(ban, kutu.firstChild);
    document.getElementById("zf-tas-yukle")?.addEventListener("click", function () { _tasYukle(d); _tasHazir = true; ban.remove(); });
    document.getElementById("zf-tas-sil")?.addEventListener("click", function () { _tasSil(); _tasHazir = true; ban.remove(); });
  })();

'''
src = src.replace(anchor1, block + anchor1, 1)
print("[+] Taslak modulu eklendi")

# ── 2) Mukerrer "mevcudu duzenle" yolunda taslagi sil ──
anchor2 = ('        } else {\n'
           '          kapatModal();\n'
           '          await loadView("ziyaretler");')
new2    = ('        } else {\n'
           '          _tasSil();\n'
           '          kapatModal();\n'
           '          await loadView("ziyaretler");')
if anchor2 not in src:
    print("HATA: mukerrer-mevcut anchor bulunamadi"); sys.exit(1)
src = src.replace(anchor2, new2, 1)
print("[+] Mukerrer-mevcut yolunda _tasSil eklendi")

# ── 3) Basarili kayit yolunda taslagi sil ──
anchor3 = ('      kapatModal();\n'
           '      if (!planla) {\n'
           '        await loadView("ziyaretler");\n'
           '        ziyaretDetayModal(ziyaret.id);')
new3    = ('      _tasSil();\n'
           '      kapatModal();\n'
           '      if (!planla) {\n'
           '        await loadView("ziyaretler");\n'
           '        ziyaretDetayModal(ziyaret.id);')
if anchor3 not in src:
    print("HATA: basarili-kayit anchor bulunamadi"); sys.exit(1)
src = src.replace(anchor3, new3, 1)
print("[+] Basarili kayit yolunda _tasSil eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
