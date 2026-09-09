#!/usr/bin/env python3
# TEKLIF_KAYDET_GONDER_V1 (client) — teklifFormModal:
#   Redundant 2. adim ("Onaya Gonder") kaldirildi: ana buton "Kaydet ve Onaya Gonder"
#   (POST create + PUT action:gonder tek akista). Ikincil "Taslak kaydet" korunur
#   (yarim teklifi park etmek isteyen icin). Tum teklifler zaten yonetici onayina gidiyor.
#   Idempotent (marker: TEKLIF_KAYDET_GONDER_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "TEKLIF_KAYDET_GONDER_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# ── 1) Buton satiri: Taslak kaydet + Kaydet & Onaya Gonder ──
btn_old = ('    <div class="modal-btnlar">\n'
           '      <button class="btn gri" data-kapat>Vazgeç</button>\n'
           '      <button class="btn gri" id="tf-satir-ekle">＋ Satıra Ekle</button>\n'
           '      <button class="btn" id="tf-kaydet">Teklifi Kaydet</button>\n'
           '    </div>`);')
btn_new = ('    <div class="modal-btnlar">\n'
           '      <button class="btn gri" data-kapat>Vazgeç</button>\n'
           '      <button class="btn gri" id="tf-satir-ekle">＋ Satıra Ekle</button>\n'
           '      <button class="btn gri" id="tf-taslak" title="Yarım kalan teklifi sonra bitirmek için">Taslak kaydet</button>  <!-- ' + MARK + ' -->\n'
           '      <button class="btn" id="tf-kaydet">Kaydet & Onaya Gönder</button>\n'
           '    </div>`);')
if btn_old not in src:
    print("HATA: buton satiri anchor bulunamadi"); sys.exit(1)
src = src.replace(btn_old, btn_new, 1)
print("[+] Butonlar: Taslak kaydet + Kaydet & Onaya Gönder")

# ── 2) Kaydet handler'i paylasilan _tfKaydet(gonder) fonksiyonuna cevir ──
h_old = ('''  document.getElementById("tf-kaydet")?.addEventListener("click", async () => {
    // If form has a product, add it as the last line
    const formKalem = kalemdenOku();
    const allKalemler = formKalem ? [..._kalemler, formKalem] : [..._kalemler];
    if (!allKalemler.length) { uyari("En az bir ürün ekleyin."); return; }
    const genelNot = document.getElementById("tf-genel-not").value.trim() || null;
    const kaynak = ziyaretId ? "ZIYARET" : (document.getElementById("tf-kaynak")?.value || "");
    if (!ziyaretId && !kaynak) { uyari("Teklif kaynağını seçin (Telefon/WhatsApp/E-posta)."); return; }
    try {
      await api("/api/saha/teklifler", {
        method: "POST",
        body: JSON.stringify({
          musteri_id: mus.id,
          ziyaret_id: ziyaretId,
          kaynak    : kaynak,
          notlar    : genelNot,
          vade_turu : document.getElementById("tf-vade")?.value.trim() || null,
          kalemler  : allKalemler
        })
      });
      kapatModal();
      uyari("✓ Teklif kaydedildi.", true);
      if (S.view === "iskonto") loadView("iskonto");
    } catch (e) { uyari(e.message); }
  });''')
h_new = ('''  // ''' + MARK + ''' — tek akis: kaydet (+ istege bagli onaya gonder)
  async function _tfKaydet(gonder) {
    // If form has a product, add it as the last line
    const formKalem = kalemdenOku();
    const allKalemler = formKalem ? [..._kalemler, formKalem] : [..._kalemler];
    if (!allKalemler.length) { uyari("En az bir ürün ekleyin."); return; }
    const genelNot = document.getElementById("tf-genel-not").value.trim() || null;
    const kaynak = ziyaretId ? "ZIYARET" : (document.getElementById("tf-kaynak")?.value || "");
    if (!ziyaretId && !kaynak) { uyari("Teklif kaynağını seçin (Telefon/WhatsApp/E-posta)."); return; }
    try {
      const r = await api("/api/saha/teklifler", {
        method: "POST",
        body: JSON.stringify({
          musteri_id: mus.id,
          ziyaret_id: ziyaretId,
          kaynak    : kaynak,
          notlar    : genelNot,
          vade_turu : document.getElementById("tf-vade")?.value.trim() || null,
          kalemler  : allKalemler
        })
      });
      if (gonder && r && r.teklif && r.teklif.id) {
        try {
          await api(`/api/saha/teklifler/${r.teklif.id}`, { method: "PUT", body: JSON.stringify({ action: "gonder" }) });
        } catch (e2) {
          kapatModal();
          uyari("Teklif kaydedildi ama onaya gönderilemedi: " + e2.message + " — listeden '▶ Onaya Gönder' ile yollayabilirsiniz.");
          if (S.view === "iskonto") loadView("iskonto");
          return;
        }
      }
      kapatModal();
      uyari(gonder ? "✓ Teklif kaydedildi ve onaya gönderildi." : "✓ Taslak kaydedildi.", true);
      if (S.view === "iskonto") loadView("iskonto");
    } catch (e) { uyari(e.message); }
  }
  document.getElementById("tf-kaydet")?.addEventListener("click", () => _tfKaydet(true));
  document.getElementById("tf-taslak")?.addEventListener("click", () => _tfKaydet(false));''')
if h_old not in src:
    print("HATA: tf-kaydet handler anchor bulunamadi"); sys.exit(1)
src = src.replace(h_old, h_new, 1)
print("[+] Handler: _tfKaydet(gonder) + iki buton bagli")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
