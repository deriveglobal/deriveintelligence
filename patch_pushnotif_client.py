import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "PUSH_ROUTE_V2" in s:
    print("[skip] zaten yamali"); sys.exit(0)

def rep(old, new, tag):
    global s
    assert s.count(old) == 1, "anchor %s count=%d" % (tag, s.count(old))
    s = s.replace(old, new, 1); print("[ok]", tag)

# 1) pushRoute + inbox fonksiyonları (renderReception öncesine)
FUNCS = r'''async function pushRoute(d) {  /* PUSH_ROUTE_V2 — bildirime tıklayınca ilgili kayda git */
  try {
    if (!d || !S || !S.container) return;
    const t = String(d.type || ""), id = d.id;
    setRoom("saha");
    if (t === "ziyaret") { await loadView("ziyaretler"); if (id && typeof ziyaretDetayModal === "function") setTimeout(function () { try { ziyaretDetayModal(id); } catch (e) {} }, 250); return; }
    if (t === "duyuru")  { await loadView("duyurular"); if (id && typeof duyuruDetayModal === "function") setTimeout(function () { try { duyuruDetayModal(id); } catch (e) {} }, 250); return; }
    if (t === "teklif_yeni" || t === "teklif_onay" || t === "teklif_red") { await loadView("iskonto"); return; }
    if (t === "mesaj" || t === "yayim") { await loadView("mesajlar"); return; }
    if (t === "hatirlatma") { await loadView("bugun"); return; }
    await loadView("bugun");
  } catch (e) {}
}
async function bildirimModal() {  /* PUSH_ROUTE_V2 — bildirim kutusu */
  modal(`<h3>🔔 Bildirimler</h3><div id="bldrm-liste" style="max-height:60vh;overflow-y:auto;margin-top:8px"><div class="sub2" style="color:#94a3b8">Yükleniyor…</div></div><div class="modal-btnlar"><button class="btn gri" id="bldrm-hepsi">Tümünü okundu</button><button class="btn gri" data-kapat>Kapat</button></div>`);
  const box = document.getElementById("bldrm-liste");
  try {
    const { bildirimler = [] } = await api("/api/saha/bildirimler");
    if (!bildirimler.length) { box.innerHTML = `<div class="sub2" style="color:#94a3b8;padding:8px">Henüz bildirim yok.</div>`; }
    else box.innerHTML = bildirimler.map(function (b, i) { return `<button class="bldrm-row" data-i="${i}" style="display:block;width:100%;text-align:left;padding:10px;margin-bottom:6px;border:1px solid #e2e8f0;border-radius:10px;background:${b.okundu ? "#fff" : "#eff6ff"};cursor:pointer"><div style="font-weight:600;font-size:14px;color:#0f172a">${esc(b.baslik || "")}</div><div style="font-size:12px;color:#475569;margin-top:1px">${esc(b.govde || "")}</div><div style="font-size:11px;color:#94a3b8;margin-top:2px">${b.created_at ? new Date(b.created_at).toLocaleString("tr-TR") : ""}</div></button>`; }).join("");
    box.querySelectorAll(".bldrm-row").forEach(function (el) {
      el.addEventListener("click", function () {
        const b = bildirimler[Number(el.dataset.i)];
        try { api("/api/saha/bildirimler/okundu", { method: "POST", body: JSON.stringify({ id: b.id }) }); } catch (e) {}
        kapatModal();
        pushRoute(b.data || {});
      });
    });
  } catch (e) { box.innerHTML = `<div class="sub2" style="padding:8px">${esc(e.message)}</div>`; }
  document.getElementById("bldrm-hepsi")?.addEventListener("click", async function () {
    try { await api("/api/saha/bildirimler/okundu", { method: "POST", body: JSON.stringify({}) }); } catch (e) {}
    kapatModal(); bildirimSayisiYukle();
  });
}
async function bildirimSayisiYukle() {  /* PUSH_ROUTE_V2 */
  try {
    const r = await api("/api/saha/bildirimler");
    const okunmamis = (r && r.okunmamis) || 0;
    const bdg = document.getElementById("rec-bell-badge");
    if (bdg) { if (okunmamis > 0) { bdg.textContent = okunmamis > 99 ? "99+" : String(okunmamis); bdg.style.display = ""; } else { bdg.style.display = "none"; } }
  } catch (e) {}
}
'''
rep("function renderReception() {", FUNCS + "\nfunction renderReception() {", "funcs")

# 2) Cold-start fix — tıklama dinleyicisini AÇILIŞTA bağla
rep(
'  // Check for navigation queued from BI hub before this module was initialized',
'''  // PUSH_ROUTE_V2 — bildirim tıklama dinleyicisini açılışta bağla (cold-start'ta ana sayfaya düşme fix'i)
  try {
    const _PC = window.Capacitor;
    if (_PC && _PC.isNativePlatform && _PC.isNativePlatform() && _PC.Plugins && _PC.Plugins.PushNotifications && !window.__pushTap) {
      window.__pushTap = true;
      _PC.Plugins.PushNotifications.addListener("pushNotificationActionPerformed", function (ev) {
        try { const _dd = (ev && ev.notification && ev.notification.data) || {}; pushRoute(_dd); } catch (e) {}
      });
    }
  } catch (e) {}
  // Check for navigation queued from BI hub before this module was initialized''',
"cold-start")

# 3) Reception başlığına 🔔 zil + rozet
rep(
'      <div class="rec-hi">${selam}${ad ? ", " + esc(ad) : ""} 👋</div>',
'''      <div style="display:flex;align-items:center;justify-content:space-between;gap:8px">
        <div class="rec-hi">${selam}${ad ? ", " + esc(ad) : ""} 👋</div>
        <button id="rec-bell" title="Bildirimler" style="position:relative;background:none;border:none;font-size:24px;cursor:pointer;padding:4px;line-height:1">🔔<span id="rec-bell-badge" style="display:none;position:absolute;top:-2px;right:-2px;background:#ef4444;color:#fff;font-size:10px;min-width:16px;height:16px;border-radius:8px;line-height:16px;text-align:center;padding:0 3px;font-weight:700">0</span></button>
      </div>''',
"bell-html")

# 4) Zili bağla + rozet sayısını yükle
rep(
'  m.querySelectorAll(".rec-tile").forEach(b => b.addEventListener("click", () => setRoom(b.dataset.room)));',
'''  m.querySelectorAll(".rec-tile").forEach(b => b.addEventListener("click", () => setRoom(b.dataset.room)));
  m.querySelector("#rec-bell")?.addEventListener("click", bildirimModal);
  bildirimSayisiYukle();''',
"bell-wire")

# 5) Reception PUSH_KAYIT_V1 tap handler → pushRoute
rep(
'            if (d.room && typeof setRoom === "function") setRoom(d.room);',
'            pushRoute(d);',
"tap-handler")

open(F, "w", encoding="utf-8").write(s)
print("[done] PUSH_ROUTE_V2")
