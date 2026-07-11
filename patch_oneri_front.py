# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ONERI_THREAD_FRONT — Öneriler becomes a real tab with threads:
#  - everyone gets an "Öneriler" tab (rep = own tickets, staff = all) + unread badge
#  - tapping a ticket opens the thread: full history, reply box, status (staff only)
#  - the 💡 quick-submit stays; its history list now opens the thread instead of
#    showing a dead one-line note
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) tab (all roles — a rep's support inbox is theirs too)
rep(
'''    ["duyurular", "📢", "Duyurular"], ["mesajlar", "💬", "Mesajlar"],''',
'''    ["duyurular", "📢", "Duyurular"], ["mesajlar", "💬", "Mesajlar"], ["oneriler", "💡", "Öneriler"],''',
    "oneri-tab")

# 2) router
rep(
'''duyurular: vDuyurular, mesajlar: vMesajlar, sistem: vSistem }[v] || vBugun)();''',
'''duyurular: vDuyurular, mesajlar: vMesajlar, oneriler: vOneriler, sistem: vSistem }[v] || vBugun)();''',
    "oneri-route")

# 3) unread badge on home
rep(
'''    if (duyurular_yeni_sayisi) tabBadge("duyurular", duyurular_yeni_sayisi);
    if (mesaj_okunmamis) tabBadge("mesajlar", mesaj_okunmamis);''',
'''    if (duyurular_yeni_sayisi) tabBadge("duyurular", duyurular_yeni_sayisi);
    if (mesaj_okunmamis) tabBadge("mesajlar", mesaj_okunmamis);
    (async () => {
      try {
        const { oneriler = [] } = await api("/api/saha/oneriler");
        tabBadge("oneriler", oneriler.filter(o => o.okunmamis).length);
      } catch {}
    })();''',
    "oneri-badge")

# 4) the 💡 history list -> opens the thread
rep(
'''  const gecmisHtml = gecmis.length ? `
    <details style="margin-top:16px">
      <summary style="cursor:pointer;font-size:12px;color:#9ca3af;padding:4px 0">Geçmiş önerilerim (${gecmis.length})</summary>
      <div style="margin-top:8px;display:flex;flex-direction:column;gap:6px;max-height:180px;overflow-y:auto">
        ${gecmis.map(o => `
          <div style="background:#0f172a;border-radius:8px;padding:8px 10px;font-size:12px">
            <div style="display:flex;justify-content:space-between;align-items:center;gap:8px">
              <span style="color:#e5e7eb;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(o.baslik)}</span>
              <span style="flex-shrink:0;background:${durumRenk[o.durum]};color:#fff;border-radius:4px;padding:1px 6px;font-size:10px">${durumLabel[o.durum]}</span>
            </div>
            ${o.yonetici_notu ? `<div style="color:#9ca3af;margin-top:3px;font-style:italic">${esc(o.yonetici_notu)}</div>` : ""}
          </div>`).join("")}
      </div>
    </details>` : "";''',
'''  const gecmisHtml = gecmis.length ? `
    <details style="margin-top:16px" open>
      <summary style="cursor:pointer;font-size:12px;color:#9ca3af;padding:4px 0">Geçmiş kayıtlarım (${gecmis.length}) — durumu görmek için tıklayın</summary>
      <div style="margin-top:8px;display:flex;flex-direction:column;gap:6px;max-height:200px;overflow-y:auto">
        ${gecmis.map(o => `
          <div data-goid="${o.id}" style="background:#0f172a;border-radius:8px;padding:8px 10px;font-size:12px;cursor:pointer">
            <div style="display:flex;justify-content:space-between;align-items:center;gap:8px">
              <span style="color:#e5e7eb;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${o.okunmamis ? "🔴 " : ""}${esc(o.baslik)}</span>
              <span style="flex-shrink:0;background:${durumRenk[o.durum]};color:#fff;border-radius:4px;padding:1px 6px;font-size:10px">${durumLabel[o.durum]}</span>
            </div>
            <div style="color:#64748b;margin-top:3px">${o.mesaj_sayisi || 1} mesaj${o.okunmamis ? " · yeni yanıt var" : ""}</div>
          </div>`).join("")}
      </div>
    </details>` : "";''',
    "oneri-history-clickable")

# 5) wire history clicks
rep(
'''  document.getElementById("on-gonder").addEventListener("click", async () => {
    const kategori = document.getElementById("on-kat").value;''',
'''  document.querySelectorAll("[data-goid]").forEach(el => el.addEventListener("click", () => {
    kapatModal(); oneriThreadModal(el.dataset.goid);
  }));

  document.getElementById("on-gonder").addEventListener("click", async () => {
    const kategori = document.getElementById("on-kat").value;''',
    "oneri-history-wire")

# 6) the Öneriler view + the thread modal
rep(
'''async function oneriModal() {''',
'''const ONERI_DURUM_RENK  = { YENI: "#6b7280", INCELENIYOR: "#f59e0b", TAMAMLANDI: "#16a34a", REDDEDILDI: "#ef4444" };
const ONERI_DURUM_ETIKET = { YENI: "Yeni", INCELENIYOR: "İnceleniyor", TAMAMLANDI: "Tamamlandı", REDDEDILDI: "Reddedildi" };
const ONERI_KAT = { HATA: "🐛 Hata", OZELLIK: "✨ Özellik", UI: "🎨 Arayüz", DIGER: "💬 Diğer" };

// ── ÖNERİLER / DESTEK (rep: kendi kayıtları · yönetici: tümü) ────────────────
async function vOneriler() {
  try {
    const { oneriler = [], staff } = await api("/api/saha/oneriler");
    tabBadge("oneriler", oneriler.filter(o => o.okunmamis).length);

    const kart = (o) => `
      <div class="kart" data-oid="${o.id}" style="padding:10px 12px;margin-bottom:6px;cursor:pointer;${o.okunmamis ? "border-left:3px solid #ef4444" : ""}">
        <div style="display:flex;justify-content:space-between;align-items:center;gap:8px">
          <span style="font-weight:600;font-size:13px;color:#0f172a;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
            ${o.okunmamis ? "🔴 " : ""}${esc(o.baslik)}
          </span>
          <span style="flex-shrink:0;background:${ONERI_DURUM_RENK[o.durum]};color:#fff;border-radius:4px;padding:2px 8px;font-size:11px;font-weight:600">${ONERI_DURUM_ETIKET[o.durum] || o.durum}</span>
        </div>
        <div style="font-size:11px;color:#64748b;margin-top:3px">
          ${esc(ONERI_KAT[o.kategori] || o.kategori)}${staff ? " · " + esc(o.kullanici || "-") : ""}
          · ${o.mesaj_sayisi || 1} mesaj
          · ${new Date(o.son_mesaj_at || o.ts).toLocaleDateString("tr-TR")}
        </div>
      </div>`;

    const acik = oneriler.filter(o => ["YENI", "INCELENIYOR"].includes(o.durum));
    const kapali = oneriler.filter(o => !["YENI", "INCELENIYOR"].includes(o.durum));

    main().innerHTML = `
      <div style="padding:12px">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
          <div style="font-size:16px;font-weight:700">💡 ${staff ? "Öneriler & Destek" : "Kayıtlarım"}</div>
          <button class="btn kucuk" id="on-yeni">＋ Yeni</button>
        </div>
        ${!oneriler.length ? `<div class="saha-bos">Henüz kayıt yok.</div>` : ""}
        ${acik.length ? `<h4 class="bolum-baslik">Açık (${acik.length})</h4>${acik.map(kart).join("")}` : ""}
        ${kapali.length ? `<h4 class="bolum-baslik">Kapanmış (${kapali.length})</h4>${kapali.map(kart).join("")}` : ""}
      </div>`;

    document.getElementById("on-yeni")?.addEventListener("click", () => oneriModal());
    main().querySelectorAll("[data-oid]").forEach(el =>
      el.addEventListener("click", () => oneriThreadModal(el.dataset.oid)));
  } catch (e) { main().innerHTML = hata(e); }
}

// ── Bir kaydın tam geçmişi + yanıt + (yönetici) durum ────────────────────────
async function oneriThreadModal(id) {
  let d;
  try { d = await api(`/api/saha/oneriler/${id}`); }
  catch (e) { uyari(e.message); return; }
  const { oneri: o, mesajlar = [], staff, ben } = d;

  const satir = (m) => m.tip === "DURUM"
    ? `<div style="text-align:center;margin:8px 0"><span style="background:#e2e8f0;color:#475569;border-radius:10px;padding:2px 10px;font-size:11px">${esc(m.mesaj)} · ${esc(m.yazar)}</span></div>`
    : `<div style="display:flex;flex-direction:column;align-items:${m.user_id === ben ? "flex-end" : "flex-start"};margin-bottom:8px">
         <div style="max-width:85%;background:${m.user_id === ben ? "#0284c7" : "#f1f5f9"};color:${m.user_id === ben ? "#fff" : "#0f172a"};border-radius:10px;padding:8px 10px;font-size:13px;white-space:pre-wrap">${esc(m.mesaj)}</div>
         <div style="font-size:10px;color:#94a3b8;margin-top:2px">${esc(m.yazar)} · ${new Date(m.ts).toLocaleString("tr-TR")}</div>
       </div>`;

  modal(`
    <h3 style="margin-bottom:4px">${esc(o.baslik)}</h3>
    <div style="font-size:11px;color:#64748b;margin-bottom:10px">
      ${esc(ONERI_KAT[o.kategori] || o.kategori)} · ${esc(o.kullanici || "-")} · ${new Date(o.ts).toLocaleDateString("tr-TR")}
      <span style="background:${ONERI_DURUM_RENK[o.durum]};color:#fff;border-radius:4px;padding:1px 6px;margin-left:4px">${ONERI_DURUM_ETIKET[o.durum] || o.durum}</span>
    </div>
    <div id="ot-thread" style="max-height:300px;overflow-y:auto;padding:8px;background:#fff;border:1px solid #e2e8f0;border-radius:10px">
      ${mesajlar.map(satir).join("")}
    </div>
    ${staff ? `
      <label style="display:block;margin-top:10px">
        <div class="giris-etiket">Durum</div>
        <select class="giris" id="ot-durum">
          ${Object.entries(ONERI_DURUM_ETIKET).map(([k, l]) => `<option value="${k}" ${o.durum === k ? "selected" : ""}>${l}</option>`).join("")}
        </select>
      </label>` : ""}
    <label style="display:block;margin-top:8px">
      <div class="giris-etiket">${staff ? "Yanıt" : "Yeni mesaj"}</div>
      <textarea class="giris" id="ot-mesaj" rows="3" placeholder="${staff ? "Yanıtınızı yazın…" : "Eklemek istediğiniz bir şey var mı?"}"></textarea>
    </label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn" id="ot-gonder">Gönder</button>
    </div>`);

  const th = document.getElementById("ot-thread");
  if (th) th.scrollTop = th.scrollHeight;

  document.getElementById("ot-gonder").addEventListener("click", async () => {
    const mesaj = document.getElementById("ot-mesaj").value.trim();
    const yeniDurum = staff ? document.getElementById("ot-durum")?.value : null;
    const durumDegisti = staff && yeniDurum && yeniDurum !== o.durum;
    if (!mesaj && !durumDegisti) { uyari("Bir mesaj yazın veya durumu değiştirin."); return; }
    const btn = document.getElementById("ot-gonder");
    btn.disabled = true; btn.textContent = "Gönderiliyor…";
    try {
      if (staff && (durumDegisti || mesaj)) {
        await api(`/api/saha/oneriler/${id}`, {
          method: "PUT",
          body: JSON.stringify({ durum: durumDegisti ? yeniDurum : null, yonetici_notu: mesaj || null })
        });
      } else if (mesaj) {
        await api(`/api/saha/oneriler/${id}/mesaj`, { method: "POST", body: JSON.stringify({ mesaj }) });
      }
      kapatModal();
      uyari("✓ Gönderildi.", true);
      if (S.view === "oneriler") await loadView("oneriler");
    } catch (e) {
      btn.disabled = false; btn.textContent = "Gönder";
      uyari(e.message);
    }
  });
}

async function oneriModal() {''',
    "oneri-view-and-thread")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
