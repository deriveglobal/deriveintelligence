#!/usr/bin/env python3
# FOTO_DECODE_SAGLAM_V1 (client) — Galeri fotografi ziyarette gorunmuyor hatasi (Eftal Yildiz, 24 Agu).
#   Kok neden: kucult() decode edilemeyen (HEIC / iOS canvas sinirini asan) fotoda img.onerror/timeout
#   olmadigi icin Promise asilir; for-dongusu await'te takilir; fotolar[] bos kalir; server'a hic foto gitmez.
#   Duzeltme: (1) kucult asilmaz — onerror + timeout + cikti dogrulama, decode edilemezse null.
#            (2) uc foto-ekleme handler'i null'i atlar, gecerlileri korur, okunamayan sayisini gorunur uyarir.
#   NOT: server foto ucu jpeg/png/webp/gif + magic-byte + 512KB govde + 4MB ile SIKI dogrular; ham HEIC
#        gonderilemez (dogru davranis). Bu yuzden duzeltme tamamen client: decode edilebileni JPEG'e cevir,
#        edilemeyeni sessiz dusurme — gorunur kil. Idempotent (marker: FOTO_DECODE_SAGLAM_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "FOTO_DECODE_SAGLAM_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

n = 0

# ── 1) kucult() — asilmaz, cikti dogrulanir, decode edilemeyen null ──
kucult_old = '''function kucult(file) {
  return new Promise(resolve => {
    const img = new Image();
    img.onload = () => {
      const max = 1280;
      const oran = Math.min(1, max / Math.max(img.width, img.height));
      const cv = document.createElement("canvas");
      cv.width = Math.round(img.width * oran);
      cv.height = Math.round(img.height * oran);
      cv.getContext("2d").drawImage(img, 0, 0, cv.width, cv.height);
      resolve(cv.toDataURL("image/jpeg", 0.72));
      URL.revokeObjectURL(img.src);
    };
    img.src = URL.createObjectURL(file);
  });
}'''
kucult_new = '''function kucult(file) {  /* FOTO_DECODE_SAGLAM_V1 — asilma yok; decode edilemeyen (HEIC/bozuk/asiri buyuk) foto null doner */
  return new Promise(resolve => {
    let bitti = false;
    const url = URL.createObjectURL(file);
    const kapat = v => { if (bitti) return; bitti = true; try { URL.revokeObjectURL(url); } catch (e) {} resolve(v); };
    const zaman = setTimeout(() => kapat(null), 15000);  // decode 15sn'de bitmezse birak — dongu asilmasin
    const img = new Image();
    img.onload = () => {
      try {
        const max = 1280;
        const oran = Math.min(1, max / Math.max(img.width, img.height));
        const cv = document.createElement("canvas");
        cv.width = Math.max(1, Math.round(img.width * oran));
        cv.height = Math.max(1, Math.round(img.height * oran));
        cv.getContext("2d").drawImage(img, 0, 0, cv.width, cv.height);
        const durl = cv.toDataURL("image/jpeg", 0.72);
        clearTimeout(zaman);
        // iOS canvas sinirinda toDataURL bos ("data:,") or gecersiz donebilir → gecersiz say, kayip uretme
        kapat((durl && durl.length > 1000 && durl.indexOf("data:image/jpeg") === 0) ? durl : null);
      } catch (e) { clearTimeout(zaman); kapat(null); }
    };
    img.onerror = () => { clearTimeout(zaman); kapat(null); };  // HEIC/desteklenmeyen/bozuk → null
    img.src = url;
  });
}'''
if kucult_old in src:
    src = src.replace(kucult_old, kucult_new, 1); n += 1; print("[+] kucult() saglamlastirildi")
else:
    print("HATA: kucult() anchor bulunamadi"); sys.exit(1)

# Ortak uyari (product sesi: rakam ne ise onu de, suclayici degil)
UYARI = 'if (hata) uyari(hata + " foto\\u011fraf okunamad\\u0131 \\u2014 desteklenmeyen bi\\u00e7im (HEIC olabilir). Kamerayla \\u00e7ekin veya JPEG se\\u00e7in.");'

# ── 2) zf-foto / zf-foto-cam (ziyaret formu) ──
zf_old = '''  const _zfFotoEkle = async ev => {  /* ZIYARET_FOTO_KAMERA_V1 — kamera + galeri tek isleyici */
    for (const file of ev.target.files) {
      const kucuk = await kucult(file);
      fotolar.push(kucuk);
      document.getElementById("zf-foto-liste").insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ev.target.value = "";
  };'''
zf_new = '''  const _zfFotoEkle = async ev => {  /* ZIYARET_FOTO_KAMERA_V1 + FOTO_DECODE_SAGLAM_V1 — okunamayan foto sessiz dusmez */
    const files = Array.from(ev.target.files || []);
    ev.target.value = "";
    let hata = 0;
    for (const file of files) {
      const kucuk = await kucult(file);
      if (!kucuk) { hata++; continue; }
      fotolar.push(kucuk);
      document.getElementById("zf-foto-liste")?.insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ''' + UYARI + '''
  };'''
if zf_old in src:
    src = src.replace(zf_old, zf_new, 1); n += 1; print("[+] zf-foto handler null-guard")
else:
    print("HATA: zf-foto handler anchor bulunamadi"); sys.exit(1)

# ── 3) zd-foto (ziyaret duzenleme modali) ──
zd_old = '''  document.getElementById("zd-foto")?.addEventListener("change", async ev => {
    for (const file of ev.target.files) {
      const kucuk = await kucult(file);
      yeniFotolar.push(kucuk);
      document.getElementById("zd-foto-yeni").insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ev.target.value = "";
  });'''
zd_new = '''  document.getElementById("zd-foto")?.addEventListener("change", async ev => {  /* FOTO_DECODE_SAGLAM_V1 */
    const files = Array.from(ev.target.files || []);
    ev.target.value = "";
    let hata = 0;
    for (const file of files) {
      const kucuk = await kucult(file);
      if (!kucuk) { hata++; continue; }
      yeniFotolar.push(kucuk);
      document.getElementById("zd-foto-yeni")?.insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ''' + UYARI + '''
  });'''
if zd_old in src:
    src = src.replace(zd_old, zd_new, 1); n += 1; print("[+] zd-foto handler null-guard")
else:
    print("HATA: zd-foto handler anchor bulunamadi"); sys.exit(1)

# ── 4) pt-foto (ziyaret tamamlama modali) ──
pt_old = '''  document.getElementById("pt-foto")?.addEventListener("change", async ev => {
    for (const file of ev.target.files) {
      const kucuk = await kucult(file);
      fotolar.push(kucuk);
      document.getElementById("pt-foto-liste").insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ev.target.value = "";
  });'''
pt_new = '''  document.getElementById("pt-foto")?.addEventListener("change", async ev => {  /* FOTO_DECODE_SAGLAM_V1 */
    const files = Array.from(ev.target.files || []);
    ev.target.value = "";
    let hata = 0;
    for (const file of files) {
      const kucuk = await kucult(file);
      if (!kucuk) { hata++; continue; }
      fotolar.push(kucuk);
      document.getElementById("pt-foto-liste")?.insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ''' + UYARI + '''
  });'''
if pt_old in src:
    src = src.replace(pt_old, pt_new, 1); n += 1; print("[+] pt-foto handler null-guard")
else:
    print("HATA: pt-foto handler anchor bulunamadi"); sys.exit(1)

if src == orig:
    print("[=] Degisiklik yok"); sys.exit(1)
with open(path, "w", encoding="utf-8") as f: f.write(src)
print("[ok] yazildi:", path, "(", n, "blok )")
