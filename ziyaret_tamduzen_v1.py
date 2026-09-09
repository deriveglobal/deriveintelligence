#!/usr/bin/env python3
# ZIYARET_TAMDUZEN_V1 — Ziyaret Duzenle modali artik TUM ziyareti duzenler:
#   tarih/katilimci/notlar + profil alanlari (raf/bayilik/rakip/stok VEYA sektor/arac-parki/
#   marka/tedarikci/potansiyel, tip'e gore) + fotograf ekle/sil.
#   z.detay'dan on-doldurur; kaydettiginde detay'i guncelle ucuna, profili musteri ucuna yazar
#   (Fatih karari: her zaman profile de yaz), yeni fotolari yukler, isaretli fotolari siler.
#   saha.js. Idempotent, marker-guardli. Backend detay'i zaten kabul ediyordu (guncelle action);
#   foto silme ZIYARET_FOTO_SIL_V1 ucunu gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "ZIYARET_TAMDUZEN_V1" in s:
    print("tamduzen: already present, skip"); print("DONE."); raise SystemExit
assert "cipSecici" in s and "cipDegerler" in s and "function kucult" in s or "kucult" in s, "gerekli yardimcilar yok"

START = "async function ziyaretDuzenleModal(z) {"
END = "\n}\n\nasync function ziyaretFormModal("
assert s.count(START) == 1, "ziyaretDuzenleModal anchor (count!=1)"
i = s.index(START)
j = s.index(END, i)  # j -> "\n}" satiri (fonksiyon kapanisi)

