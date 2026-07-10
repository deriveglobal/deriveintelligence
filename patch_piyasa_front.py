# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# PIYASA_FRONT — Market Intel tab: rival price + file upload + market note + feed.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) nav tab
rep('["rapor", "📊", "Rapor"],',
    '["rapor", "📊", "Rapor"], ["piyasa", "🏷️", "Piyasa"],',
    "nav-tab")

# 2) view map
rep("duyurular: vDuyurular, mesajlar: vMesajlar",
    "piyasa: vPiyasa, duyurular: vDuyurular, mesajlar: vMesajlar",
    "view-map")

# 3) vPiyasa view + modals (before vDuyurular)
BLOCK = r'''async function vPiyasa() {
  const m = main();
  try {
    const [df, rf] = await Promise.all([
      api("/api/saha/piyasa-dosya").catch(() => ({ dosyalar: [] })),
      api("/api/saha/rakip-teklif?limit=30").catch(() => ({ kayitlar: [] }))
    ]);
    const dosyalar = df.dosyalar || [], kayitlar = rf.kayitlar || [];
    const TIP = { FIYAT_LISTESI: "📋 Fiyat Listesi", KAMPANYA: "🎯 Kampanya", RAKIP_TEKLIF: "🏁 Rakip Teklif", DIGER: "📎 Diğer" };
    const KYN = { ZIYARET: "🚶 Ziyaret", TELEFON: "📞 Telefon", MANUEL: "✍️ Manuel" };
    const fileHtml = dosyalar.length ? dosyalar.map(d => `
      <div class="kart" data-dosya="${d.id}" style="cursor:pointer;padding:10px 12px;margin-bottom:6px">
        <div class="kart-ust"><b>${esc(d.baslik || TIP[d.tip] || "Dosya")}</b><span class="rozet" style="background:#0891b2">${TIP[d.tip] || d.tip}</span></div>
        <div class="kart-alt">${d.rakip_marka ? `<span>${esc(d.rakip_marka)}</span>` : ""}${d.musteri ? `<span>${esc(d.musteri)}</span>` : ""}<span>👤 ${esc(d.rep || "")}</span><span>${new Date(d.created_at).toLocaleDateString("tr-TR")}</span></div>
        ${d.notlar ? `<div class="kart-not">${esc(d.notlar)}</div>` : ""}
      </div>`).join("") : `<div class="saha-bos">Henüz dosya yok.</div>`;
    const priceHtml = kayitlar.length ? kayitlar.map(r => `
      <div class="kart" style="padding:10px 12px;margin-bottom:6px">
        <div class="kart-ust"><b>${esc(r.rakip_marka || "")}${r.rakip_model ? " " + esc(r.rakip_model) : ""}</b><span>${esc(r.ebat || "")}</span><span style="font-weight:700;color:#0f172a">${r.rakip_fiyat != null ? Number(r.rakip_fiyat).toLocaleString("tr-TR") + "₺" : ""}</span></div>
        <div class="kart-alt"><span>${KYN[r.kaynak] || r.kaynak || ""}</span>${r.musteri ? `<span>${esc(r.musteri)}</span>` : ""}${r.il ? `<span>${esc(r.il)}</span>` : ""}<span>${r.teklif_tarihi ? new Date(r.teklif_tarihi).toLocaleDateString("tr-TR") : ""}</span></div>
      </div>`).join("") : `<div class="saha-bos">Henüz rakip fiyat kaydı yok.</div>`;
    m.innerHTML = `
      <div style="padding:12px">
        <b style="font-size:15px">🏷️ Piyasa Bilgisi</b>
        <div style="display:flex;gap:8px;flex-wrap:wrap;margin:12px 0">
          <button class="btn" id="pi-fiyat">🏁 Rakip Fiyat</button>
          <button class="btn" id="pi-dosya">📎 Dosya Yükle</button>
          <button class="btn" id="pi-not">📝 Piyasa Notu</button>
        </div>
        <div style="font-size:12px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.4px;margin:10px 0 6px">📎 Dosyalar & Broşürler</div>
        ${fileHtml}
        <div style="font-size:12px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.4px;margin:14px 0 6px">🏁 Son Rakip Fiyatlar</div>
        ${priceHtml}
      </div>`;
    m.querySelector("#pi-fiyat").addEventListener("click", () => rakipFiyatModal(() => loadView("piyasa")));
    m.querySelector("#pi-dosya").addEventListener("click", () => dosyaYukleModal(() => loadView("piyasa")));
    m.querySelector("#pi-not").addEventListener("click", () => piyasaNotuModal(() => loadView("piyasa")));
    m.querySelectorAll("[data-dosya]").forEach(el => el.addEventListener("click", async () => {
      try { const res = await fetch(`/api/saha/piyasa-dosya/${el.dataset.dosya}`, { headers: S.headers() }); const url = URL.createObjectURL(await res.blob()); window.open(url, "_blank"); }
      catch (e) { uyari("Dosya açılamadı."); }
    }));
  } catch (e) { m.innerHTML = hata(e); }
}

function rakipFiyatModal(onSave) {
  modal(`
    <h3>🏁 Rakip Fiyat Ekle</h3>
    <label>Rakip Marka *<input class="giris" id="rf-marka" placeholder="Michelin, Pirelli…"></label>
    <label>Model<input class="giris" id="rf-model" placeholder="opsiyonel"></label>
    <label>Ebat *<input class="giris" id="rf-ebat" placeholder="385/65R22.5"></label>
    <label>Fiyat (₺) *<input type="number" class="giris" id="rf-fiyat" min="0" step="0.01"></label>
    <label>Kaynak<select class="giris" id="rf-kaynak"><option value="ZIYARET">🚶 Ziyaret</option><option value="TELEFON">📞 Telefon</option><option value="MANUEL">✍️ Manuel</option></select></label>
    <label>Not<textarea class="giris" id="rf-not" rows="2"></textarea></label>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Vazgeç</button><button class="btn" id="rf-kaydet">Kaydet</button></div>`);
  document.getElementById("rf-kaydet").addEventListener("click", async () => {
    const marka = g("rf-marka"), ebat = g("rf-ebat"), fiyat = g("rf-fiyat");
    if (!marka || !ebat || !fiyat) { uyari("Marka, ebat ve fiyat zorunlu."); return; }
    try {
      await api("/api/saha/rakip-teklif", { method: "POST", body: JSON.stringify({ rakip_marka: marka, rakip_model: g("rf-model") || null, ebat, rakip_fiyat: Number(fiyat), kaynak: document.getElementById("rf-kaynak").value, notlar: g("rf-not") || null }) });
      kapatModal(); uyari("✓ Rakip fiyat kaydedildi.", true); onSave();
    } catch (e) { uyari(e.message); }
  });
}

function dosyaYukleModal(onSave) {
  modal(`
    <h3>📎 Dosya / Foto Yükle</h3>
    <label>Tür<select class="giris" id="dy-tip"><option value="FIYAT_LISTESI">📋 Fiyat Listesi</option><option value="KAMPANYA">🎯 Kampanya Broşürü</option><option value="RAKIP_TEKLIF">🏁 Rakip Teklif</option><option value="DIGER">📎 Diğer</option></select></label>
    <label>Başlık<input class="giris" id="dy-baslik" placeholder="ör. Michelin 2026 fiyat listesi"></label>
    <label>Rakip Marka<input class="giris" id="dy-marka" placeholder="opsiyonel"></label>
    <label>Not<textarea class="giris" id="dy-not" rows="2"></textarea></label>
    <label class="btn cizgili dosya-btn" style="display:inline-block;margin-top:8px">📎 Dosya / Foto Seç<input type="file" id="dy-file" accept="image/*,application/pdf" capture="environment" hidden></label>
    <div id="dy-secili" style="font-size:12px;color:#64748b;margin-top:6px"></div>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Vazgeç</button><button class="btn" id="dy-yukle">Yükle</button></div>`);
  let _data = null, _mime = null;
  document.getElementById("dy-file").addEventListener("change", (ev) => {
    const f = ev.target.files[0]; if (!f) return;
    if (f.size > 8 * 1024 * 1024) { uyari("Dosya 8MB'ı aşamaz."); ev.target.value = ""; return; }
    _mime = f.type;
    const rd = new FileReader();
    rd.onload = () => { _data = rd.result; document.getElementById("dy-secili").textContent = "✓ " + f.name + " (" + Math.round(f.size / 1024) + " KB)"; };
    rd.readAsDataURL(f);
  });
  document.getElementById("dy-yukle").addEventListener("click", async () => {
    if (!_data) { uyari("Bir dosya seçin."); return; }
    const btn = document.getElementById("dy-yukle"); btn.disabled = true; btn.textContent = "Yükleniyor…";
    try {
      await api("/api/saha/piyasa-dosya", { method: "POST", body: JSON.stringify({ tip: document.getElementById("dy-tip").value, baslik: g("dy-baslik") || null, rakip_marka: g("dy-marka") || null, mime: _mime, data: _data, notlar: g("dy-not") || null }) });
      kapatModal(); uyari("✓ Dosya yüklendi.", true); onSave();
    } catch (e) { btn.disabled = false; btn.textContent = "Yükle"; uyari(e.message); }
  });
}

function piyasaNotuModal(onSave) {
  modal(`
    <h3>📝 Piyasa Notu Paylaş</h3>
    <label>Başlık *<input class="giris" id="pn-baslik" placeholder="ör. Michelin zam yaptı"></label>
    <label>Not *<textarea class="giris" id="pn-icerik" rows="4" placeholder="Sahada duyduğun/gördüğün piyasa bilgisi…"></textarea></label>
    <div style="font-size:11px;color:#94a3b8">Bu not Duyurular > Piyasa Bilgisi olarak herkesle paylaşılır.</div>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Vazgeç</button><button class="btn" id="pn-kaydet">Paylaş</button></div>`);
  document.getElementById("pn-kaydet").addEventListener("click", async () => {
    const baslik = g("pn-baslik"), icerik = g("pn-icerik");
    if (!baslik || !icerik) { uyari("Başlık ve not zorunlu."); return; }
    try {
      await api("/api/saha/duyurular", { method: "POST", body: JSON.stringify({ baslik, icerik, tip: "PIYASA", onem: "NORMAL" }) });
      kapatModal(); uyari("✓ Piyasa notu paylaşıldı.", true); onSave();
    } catch (e) { uyari(e.message); }
  });
}

async function vDuyurular() {'''
rep("async function vDuyurular() {", BLOCK, "view-modals")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