NEW = r'''async function ziyaretDuzenleModal(z) { /* ZIYARET_TAMDUZEN_V1 — tam form */
  const tip = z.tip || z.musteri_tip || S.semsiye || "TUKETICI";
  const tuketici = tip === "TUKETICI";
  const d = z.detay || {};
  const ap = d.arac_parki || {};
  modal(`
    <h3>✏️ Ziyaret Düzenle — ${esc(z.firma || "")}</h3>
    <div style="font-size:11px;color:#64748b;margin-bottom:10px">Düzeltmeler kayıt altına alınır; notun ilk hâli saklanır. Değişiklik müşteri profiline de işlenir.</div>
    <div class="yanyana">
      <label>Ziyaret tarihi
        <input class="giris" id="zd-tarih" type="date" value="${z.ziyaret_tarihi ? String(z.ziyaret_tarihi).slice(0, 10) : ""}">
      </label>
      <label>Katılımcı
        <input class="giris" id="zd-katilimci" value="${esc(z.katilimci || "")}" placeholder="Görüşülen kişi">
      </label>
    </div>
    ${tuketici ? `
      <div class="alan-grup"><span class="alan-baslik">Raftaki markalar</span>${cipSecici("zd-raf", MARKALAR)}</div>
      <div class="alan-grup"><span class="alan-baslik">Bayilikler</span>${cipSecici("zd-bayilik", BAYILIKLER)}</div>
      <div class="alan-grup"><span class="alan-baslik">Görülen rakip toptancılar</span>${cipSecici("zd-rakip", RAKIPLER)}</div>
      <div class="yanyana">
        <label>Kış stok (adet)<input type="number" class="giris" id="zd-kis" min="0" value="${d.kis_stok != null ? d.kis_stok : ""}"></label>
        <label>Yaz stok (adet)<input type="number" class="giris" id="zd-yaz" min="0" value="${d.yaz_stok != null ? d.yaz_stok : ""}"></label>
      </div>
    ` : `
      <div class="alan-grup"><span class="alan-baslik">Sektörler</span>${cipSecici("zd-sektorler", SEKTORLER)}</div>
      <div class="alan-grup"><span class="alan-baslik">Araç parkı</span>
        <div class="yanyana4">
          <label>Çekici<input type="number" class="giris" id="zd-cekici" min="0" value="${ap.cekici != null ? ap.cekici : ""}"></label>
          <label>Dorse<input type="number" class="giris" id="zd-dorse" min="0" value="${ap.dorse != null ? ap.dorse : ""}"></label>
          <label>Kamyon<input type="number" class="giris" id="zd-kamyon" min="0" value="${ap.kamyon != null ? ap.kamyon : ""}"></label>
          <label>İş mak.<input type="number" class="giris" id="zd-ismak" min="0" value="${ap.is_makinesi != null ? ap.is_makinesi : ""}"></label>
        </div></div>
      <div class="alan-grup"><span class="alan-baslik">Kullanılan markalar</span>${cipSecici("zd-marka", MARKALAR)}</div>
      <div class="alan-grup"><span class="alan-baslik">Mevcut tedarikçi</span>${cipSecici("zd-tedarikci", RAKIPLER)}</div>
      <label>Yıllık potansiyel (adet)<input type="number" class="giris" id="zd-potansiyel" min="0" value="${d.yillik_potansiyel != null ? d.yillik_potansiyel : ""}"></label>`}
    <label>Notlar
      <textarea class="giris" id="zd-notlar" rows="6" placeholder="Ziyaret notu…">${esc(z.notlar || "")}</textarea>
    </label>
    <div class="alan-grup"><span class="alan-baslik">Fotoğraflar</span>
      <div id="zd-foto-mevcut" class="foto-izgara"><span style="font-size:12px;color:#94a3b8">yükleniyor…</span></div>
      <label class="btn cizgili dosya-btn" style="display:inline-block;margin-top:2px">📷 Foto Ekle<input type="file" id="zd-foto" accept="image/*" capture="environment" multiple hidden></label>
      <div id="zd-foto-yeni" class="foto-izgara"></div>
    </div>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="zd-kaydet">Kaydet</button>
    </div>`);

  // Cip on-doldurma — cipDegerler yalniz .on doner; kayitli custom degerler kaybolmasin diye
  // predefined listede olmayan degerlere de buton uretip on isaretle.
  const _cipDoldur = (kap, arr) => {
    const kutu = document.getElementById(kap);
    if (!kutu || !Array.isArray(arr)) return;
    const ekle = kutu.querySelector(".cip-ekle");
    arr.forEach(v => {
      let b = [...kutu.querySelectorAll(".cip")].find(x => x.dataset.v === v);
      if (!b) {
        b = document.createElement("button");
        b.type = "button"; b.className = "cip"; b.dataset.v = v; b.textContent = v;
        kutu.insertBefore(b, ekle || null);
      }
      b.classList.add("on");
    });
  };
  if (tuketici) {
    _cipDoldur("zd-raf", d.raf_markalari);
    _cipDoldur("zd-bayilik", d.bayilikler);
    _cipDoldur("zd-rakip", d.rakipler);
  } else {
    _cipDoldur("zd-sektorler", d.sektorler);
    _cipDoldur("zd-marka", d.kullanilan_markalar);
    _cipDoldur("zd-tedarikci", d.tedarikci_markalar);
  }
  cipleriBagla(document.getElementById("saha-modal"));

  // Mevcut fotolar — her birine sil(x) rozeti; toggle ile isaretle
  const silinecek = new Set();
  (async () => {
    const g = document.getElementById("zd-foto-mevcut");
    if (!z.id || !Number(z.foto_sayisi)) { g.innerHTML = `<span style="font-size:12px;color:#94a3b8">fotoğraf yok</span>`; }
    try {
      const { fotolar } = await api(`/api/saha/ziyaretler/${z.id}/fotolar`);
      if (!fotolar || !fotolar.length) { g.innerHTML = `<span style="font-size:12px;color:#94a3b8">fotoğraf yok</span>`; return; }
      g.innerHTML = "";
      for (const f of fotolar) {
        const url = await fotoUrl(f.id);
        const w = document.createElement("div");
        w.style.cssText = "position:relative;display:inline-block";
        w.innerHTML = `<img src="${url}" alt=""><button type="button" title="Sil" style="position:absolute;top:-6px;right:-6px;width:20px;height:20px;border-radius:50%;border:none;background:#dc2626;color:#fff;font-size:13px;line-height:1;cursor:pointer">×</button>`;
        const btn = w.querySelector("button");
        btn.addEventListener("click", () => {
          if (silinecek.has(f.id)) { silinecek.delete(f.id); w.style.opacity = "1"; btn.style.background = "#dc2626"; }
          else { silinecek.add(f.id); w.style.opacity = "0.35"; btn.style.background = "#64748b"; }
        });
        g.appendChild(w);
      }
    } catch { g.innerHTML = `<span style="font-size:12px;color:#94a3b8">fotoğraflar yüklenemedi</span>`; }
  })();

  // Yeni foto ekleme
  const yeniFotolar = [];
  document.getElementById("zd-foto")?.addEventListener("change", async ev => {
    for (const file of ev.target.files) {
      const kucuk = await kucult(file);
      yeniFotolar.push(kucuk);
      document.getElementById("zd-foto-yeni").insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ev.target.value = "";
  });

  document.getElementById("zd-kaydet").addEventListener("click", async () => {
    const g = id => document.getElementById(id)?.value.trim() || "";
    const n = id => { const v = g(id); return v ? Number(v) : null; };
    const notlar = g("zd-notlar");
    const katilimci = g("zd-katilimci");
    const tarih = document.getElementById("zd-tarih").value || null;
    if (!notlar) { uyari("Not boş olamaz."); return; }
    const detay = tuketici ? {
      raf_markalari: cipDegerler("zd-raf"), bayilikler: cipDegerler("zd-bayilik"),
      rakipler: cipDegerler("zd-rakip"), kis_stok: n("zd-kis"), yaz_stok: n("zd-yaz")
    } : {
      sektorler: cipDegerler("zd-sektorler"),
      arac_parki: { cekici: n("zd-cekici"), dorse: n("zd-dorse"), kamyon: n("zd-kamyon"), is_makinesi: n("zd-ismak") },
      kullanilan_markalar: cipDegerler("zd-marka"),
      tedarikci_markalar: cipDegerler("zd-tedarikci"), yillik_potansiyel: n("zd-potansiyel")
    };
    const btn = document.getElementById("zd-kaydet");
    btn.disabled = true; btn.textContent = "Kaydediliyor…";
    try {
      await api(`/api/saha/ziyaretler/${z.id}`, {
        method: "PUT",
        body: JSON.stringify({ action: "guncelle", notlar, katilimci: katilimci || null, ziyaret_tarihi: tarih, detay })
      });
      // Profil propagasyonu — create ile ayni alan adlariyla (Fatih karari: her zaman yaz)
      if (z.musteri_id) {
        const _profil = tuketici
          ? { raf_markalar: detay.raf_markalari, bayilikler: detay.bayilikler, rakip_toptancilar: detay.rakipler, kis_stok: detay.kis_stok, yaz_stok: detay.yaz_stok }
          : { sektorler: detay.sektorler, tedarikci_markalar: detay.tedarikci_markalar, kullanilan_markalar: detay.kullanilan_markalar, arac_parki: detay.arac_parki, yillik_potansiyel: detay.yillik_potansiyel };
        try { await api(`/api/saha/musteriler/${z.musteri_id}`, { method: "PUT", body: JSON.stringify(_profil) }); }
        catch (e) { uyari("⚠ Ziyaret güncellendi ama müşteri profili yazılamadı: " + (e.message || "")); }
      }
      // Isaretli fotolari sil, yeni fotolari yukle
      for (const fid of silinecek) {
        await api(`/api/saha/ziyaretler/${z.id}/foto/${fid}`, { method: "DELETE" }).catch(() => {});
      }
      for (const f of yeniFotolar) {
        await api(`/api/saha/ziyaretler/${z.id}/foto`, { method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" }) }).catch(() => {});
      }
      kapatModal();
      uyari("✓ Ziyaret güncellendi.", true);
      await loadView("ziyaretler");
    } catch (e) {
      btn.disabled = false; btn.textContent = "Kaydet";
      uyari(e.message);
    }
  });
}'''

s = s[:i] + NEW + s[j+2:]
write(FP, s)
print("tamduzen: ziyaretDuzenleModal genisletildi (profil alanlari + foto ekle/sil)")
print("marker count:", s.count("ZIYARET_TAMDUZEN_V1"))
print("DONE.")
