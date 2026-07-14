// ═══════════════════════════════════════════════════════════════════════════
// KRB SAHA — Saha ziyaretleri + iskonto onay modülü (mobile-first shell)
// İki şemsiye: TÜKETİCİ (PSR bayi) / TİCARİ (TBR-OTR filo, maden, inşaat)
// initSahaSurface(container, me, sub, opts) — app.js loadSahaSurface çağırır
// ═══════════════════════════════════════════════════════════════════════════

const MARKALAR = [
  "Lassa", "Bridgestone", "Petlas", "Starmaxx", "Continental", "Hankook",
  "Goodyear", "Dunlop", "Michelin", "Pirelli", "Kumho", "Nexen", "Laufenn",
  "Dayton", "Delinte", "Sentury", "Waterfall", "Sava", "Kormoran", "Riken",
  "Aeolus", "Windpower", "Double Coin", "Magna", "Techking", "Advance"
];
const RAKIPLER = [
  "Yuke", "Mutaf", "Ayko", "Keskin", "Tatko", "Has-Kar", "Erenler",
  "Çakıroğlu", "Bayraktarlar", "İntaş", "Soylular", "Acarlar"
];
const BAYILIKLER = [
  "Lastik Park", "Express Lastik", "Lastiğim", "Dunlop", "Bridgestone",
  "Michelin", "Pirelli", "Continental", "Petlas", "Goodyear"
];
const SEKTORLER = ["Lojistik", "Nakliyat", "Maden", "İnşaat", "Hafriyat", "Kooperatif", "Tarım", "Servis/Filo", "Diğer"];
const DURUM_ETIKET = {
  YENI_NOKTA: ["Yeni Nokta", "#0ea5e9"], ESKI_NOKTA: ["Eski Nokta", "#8b5cf6"],
  AKTIF_MUSTERI: ["Aktif Müşteri", "#10b981"], PASIF_NOKTA: ["Pasif Nokta", "#94a3b8"],
  RISKLI_NOKTA: ["Riskli Nokta", "#ef4444"]
};
const ISK_DURUM = {
  ONAYLANDI: ["Onaylandı", "#10b981"], REDDEDILDI: ["Reddedildi", "#ef4444"],
  BEKLIYOR_MUDUR: ["Müdür Onayı Bekliyor", "#f59e0b"], BEKLIYOR_GM: ["GM Onayı Bekliyor", "#f97316"]
};

let S = null; // module state

export function initSahaSurface(container, me, sub, opts = {}) {
  const headers = opts.authHeaders || (() => {
    const t = localStorage.getItem("platformSessionToken") || "";
    return t ? { Authorization: "Bearer " + t } : {};
  });
  const role = (me.tenantRole === "platform_owner" || sub.moduleRole === "admin") ? "admin"
    : (sub.moduleRole === "manager" ? "manager" : "rep");
  // platform_owner (Derive) and tenant admin both map to role 'admin'. Keep the real
  // distinction: platform telemetry must never be shown to a tenant.
  const isOwner = me.tenantRole === "platform_owner";
  S = {
    container, me, role, isOwner, headers,
    view: "ziyaretler", semsiye: "", // '' = tümü | TUKETICI | TICARI
    ziyaretler: [], musteriler: [], talepler: [], ayarlar: null,
    fotoUrls: new Map(),
    gosterilmisOnaylandi: new Set() // track quote IDs already toasted to rep
  };
  injectStyles();
  container.innerHTML = layout();
  wireNav();
  // Pre-select şemsiye from rep's profile setting (stored in permissions_json.saha_tip)
  if (role === "rep" && sub.permissions?.saha_tip) {
    S.semsiye = sub.permissions.saha_tip.toUpperCase();
    S.container.querySelectorAll("#saha-semsiye .chip").forEach(b => {
      b.classList.toggle("on", b.dataset.s === S.semsiye);
    });
  }
  // Hub canlı akışından derin bağlantı: ilgili sekme + kaydın kendisi
  window.__sahaGit = async function(tip, kayitId) {
    const v = tip === "ZIYARET" ? "ziyaretler" : (tip === "TEKLIF" || tip === "ISKONTO") ? "iskonto" : "ziyaretler";
    S.container.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x.dataset.v === v));
    await loadView(v);
    if (!kayitId) return;
    if (tip === "ZIYARET" && S.ziyaretler.some(z => z.id === kayitId)) {
      ziyaretDetayModal(kayitId);
      return;
    }
    const el = document.getElementById("kayit-" + kayitId);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "center" });
      el.classList.add("kayit-vurgu");
      setTimeout(() => el.classList.remove("kayit-vurgu"), 3000);
    }
  };
  // Check for navigation queued from BI hub before this module was initialized
  if (window.__sahaPendingNav) {
    const pendingTip = window.__sahaPendingNav;
    window.__sahaPendingNav = null;
    window.__sahaGit(pendingTip, null);
  } else {
    loadView("bugun");
  }
}

// ── API yardımcıları ─────────────────────────────────────────────────────────
// ── Hata logger (fire-and-forget) ────────────────────────────────────────────
function logHata(tip, partial = {}) {
  try {
    fetch("/api/saha/log-hata", {
      method: "POST",
      headers: { "Content-Type": "application/json", ...S.headers() },
      body: JSON.stringify({
        tip,
        view_adi: S.view || null,
        user_agent: navigator.userAgent.slice(0, 200),
        ...partial
      })
    }).catch(() => {});
  } catch {}
}

// Global JS error capture
if (typeof window !== "undefined") {
  window.addEventListener("error", ev => {
    logHata("JS_HATA", { hata_mesaji: `${ev.message} @ ${ev.filename}:${ev.lineno}`, extra: { colno: ev.colno } });
  });
  window.addEventListener("unhandledrejection", ev => {
    logHata("JS_HATA", { hata_mesaji: String(ev.reason?.message || ev.reason || "UnhandledRejection").slice(0, 500) });
  });
}

function _asistanBar(mesaj, opts) {
  opts = opts || {};
  let el = document.getElementById("asistan-cevap-bar");
  if (!el) { el = document.createElement("div"); el.id = "asistan-cevap-bar"; document.body.appendChild(el); }
  el.style.cssText = "position:fixed;left:50%;bottom:82px;transform:translateX(-50%);z-index:99999;max-width:92%;background:linear-gradient(135deg,#7c3aed,#4f46e5);color:#fff;padding:12px 15px;border-radius:14px;box-shadow:0 10px 34px rgba(79,70,229,.45);font-size:13.5px;line-height:1.5;display:flex;gap:10px;align-items:flex-start";
  el.innerHTML = '<span style="font-size:18px;flex-shrink:0">🤖</span><span>' + (mesaj ? String(mesaj).replace(/</g, "&lt;") : "") + '</span>';
  if (el._t) clearTimeout(el._t);
  el._t = setTimeout(function () { if (el) { el.style.transition = "opacity .5s"; el.style.opacity = "0"; setTimeout(function () { el && el.remove(); }, 500); } }, opts.sure || 9000);
  return el;
}
function asistanOkuyor() { return _asistanBar("okuyorum…", { sure: 15000 }); }
function asistanCevap(mesaj) { if (!mesaj) { const e = document.getElementById("asistan-cevap-bar"); if (e) e.remove(); return; } _asistanBar(mesaj, { sure: 9000 }); }

async function api(path, options = {}) {
  const t0 = Date.now();
  const _repWrite = (options.method === "POST" || options.method === "PUT") && /\/api\/saha\/(notlar|ziyaretler|teklifler)/.test(path) && !/\/foto/.test(path) && !/"action":"(checkin|iptal)"/.test(options.body || "");
  if (_repWrite) asistanOkuyor();
  const res = await fetch(path, {
    ...options,
    headers: { "Content-Type": "application/json", ...S.headers(), ...(options.headers || {}) }
  }).catch(networkErr => {
    logHata("AG_HATA", { endpoint: path, hata_mesaji: networkErr.message });
    throw networkErr;
  });
  const duration_ms = Date.now() - t0;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    logHata("API_HATA", {
      endpoint: path,
      http_status: res.status,
      hata_mesaji: (data.error || `İstek başarısız (${res.status})`).slice(0, 500),
      duration_ms
    });
    throw new Error(data.error || `İstek başarısız (${res.status})`);
  }
  if (duration_ms > 4000) {
    logHata("YAVAS_API", { endpoint: path, duration_ms });
  }
  if (_repWrite) { asistanCevap(data && data.asistan); } else if (data && data.asistan) { asistanCevap(data.asistan); }
  return data;
}
async function fotoUrl(id) {
  if (S.fotoUrls.has(id)) return S.fotoUrls.get(id);
  const res = await fetch(`/api/saha/foto/${id}`, { headers: S.headers() });
  if (!res.ok) return "";
  const url = URL.createObjectURL(await res.blob());
  S.fotoUrls.set(id, url);
  return url;
}

// ── İskelet ──────────────────────────────────────────────────────────────────
function dahaSheet() {
  const items = (S.moreTabs || []).map(([id, ico, l]) => {
    const bdg = (S.moreBadges && S.moreBadges[id]) ? `<sup style="position:absolute;top:8px;right:14px;background:#ef4444;color:#fff;border-radius:9px;padding:0 5px;font-size:10px">${S.moreBadges[id]}</sup>` : "";
    return `<button class="daha-item" data-v="${id}" style="position:relative;display:flex;flex-direction:column;align-items:center;gap:5px;padding:16px 8px;border:1px solid #e2e8f0;border-radius:12px;background:#fff;cursor:pointer">${bdg}<span style="font-size:26px">${ico}</span><span style="font-size:12px;color:#334155;font-weight:600">${l}</span></button>`;
  }).join("");
  modal(`<h3 style="margin:0 0 12px">Daha Fazla</h3><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px">${items}</div><div class="modal-btnlar"><button class="btn gri" data-kapat>Kapat</button></div>`);
  document.querySelectorAll(".daha-item").forEach(b => b.addEventListener("click", () => { kapatModal(); loadView(b.dataset.v); }));
}

function layout() {
  const tabs = [
    ["bugun", "🏠", "Bugün"],
    ["ziyaretler", "📋", "Ziyaretler"], ["plan", "🗓️", "Plan"],
    ["musteriler", "🏪", "Müşteri"], ["iskonto", "💰", "Teklif"], ["rapor", "📊", "Rapor"], ["piyasa", "🏷️", "Piyasa"],
    ["notlarim", "📝", "Notlarım"], ["rep-brain", "🤖", "Asistan"],
    ["rakip", "🏷", "Rakip Fiyatlar"],
    ["duyurular", "📢", "Duyurular"], ["mesajlar", "💬", "Mesajlar"], ["oneriler", "💡", "Öneriler"],
    ...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Temsilci"]] : []),
    ...(S.isOwner ? [["sistem", "🔧", "Sistem"]] : [])
  ];
  const CORE = ["bugun","ziyaretler","iskonto","rep-brain"];
  S.coreIds = CORE;
  const coreTabs = tabs.filter(t => CORE.includes(t[0]));
  S.moreTabs = tabs.filter(t => !CORE.includes(t[0]));
  return `
  <div class="saha-app">
    <header class="saha-head">
      <div class="saha-title">KRB <b>Saha</b></div>
      <div class="saha-chips" id="saha-semsiye">
        <button data-s="" class="chip on">Tümü</button>
        <button data-s="TUKETICI" class="chip">Tüketici</button>
        <button data-s="TICARI" class="chip">Ticari</button>
      </div>
      <div class="saha-user">${esc(S.me.name || "")}<span class="saha-role">${S.role === "admin" ? "GM" : S.role === "manager" ? "Müdür" : "Saha"}</span><button id="saha-cikis" title="Çıkış Yap" style="background:none;border:none;color:#94a3b8;font-size:16px;cursor:pointer;padding:0 0 0 6px;line-height:1">⏏</button></div>
    </header>
    <main class="saha-main" id="saha-main"><div class="saha-load">Yükleniyor…</div></main>
    <nav class="saha-nav">
      ${coreTabs.map(([id, ico, l]) => `<button class="saha-tab${id === "bugun" ? " on" : ""}" data-v="${id}"><span>${ico}</span>${l}</button>`).join("")}
      <button class="saha-tab" data-v="daha"><span>⋯</span>Daha</button>
    </nav>
    <button id="saha-oneri-fab" title="Öneri / Geri Bildirim" style="
      position:fixed;bottom:72px;right:16px;z-index:200;
      width:44px;height:44px;border-radius:50%;border:none;
      background:#1d4ed8;color:#fff;font-size:20px;
      box-shadow:0 4px 12px rgba(0,0,0,.5);cursor:pointer;
      display:flex;align-items:center;justify-content:center;
      transition:transform .15s;
    ">💡</button>
    <div id="saha-modal"></div>
  </div>`;
}

function wireNav() {
  S.container.querySelectorAll(".saha-tab").forEach(b =>
    b.addEventListener("click", () => {
      if (b.dataset.v === "daha") { dahaSheet(); return; }
      loadView(b.dataset.v);
    }));
  S.container.querySelectorAll("#saha-semsiye .chip").forEach(b =>
    b.addEventListener("click", () => {
      S.container.querySelectorAll("#saha-semsiye .chip").forEach(x => x.classList.toggle("on", x === b));
      S.semsiye = b.dataset.s;
      loadView(S.view);
    }));
  S.container.querySelector("#saha-cikis")?.addEventListener("click", async () => {
    try {
      await fetch("/api/auth/logout", { method: "POST", headers: S.headers() });
    } catch {}
    // Clear all app.js session state so the login screen appears on redirect
    ["krbCurrentUserEmail","krbSession","currentPlatformUser","platformSessionToken"].forEach(k => localStorage.removeItem(k));
    window.location.href = "/?app=1";
  });
  // ── Draggable FAB ──────────────────────────────────────────────────────────
  const fab = S.container.querySelector("#saha-oneri-fab");
  if (fab) {
    // Restore saved position (validate it's within current viewport)
    try {
      const sv = JSON.parse(localStorage.getItem("saha-fab-pos") || "null");
      if (sv && sv.top >= 8 && sv.left >= 8 &&
          sv.top < window.innerHeight - 52 && sv.left < window.innerWidth - 52) {
        fab.style.bottom = "auto"; fab.style.right = "auto";
        fab.style.top = sv.top + "px"; fab.style.left = sv.left + "px";
      }
    } catch {}

    let dragging = false, didMove = false, startX, startY, startLeft, startTop;

    const onStart = (cx, cy) => {
      const r = fab.getBoundingClientRect();
      dragging = true; didMove = false;
      startX = cx; startY = cy; startLeft = r.left; startTop = r.top;
      fab.style.bottom = "auto"; fab.style.right = "auto";
      fab.style.top = startTop + "px"; fab.style.left = startLeft + "px";
      fab.style.transition = "none";
    };
    const onMove = (cx, cy) => {
      if (!dragging) return;
      const dx = cx - startX, dy = cy - startY;
      if (Math.abs(dx) > 4 || Math.abs(dy) > 4) didMove = true;
      fab.style.left = Math.max(8, Math.min(window.innerWidth  - 52, startLeft + dx)) + "px";
      fab.style.top  = Math.max(8, Math.min(window.innerHeight - 52, startTop  + dy)) + "px";
    };
    const onEnd = () => {
      if (!dragging) return;
      dragging = false; fab.style.transition = "";
      if (didMove) {
        const r = fab.getBoundingClientRect();
        try { localStorage.setItem("saha-fab-pos", JSON.stringify({ top: r.top, left: r.left })); } catch {}
      }
    };

    fab.addEventListener("mousedown",  e => { onStart(e.clientX, e.clientY); e.preventDefault(); });
    window.addEventListener("mousemove", e => onMove(e.clientX, e.clientY));
    window.addEventListener("mouseup",   () => onEnd());
    fab.addEventListener("touchstart", e => onStart(e.touches[0].clientX, e.touches[0].clientY), { passive: true });
    fab.addEventListener("touchmove",  e => { onMove(e.touches[0].clientX, e.touches[0].clientY); if (didMove) e.preventDefault(); }, { passive: false });
    fab.addEventListener("touchend",   () => onEnd());
    fab.addEventListener("click",      () => { if (!didMove) oneriModal(); });
  }
}

function main() { return S.container.querySelector("#saha-main"); }
function loadView(v) {
  S.view = v;
  const _navId = (S.coreIds || []).includes(v) ? v : "daha";
  S.container?.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x.dataset.v === _navId));
  const m = main();
  m.scrollTop = 0; // reset scroll position when switching tabs
  m.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
  return ({ bugun: vBugun, ziyaretler: vZiyaretler, plan: vPlan, musteriler: vMusteriler, iskonto: vIskonto, rapor: vRapor, temsilciler: vTemsilciler, notlarim: vNotlarim, 'rep-brain': vRepBrain, piyasa: vPiyasa, rakip: vRakip, duyurular: vDuyurular, mesajlar: vMesajlar, oneriler: vOneriler, sistem: vSistem }[v] || vBugun)();
}
function tipQS() { return S.semsiye ? `&tip=${S.semsiye}` : ""; }

// Tab badge: shows action-count on a nav tab
function tabBadge(v, sayi) {
  S.moreBadges = S.moreBadges || {};
  const isCore = (S.coreIds || ["bugun","ziyaretler","iskonto","rep-brain"]).includes(v);
  if (!isCore) {
    if (sayi > 0) S.moreBadges[v] = sayi; else delete S.moreBadges[v];
    sayi = Object.values(S.moreBadges).reduce((a, b) => a + Number(b || 0), 0);
  }
  const tab = S.container.querySelector(`.saha-tab[data-v="${isCore ? v : "daha"}"]`);
  if (!tab) return;
  const mevcut = tab.querySelector(".tab-rozet");
  if (sayi > 0) {
    if (mevcut) { mevcut.textContent = sayi; }
    else { tab.insertAdjacentHTML("beforeend", `<sup class="tab-rozet" style="background:#ef4444;color:#fff;border-radius:9px;padding:0 5px;font-size:10px;margin-left:2px;vertical-align:super">${sayi}</sup>`); }
  } else {
    mevcut?.remove();
  }
}

// ── GÜNLÜK BAŞLANGIÇ NOKTASI ────────────────────────────────────────────────
// Sadece gösterim: ilk check-in bunu otomatik belirler. Rota önerisi buradan başlar.
async function baslangicStripYukle() {
  const box = document.getElementById("bugun-baslangic");
  if (!box) return;
  let d = {};
  try { d = await api("/api/saha/gunluk-baslangic"); } catch { box.innerHTML = ""; return; }
  const b = d.bugun, merkez = d.merkez;

  if (b) {
    const yer = [b.sehir, b.ilce].filter(Boolean).join(" / ") || (b.lat ? `${b.lat}, ${b.lng}` : "—");
    box.innerHTML = `
      <div style="background:#ecfdf5;border:1px solid #a7f3d0;border-radius:10px;padding:8px 12px;margin-bottom:14px;display:flex;align-items:center;gap:8px;font-size:12px;color:#065f46">
        <span>📍</span>
        <span style="flex:1"><b>Bugünkü başlangıç:</b> ${esc(yer)}${b.kaynak === "OTOMATIK" ? ` <span style="color:#059669">· ilk check-in'den</span>` : ""}</span>
        <button class="btn kucuk cizgili" id="bs-sifirla" style="font-size:11px;padding:3px 8px">Sıfırla</button>
      </div>`;
    document.getElementById("bs-sifirla")?.addEventListener("click", async () => {
      try {
        await api("/api/saha/gunluk-baslangic", { method: "DELETE" });
        uyari("✓ Sıfırlandı — merkez konumun kullanılacak.", true);
        baslangicStripYukle();
      } catch (e) { uyari(e.message); }
    });
  } else {
    const merkezYer = merkez && (merkez.base_adres || (merkez.base_lat ? "kayıtlı merkez konum" : null));
    box.innerHTML = `
      <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:8px 12px;margin-bottom:14px;font-size:12px;color:#64748b">
        📍 Başlangıç: <b>${merkezYer ? esc(merkezYer) : "ayarlanmamış"}</b> — bugünün ilk <b>check-in</b>'inde otomatik güncellenir.
      </div>`;
  }
}

// ── BUGÜN (home) ─────────────────────────────────────────────────────────────
async function vBugun() {
  try {
    const { bugun, ziyaretler, duyurular_okunmamis, duyurular_yeni_sayisi = 0, rep_sayisi = 0, mesaj_okunmamis, teklifler, hatirlatmalar } = await api("/api/saha/bugun");

    if (duyurular_yeni_sayisi) tabBadge("duyurular", duyurular_yeni_sayisi);
    if (mesaj_okunmamis) tabBadge("mesajlar", mesaj_okunmamis);
    (async () => {
      try {
        const { oneriler = [] } = await api("/api/saha/oneriler");
        tabBadge("oneriler", oneriler.filter(o => o.okunmamis).length);
      } catch {}
    })();

    const tarihStr = new Date(bugun + "T12:00:00").toLocaleDateString("tr-TR", { weekday: "long", day: "numeric", month: "long" });
    const onemRenk   = { ACIL: "#dc2626", YUKSEK: "#d97706", NORMAL: "#0284c7" };
    const onemEtiket = { ACIL: "🚨 ACİL", YUKSEK: "⚠️ Önemli", NORMAL: "📢" };

    const secBlock = (ico, title, badge, badgeColor, body) => `
      <div style="margin-bottom:18px">
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px">
          <span style="font-size:14px;font-weight:700;color:#1e293b">${ico} ${title}</span>
          ${badge ? `<span style="background:${badgeColor};color:#fff;border-radius:10px;font-size:10px;font-weight:700;padding:2px 8px">${badge}</span>` : ""}
        </div>
        ${body}
      </div>`;

    const empty = txt => `<div style="color:#94a3b8;font-size:13px;font-style:italic;padding:6px 0">${txt}</div>`;

    const hatirlatmaHtml = hatirlatmalar.length
      ? hatirlatmalar.map(n => `
          <div class="kart" style="padding:10px 12px;border-left:3px solid #7c3aed;margin-bottom:6px">
            <div style="font-size:13px;color:#0f172a">${esc(n.icerik.slice(0, 80))}${n.icerik.length > 80 ? "…" : ""}</div>
            ${n.hatirlatma_tarihi ? `<div style="font-size:11px;color:#7c3aed;margin-top:2px">⏰ ${n.hatirlatma_tarihi}</div>` : ""}
          </div>`).join("")
      : "";

    const ziyaretHtml = ziyaretler.length === 0
      ? empty("Bugün planlanmış ziyaret yok")
      : ziyaretler.map(z => `
          <div class="kart" data-zid="${z.id}" style="padding:10px 12px;margin-bottom:6px;cursor:pointer">
            <div class="kart-ust">
              <b>${esc(z.musteri_adi || "")}</b>
              ${z.rep_adi
                ? `<span style="font-size:11px;color:#64748b">👤 ${esc(z.rep_adi)}</span>`
                : `<button class="btn mavi kucuk" data-checkin="${z.id}" style="font-size:11px;padding:3px 10px">✓ Check-in</button>`}
            </div>
            ${z.adres ? `<div style="font-size:12px;color:#64748b;margin-top:2px">📍 ${esc(z.adres)}</div>` : ""}
          </div>`).join("");

    const duyuruHtml = duyurular_okunmamis.length === 0
      ? empty("Okunmamış duyuru yok ✓")
      : duyurular_okunmamis.map(d => `
          <div class="kart" data-did="${d.id}" style="padding:10px 12px;margin-bottom:6px;cursor:pointer;border-left:3px solid ${onemRenk[d.onem] || "#0284c7"}">
            <div style="font-size:10px;font-weight:700;color:${d.tip === "PIYASA" ? "#0891b2" : onemRenk[d.onem]};margin-bottom:3px">${d.tip === "PIYASA" ? "📊 PİYASA" : (onemEtiket[d.onem] || "📢")}</div>
            <div style="font-size:13px;font-weight:600;color:#0f172a">${esc(d.baslik)}</div>
            <div style="font-size:11px;color:#64748b;margin-top:2px">${esc(d.yazan_adi)} · ${new Date(d.created_at).toLocaleDateString("tr-TR")}</div>
            <div style="font-size:11px;color:#64748b;margin-top:3px">👁 ${d.okuyan_sayisi}${rep_sayisi ? "/" + rep_sayisi : ""} gördü${!d.okundu ? ` · <span style="color:#0284c7;font-weight:600">● Yeni</span>` : ""}</div>
          </div>`).join("");

    const mesajHtml = `
      <div class="kart" id="bugun-mesaj-btn" style="padding:12px;cursor:pointer;${mesaj_okunmamis ? "border-left:3px solid #0284c7;" : ""}">
        <div class="kart-ust">
          <span>${S.role === "rep" ? "Yönetici ile Konuşma" : "Temsilci Mesajları"}</span>
          ${mesaj_okunmamis
            ? `<span class="rozet" style="background:#0284c7">${mesaj_okunmamis} yeni</span>`
            : `<span style="font-size:12px;color:#94a3b8">Güncel ✓</span>`}
        </div>
      </div>`;

    const teklifHtml = teklifler.length === 0
      ? empty("Bekleyen teklif yok")
      : teklifler.slice(0, 4).map(t => `
          <div class="kart" data-teklif-nav="1" style="padding:10px 12px;margin-bottom:6px;cursor:pointer">
            <div class="kart-ust">
              <b>${esc(t.musteri_adi)}</b>
              <span style="font-size:12px;font-weight:600;color:#d97706">${Number(t.toplam_tutar || 0).toLocaleString("tr-TR")} TL</span>
            </div>
            ${t.rep_adi ? `<div style="font-size:11px;color:#64748b">👤 ${esc(t.rep_adi)}</div>` : ""}
          </div>`).join("") +
        (teklifler.length > 4 ? `<div style="font-size:12px;color:#64748b;text-align:center;padding:4px 0">+${teklifler.length - 4} daha →</div>` : "");

    main().innerHTML = `
      <div style="padding:2px 0 24px">
        <div style="font-size:17px;font-weight:700;color:#0f172a;margin-bottom:10px;text-transform:capitalize">${tarihStr}</div>
        <div id="bugun-baslangic"></div>
        ${hatirlatmalar.length ? secBlock("⏰", "Hatırlatmalar", hatirlatmalar.length, "#7c3aed", hatirlatmaHtml) : ""}
        ${secBlock("📅", "Bugünün Ziyaretleri", ziyaretler.length || null, "#0ea5e9", ziyaretHtml)}
        ${secBlock("📢", "Okunmamış Duyurular", duyurular_okunmamis.length || null, "#dc2626", duyuruHtml)}
        ${secBlock("💬", "Mesajlar", mesaj_okunmamis || null, "#0284c7", mesajHtml)}
        ${secBlock("💰", "Bekleyen Teklifler", teklifler.length || null, "#d97706", teklifHtml)}
      </div>`;

    baslangicStripYukle();

    // check-in (rep only)
    main().querySelectorAll("[data-checkin]").forEach(btn =>
      btn.addEventListener("click", async e => {
        e.stopPropagation();
        const z = ziyaretler.find(x => x.id === btn.dataset.checkin);
        if (z) planTamamlaModal(z);
      }));

    // visit card → detail
    main().querySelectorAll("[data-zid]").forEach(el =>
      el.addEventListener("click", e => {
        if (e.target.closest("[data-checkin]")) return;
        ziyaretDetayModal(el.dataset.zid);
      }));

    // duyuru card → detail
    main().querySelectorAll("[data-did]").forEach(el =>
      el.addEventListener("click", () => duyuruDetayModal(el.dataset.did)));

    // mesaj → mesajlar tab
    main().querySelector("#bugun-mesaj-btn")?.addEventListener("click", () => switchSahaTab("mesajlar"));

    // teklif → iskonto tab
    main().querySelectorAll("[data-teklif-nav]").forEach(el =>
      el.addEventListener("click", () => switchSahaTab("iskonto")));

  } catch(e) { main().innerHTML = hata(e); }
}

function switchSahaTab(tabId) {
  S.container.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x.dataset.v === tabId));
  loadView(tabId);
}

// ── ZİYARETLER ───────────────────────────────────────────────────────────────
async function vZiyaretler() {
  try {
    const { ziyaretler } = await api(`/api/saha/ziyaretler?durum=TAMAMLANDI${tipQS()}`);
    S.ziyaretler = ziyaretler;
    const bugunFiltre = !!window.__sahaGunFiltre;
    window.__sahaGunFiltre = false;
    const bugunISO = new Date().toISOString().slice(0, 10);

    function renderListe(repFiltre) {
      let liste = bugunFiltre
        ? ziyaretler.filter(z => z.ziyaret_tarihi && String(z.ziyaret_tarihi).slice(0, 10) === bugunISO)
        : ziyaretler;
      if (repFiltre) liste = liste.filter(z => (z.rep_full_name || z.rep_adi || "") === repFiltre);

      const ara = (document.getElementById("ziy-filtre")?.value || "").trim().toLocaleLowerCase("tr");
      if (ara) {
        liste = liste.filter(z =>
          [z.firma, z.il, z.ilce, z.lokasyon_adi, z.notlar, z.rep_full_name, z.rep_adi]
            .some(v => String(v || "").toLocaleLowerCase("tr").includes(ara)));
      }

      const listEl = document.getElementById("ziyaret-liste");
      if (listEl) listEl.innerHTML = liste.length
        ? liste.map(zKart).join("")
        : `<div class="saha-bos">${ara ? "Aramayla eşleşen ziyaret yok." : repFiltre ? "Bu temsilciye ait ziyaret yok." : bugunFiltre ? "Bugün tamamlanan ziyaret yok." : "Henüz ziyaret yok. İlk ziyaretini kaydet!"}</div>`;
      listEl?.querySelectorAll("[data-zid]").forEach(el =>
        el.addEventListener("click", () => ziyaretDetayModal(el.dataset.zid)));
    }

    // Rep filter dropdown — only for manager/admin, fetched from DB
    let repSecEl = "";
    if (S.role !== "rep") {
      try {
        const { reps } = await api("/api/saha/reps");
        if (reps.length) {
          repSecEl = `<select id="rep-filtre" class="giris" style="margin-bottom:10px;font-size:13px">
            <option value="">Tüm temsilciler</option>
            ${reps.map(r => `<option value="${esc(r.full_name)}">${esc(r.full_name)}</option>`).join("")}
          </select>`;
        }
      } catch { /* rep listesi yüklenemedi, filtre gösterilmez */ }
    }

    const filtreBandi = bugunFiltre
      ? `<div style="background:#dbeafe;border:1px solid #93c5fd;border-radius:9px;padding:8px 12px;font-size:12px;color:#1d4ed8;margin-bottom:10px">
           📅 Bugünkü ziyaretler — ${ziyaretler.filter(z => String(z.ziyaret_tarihi).slice(0,10) === bugunISO).length} kayıt
           <button style="background:none;border:0;color:#1d4ed8;font-size:11px;cursor:pointer;text-decoration:underline;margin-left:8px" id="filtre-kaldir">Tümünü göster</button>
         </div>`
      : "";

    main().innerHTML = `
      <button class="saha-cta" id="yeni-ziyaret">＋ Yeni Ziyaret</button>
      <input class="giris" id="ziy-filtre" placeholder="🔍 Ara — firma, şehir, not…" autocomplete="off">
      ${filtreBandi}
      ${repSecEl}
      <div id="ziyaret-liste"></div>`;

    renderListe("");
    main().querySelector("#yeni-ziyaret").addEventListener("click", () => musteriSecModal(z => ziyaretFormModal(z, "kaydet")));
    main().querySelector("#filtre-kaldir")?.addEventListener("click", () => loadView("ziyaretler"));
    main().querySelector("#rep-filtre")?.addEventListener("change", function() { renderListe(this.value); });
    let _zt = null;
    main().querySelector("#ziy-filtre")?.addEventListener("input", () => {
      clearTimeout(_zt);
      _zt = setTimeout(() => renderListe(main().querySelector("#rep-filtre")?.value || ""), 200);
    });
  } catch (e) { main().innerHTML = hata(e); }
}

function zKart(z) {
  const tarih = z.ziyaret_tarihi ? new Date(z.ziyaret_tarihi).toLocaleDateString("tr-TR") : "";
  const [dl, dc] = DURUM_ETIKET[z.musteri_durum] || ["", "#999"];
  return `
  <div class="kart" data-zid="${z.id}">
    <div class="kart-ust">
      <b>${esc(z.firma)}</b>
      <span class="rozet" style="background:${z.tip === "TUKETICI" ? "#0ea5e9" : "#f59e0b"}">${z.tip === "TUKETICI" ? "Tüketici" : "Ticari"}</span>
    </div>
    <div class="kart-alt">
      <span>${esc(z.lokasyon_adi ? z.lokasyon_adi : [z.il, z.ilce].filter(Boolean).join(" / "))}</span>
      <span>${tarih}</span>
      ${S.role !== "rep" ? `<span>👤 ${esc(z.rep_full_name || z.rep_adi || "")}</span>` : ""}
      ${Number(z.foto_sayisi) ? `<span>📷 ${z.foto_sayisi}</span>` : ""}
      ${z.checkin_at ? `<span title="Check-in yapıldı">📍</span>` : ""}
      ${dl ? `<span class="rozet-cizgi" style="color:${dc};border-color:${dc}">${dl}</span>` : ""}
    </div>
    ${z.notlar ? `<div class="kart-not">${esc(z.notlar.slice(0, 140))}${z.notlar.length > 140 ? "…" : ""}</div>` : ""}
  </div>`;
}

async function ziyaretDetayModal(zid) {
  let z = (S.ziyaretler || []).find(x => x.id === zid);
  if (!z) {
    try { z = (await api(`/api/saha/ziyaretler/${zid}`)).ziyaret; } catch {}
  }
  z = z || {};
  const d = z.detay || {};
  const satir = (l, v) => v ? `<div class="det-satir"><span>${l}</span><b>${esc(String(v))}</b></div>` : "";
  const dizi = (l, a) => Array.isArray(a) && a.length ? satir(l, a.join(", ")) : "";
  modal(`
    <h3>${esc(z.firma || "")}</h3>
    ${satir("Tarih", z.ziyaret_tarihi ? new Date(z.ziyaret_tarihi).toLocaleDateString("tr-TR") : "")}
    ${satir("Temsilci", z.rep_full_name || z.rep_adi)}
    ${satir("Katılımcı", z.katilimci)}
    ${satir("Konum", [z.il, z.ilce].filter(Boolean).join(" / "))}
    ${z.checkin_at ? satir("Check-in", new Date(z.checkin_at).toLocaleString("tr-TR")) : ""}
    ${dizi("Raf markaları", d.raf_markalari)}${dizi("Bayilikler", d.bayilikler)}${dizi("Rakipler", d.rakipler)}
    ${satir("Kış stok", d.kis_stok)}${satir("Yaz stok", d.yaz_stok)}
    ${dizi("Sektörler", d.sektorler)}${dizi("Kullanılan markalar", d.kullanilan_markalar)}${dizi("Tedarikçi markalar", d.tedarikci_markalar)}${satir("Yıllık potansiyel", d.yillik_potansiyel)}
    ${d.arac_parki ? satir("Araç parkı", Object.entries(d.arac_parki).filter(([, n]) => n).map(([k, n]) => `${n} ${k}`).join(", ")) : ""}
    ${z.notlar ? `<div class="det-not">${esc(z.notlar)}</div>` : ""}
    ${z.duzenlendi_at ? `
      <details style="margin-top:4px">
        <summary style="font-size:11px;color:#b45309;cursor:pointer">✏️ ${new Date(z.duzenlendi_at).toLocaleString("tr-TR")} tarihinde düzenlendi — ilk hâlini gör</summary>
        <div style="font-size:12px;color:#64748b;background:#f8fafc;border-radius:8px;padding:8px;margin-top:4px;white-space:pre-wrap">${esc(z.notlar_orijinal || "—")}</div>
      </details>` : ""}
    <div id="det-fotolar" class="foto-izgara"></div>
    <div style="margin-top:14px;border-top:1px solid #f1f5f9;padding-top:12px">
      <div style="font-size:12px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.4px;margin-bottom:8px">Yorumlar</div>
      <div id="det-yorumlar" style="display:flex;flex-direction:column;gap:8px;margin-bottom:10px">
        <div style="font-size:12px;color:#94a3b8">Yükleniyor…</div>
      </div>
      <div style="display:flex;gap:8px;align-items:flex-end">
        <textarea id="det-yorum-input" class="giris" rows="2" placeholder="Yorum yaz…" style="flex:1;resize:none"></textarea>
        <button class="btn kucuk" id="det-yorum-gonder" style="flex-shrink:0">Gönder</button>
      </div>
    </div>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn cizgili" id="det-duzenle">✏️ Düzenle</button>
      <button class="btn cizgili" id="det-sil" style="color:#dc2626;border-color:#fecaca">🗑 Sil</button>
      <button class="btn" id="det-teklif">＋ Teklif</button>
    </div>`);

  document.getElementById("det-teklif")?.addEventListener("click", () => {
    kapatModal(); teklifFormModal({ id: z.musteri_id, firma: z.firma }, zid);
  });

  // ⚠ ZIYARET_SIL_V1 — UYARI TAHMIN DEGIL SAYIM.
  //   "Emin misiniz?" hicbir sey anlatmaz. "2 fotograf, 1 rakip fiyat" anlatir.
  const _silBtn = document.getElementById("det-sil");
  if (_silBtn) _silBtn.addEventListener("click", async () => {
    let o;
    try { o = await api(`/api/saha/ziyaretler/${zid}/silme-onizleme`); }
    catch (e) { uyari(e.message); return; }
    if (!o.silebilir) { uyari(o.neden || "Bu ziyareti silemezsiniz."); return; }
    const kayiplar = [];
    if (o.not_uzunluk > 0) kayiplar.push(`${o.not_uzunluk} karakterlik ziyaret notu`);
    if (o.foto > 0)        kayiplar.push(`${o.foto} fotoğraf`);
    if (o.teklif > 0)      kayiplar.push(`${o.teklif} rakip fiyat kaydı`);
    const liste = kayiplar.length
      ? kayiplar.map(k => "• " + k).join("\n")
      : "• (bu ziyarette not, fotoğraf veya rakip fiyat kaydı yok)";
    const ok = confirm(
      `${o.firma || "Ziyaret"} — ${o.tarih || ""}\n\n` +
      `Bu ziyaret KALICI OLARAK silinecek.\n\nSilinecekler:\n${liste}\n\n` +
      `⚠ Geri alınamaz.`);
    if (!ok) return;
    _silBtn.disabled = true; _silBtn.textContent = "Siliniyor…";
    try {
      await api(`/api/saha/ziyaretler/${zid}`, { method: "DELETE" });
      kapatModal();
      uyari("✓ Ziyaret silindi.", true);
      await loadView("ziyaretler");
    } catch (e) {
      _silBtn.disabled = false; _silBtn.textContent = "🗑 Sil";
      uyari(e.message);
    }
  });
  document.getElementById("det-duzenle")?.addEventListener("click", () => {
    kapatModal(); ziyaretDuzenleModal(z);
  });

  // Load photos
  if (Number(z.foto_sayisi)) {
    try {
      const { fotolar } = await api(`/api/saha/ziyaretler/${zid}/fotolar`);
      const g = document.getElementById("det-fotolar");
      for (const f of fotolar) {
        const url = await fotoUrl(f.id);
        if (url && g) g.insertAdjacentHTML("beforeend", `<img src="${url}" alt="">`);
      }
    } catch { /* foto yüklenemedi */ }
  }

  // Load + render comment thread
  const ROL_RENK = { admin: "#7c3aed", manager: "#0284c7", rep: "#374151" };
  const ROL_ETIKET = { admin: "GM", manager: "Müdür", rep: "Temsilci" };

  const yorumlarEl = document.getElementById("det-yorumlar");

  function renderYorumlar(yorumlar) {
    if (!yorumlar.length) {
      yorumlarEl.innerHTML = `<div style="font-size:12px;color:#94a3b8;font-style:italic">Henüz yorum yok.</div>`;
      return;
    }
    yorumlarEl.innerHTML = yorumlar.map(y => {
      const renk = ROL_RENK[y.rol] || "#374151";
      const etiket = ROL_ETIKET[y.rol] || y.rol;
      const ts = new Date(y.created_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
      const yonetici = y.rol !== "rep";
      return `
        <div style="display:flex;flex-direction:column;gap:2px;${yonetici ? "padding-left:0" : "padding-left:0"}">
          <div style="display:flex;align-items:center;gap:6px">
            <span style="background:${renk};color:#fff;border-radius:5px;padding:1px 6px;font-size:10px;font-weight:700">${etiket}</span>
            <span style="font-size:12px;font-weight:600;color:#334155">${esc(y.user_adi)}</span>
            <span style="font-size:11px;color:#94a3b8;margin-left:auto">${ts}</span>
          </div>
          <div style="background:${yonetici ? "#f0f9ff" : "#f8fafc"};border:1px solid ${yonetici ? "#bae6fd" : "#e2e8f0"};border-radius:8px;padding:8px 10px;font-size:13px;color:#0f172a;white-space:pre-wrap;border-top-left-radius:2px">${esc(y.icerik)}</div>
        </div>`;
    }).join("");
  }

  try {
    const { yorumlar } = await api(`/api/saha/ziyaretler/${zid}/yorumlar`);
    renderYorumlar(yorumlar);
  } catch { yorumlarEl.innerHTML = `<div style="font-size:12px;color:#94a3b8">Yorumlar yüklenemedi.</div>`; }

  // ⚠ SAHA_FIX_V1 — kok sebep (404) kapandi, ama ekran bir daha ASLA
  //   var olmayan bir butona olay baglayip patlamasin.
  const _detYorumBtn = document.getElementById("det-yorum-gonder");
  if (_detYorumBtn) _detYorumBtn.addEventListener("click", async () => {
    const inp = document.getElementById("det-yorum-input");
    const text = inp?.value.trim();
    if (!text) return;
    inp.value = "";
    inp.disabled = true;
    try {
      await api(`/api/saha/ziyaretler/${zid}/yorumlar`, { method: "POST", body: JSON.stringify({ icerik: text }) });
      const { yorumlar } = await api(`/api/saha/ziyaretler/${zid}/yorumlar`);
      renderYorumlar(yorumlar);
    } catch(e) { uyari(e.message); }
    finally { if (inp) inp.disabled = false; }
  });

  document.getElementById("det-yorum-input")?.addEventListener("keydown", ev => {
    if (ev.key === "Enter" && !ev.shiftKey) { ev.preventDefault(); document.getElementById("det-yorum-gonder").click(); }
  });
}

// ── MÜŞTERİ SEÇ (typeahead) ─────────────────────────────────────────────────
function musteriSecModal(devam) {
  modal(`
    <h3>Müşteri Seç</h3>
    <input class="giris" id="mus-ara" placeholder="En az 2 harf yazın… (firma adı)" autocomplete="off">
    <div id="mus-sonuc" class="ara-sonuc"></div>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Vazgeç</button></div>`);
  const inp = document.getElementById("mus-ara");
  const kutu = document.getElementById("mus-sonuc");
  inp.focus();
  let t = null;
  inp.addEventListener("input", () => {
    clearTimeout(t);
    const q = inp.value.trim();
    if (q.length < 2) { kutu.innerHTML = ""; return; }
    t = setTimeout(async () => {
      try {
        const { sonuclar } = await api(`/api/saha/musteri-ara?q=${encodeURIComponent(q)}`);
        kutu.innerHTML = sonuclar.map((r, i) => `
          <div class="ara-satir" data-i="${i}">
            <b>${esc(r.firma)}</b>
            <span class="rozet" style="background:${r.kaynak === "SAHA" ? "#10b981" : "#64748b"}">${r.kaynak === "SAHA" ? "Kayıtlı" : "ERP Cari"}</span>
            <small>${esc([r.il, r.ilce].filter(Boolean).join(" / ") || r.musteri_kodu || "")}</small>
          </div>`).join("") +
          `<div class="ara-satir yeni" data-yeni="1"><b>＋ "${esc(q)}" yeni müşteri olarak ekle</b></div>`;
        kutu.querySelectorAll(".ara-satir").forEach(el => el.addEventListener("click", async () => {
          if (el.dataset.yeni) { kapatModal(); yeniMusteriModal(q, devam); return; }
          const r = sonuclar[Number(el.dataset.i)];
          if (r.kaynak === "SAHA") { kapatModal(); devam(r); }
          else { kapatModal(); yeniMusteriModal(r.firma, devam, r.musteri_kodu); }
        }));
      } catch (e) { kutu.innerHTML = hata(e); }
    }, 300);
  });
}

function yeniMusteriModal(firma, devam, musteriKodu = null) {
  modal(`
    <h3>${musteriKodu ? "ERP Cariyi Sahaya Ekle" : "Yeni Müşteri / Nokta"}</h3>
    ${musteriKodu ? `<div class="bilgi-kutu">ERP kodu <b>${esc(musteriKodu)}</b> bağlanacak — bakiye ve satış geçmişi otomatik görünür.</div>` : ""}
    <label>Firma *<input class="giris" id="ym-firma" value="${esc(firma)}"></label>
    <label>Tip *
      <select class="giris" id="ym-tip">
        <option value="">Seçin…</option>
        <option value="TUKETICI" ${S.semsiye === "TUKETICI" ? "selected" : ""}>Tüketici (PSR bayi)</option>
        <option value="TICARI" ${S.semsiye === "TICARI" ? "selected" : ""}>Ticari (TBR/OTR)</option>
      </select></label>
    <div class="yanyana">
      <label>İl *<input class="giris" id="ym-il" list="ym-il-list" placeholder="Şehir seçin">
        <datalist id="ym-il-list">${TR_ILLER.map(il => `<option>${esc(il)}</option>`).join("")}</datalist>
      </label>
      <label>İlçe<input class="giris" id="ym-ilce"></label>
    </div>
    <label>Kayıt Kaynağı *
      <select class="giris" id="ym-kaynak">
        <option value="SAHA_ZIYARETI">📍 Saha Ziyareti</option>
        <option value="TELEFON">📞 Telefon</option>
        <option value="REFERANS">🤝 Referans</option>
        <option value="DIGER">Diğer</option>
      </select></label>
    <div class="yanyana">
      <label>Yetkili Kişi *<input class="giris" id="ym-yetkili" placeholder="Ad Soyad / Ünvan"></label>
      <label>Telefon *<input class="giris" id="ym-tel" inputmode="tel" placeholder="+90 5xx xxx xx xx"></label>
    </div>
    <div class="yanyana">
      <label>VKN <span style="font-size:11px;background:#fff7ed;color:#c2410c;border:1px solid #fed7aa;border-radius:4px;padding:1px 5px">yakında zorunlu</span>
        <input class="giris" id="ym-vkn" inputmode="numeric" placeholder="10 hane (Vergi No)">
      </label>
      <label>TC Kimlik No<input class="giris" id="ym-tcno" inputmode="numeric" placeholder="11 hane"></label>
    </div>
    <label>Segment<input class="giris" id="ym-segment" placeholder="bayi / lojistik / maden…"></label>
    <div id="ym-konum-kutu">
      <div id="ym-konum-zorunlu" style="font-size:12px;color:#dc2626;font-weight:600;margin-bottom:4px;display:none">⚠ Saha ziyareti için GPS konumu zorunludur.</div>
      <button class="btn cizgili" id="ym-konum-btn" style="width:100%;margin-bottom:4px">📍 GPS ile Konumu Pinle</button>
      <div id="ym-konum-durum" class="mini-durum"></div>
    </div>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="ym-kaydet">Kaydet ve Devam</button>
    </div>`);

  const konumData = { lat: null, lng: null };

  // Show/hide & mandate GPS based on source
  const kaynakEl  = document.getElementById("ym-kaynak");
  const konumKutu = document.getElementById("ym-konum-kutu");
  const uyariEl   = document.getElementById("ym-konum-zorunlu");
  function toggleKonum() {
    const saha = kaynakEl.value === "SAHA_ZIYARETI";
    konumKutu.style.display = saha ? "block" : "none";
  }
  toggleKonum();
  kaynakEl.addEventListener("change", toggleKonum);

  document.getElementById("ym-konum-btn").addEventListener("click", () => {
    const st = document.getElementById("ym-konum-durum");
    st.textContent = "Konum alınıyor…";
    uyariEl.style.display = "none";
    navigator.geolocation.getCurrentPosition(
      p => {
        konumData.lat = p.coords.latitude;
        konumData.lng = p.coords.longitude;
        st.textContent = `✓ Konum alındı (±${Math.round(p.coords.accuracy)}m)`;
      },
      () => { st.textContent = "⚠ Konum alınamadı — izinleri kontrol edin."; },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  });

  document.getElementById("ym-kaydet").addEventListener("click", async () => {
    const g = id => document.getElementById(id).value.trim();
    if (!g("ym-firma"))   { uyari("Firma zorunlu."); return; }
    if (!g("ym-tip"))     { uyari("Tip zorunlu."); return; }
    if (!g("ym-il"))      { uyari("İl zorunlu."); return; }
    if (!g("ym-yetkili")) { uyari("Yetkili kişi adı zorunlu."); return; }
    if (!g("ym-tel"))     { uyari("Telefon zorunlu."); return; }
    if (g("ym-kaynak") === "SAHA_ZIYARETI" && konumData.lat == null) {
      uyariEl.style.display = "block";
      uyari("Saha ziyareti için GPS konumu zorunludur. Lütfen 'GPS ile Konumu Pinle' butonuna basın.");
      return;
    }
    try {
      const { musteri } = await api("/api/saha/musteriler", {
        method: "POST",
        body: JSON.stringify({
          firma: g("ym-firma"), tip: g("ym-tip"),
          il: g("ym-il"), ilce: g("ym-ilce") || null,
          yetkili: g("ym-yetkili"), telefon: g("ym-tel"),
          segment: g("ym-segment") || null,
          vergi_no: g("ym-vkn") || null, tc_no: g("ym-tcno") || null,
          musteri_kodu: musteriKodu,
          kayit_kaynagi: g("ym-kaynak") || "SAHA_ZIYARETI",
          lat: konumData.lat, lng: konumData.lng
        })
      });
      kapatModal(); devam(musteri);
    } catch (e) { uyari(e.message); }
  });
}

// ── ZİYARET FORMU (kaydet = tamamlandı | planla = ileri tarih) ──────────────
// ── Ziyaret düzenle (kendi ziyaretin) — not/katılımcı/tarih ─────────────────
async function ziyaretDuzenleModal(z) {
  modal(`
    <h3>✏️ Ziyaret Düzenle — ${esc(z.firma || "")}</h3>
    <div style="font-size:11px;color:#64748b;margin-bottom:10px">Düzeltmeler kayıt altına alınır; notun ilk hâli saklanır.</div>
    <div class="yanyana">
      <label>Ziyaret tarihi
        <input class="giris" id="zd-tarih" type="date" value="${z.ziyaret_tarihi ? String(z.ziyaret_tarihi).slice(0, 10) : ""}">
      </label>
      <label>Katılımcı
        <input class="giris" id="zd-katilimci" value="${esc(z.katilimci || "")}" placeholder="Görüşülen kişi">
      </label>
    </div>
    <label>Notlar
      <textarea class="giris" id="zd-notlar" rows="6" placeholder="Ziyaret notu…">${esc(z.notlar || "")}</textarea>
    </label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="zd-kaydet">Kaydet</button>
    </div>`);

  document.getElementById("zd-kaydet").addEventListener("click", async () => {
    const notlar = document.getElementById("zd-notlar").value.trim();
    const katilimci = document.getElementById("zd-katilimci").value.trim();
    const tarih = document.getElementById("zd-tarih").value || null;
    if (!notlar) { uyari("Not boş olamaz."); return; }
    const btn = document.getElementById("zd-kaydet");
    btn.disabled = true; btn.textContent = "Kaydediliyor…";
    try {
      await api(`/api/saha/ziyaretler/${z.id}`, {
        method: "PUT",
        body: JSON.stringify({ action: "guncelle", notlar, katilimci: katilimci || null, ziyaret_tarihi: tarih })
      });
      kapatModal();
      uyari("✓ Ziyaret güncellendi.", true);
      await loadView("ziyaretler");
    } catch (e) {
      btn.disabled = false; btn.textContent = "Kaydet";
      uyari(e.message);
    }
  });
}

async function ziyaretFormModal(mus, mod, presetDate = null) {
  const tip = mus.tip || S.semsiye || "TUKETICI";
  const bugun = new Date().toISOString().slice(0, 10);
  const tarihDeger = presetDate || bugun;
  const tuketici = tip === "TUKETICI";
  let lokasyonlar = [];
  try { lokasyonlar = (await api(`/api/saha/musteriler/${mus.id}/lokasyonlar`)).lokasyonlar || []; } catch { /* yok */ }
  modal(`
    <h3>${mod === "planla" ? "Ziyaret Planla" : "Ziyaret Kaydet"} — ${esc(mus.firma)}</h3>
    ${lokasyonlar.length ? `
    <label>Lokasyon
      <select class="giris" id="zf-lokasyon">
        <option value="">Merkez / belirtilmedi</option>
        ${lokasyonlar.map(l => `<option value="${l.id}">${esc(l.ad)}${l.il ? " — " + esc([l.il, l.ilce].filter(Boolean).join("/")) : ""}</option>`).join("")}
      </select></label>` : ""}
    <label>Tarih<input type="date" class="giris" id="zf-tarih" value="${tarihDeger}"></label>
    <label>Görüşülen kişi / ünvan<input class="giris" id="zf-katilimci" placeholder="Ahmet Bey — Satınalma"></label>
    ${tuketici ? `
      <div class="alan-grup"><span class="alan-baslik">Raftaki markalar</span>${cipSecici("zf-raf", MARKALAR)}</div>
      <div class="alan-grup"><span class="alan-baslik">Bayilikler</span>${cipSecici("zf-bayilik", BAYILIKLER)}</div>
      <div class="alan-grup"><span class="alan-baslik">Görülen rakip toptancılar</span>${cipSecici("zf-rakip", RAKIPLER)}</div>
      <div class="yanyana">
        <label>Kış stok (adet)<input type="number" class="giris" id="zf-kis" min="0"></label>
        <label>Yaz stok (adet)<input type="number" class="giris" id="zf-yaz" min="0"></label>
      </div>
      <label>Nokta durumu
        <select class="giris" id="zf-durum">
          <option value="">Değişmedi</option>
          ${Object.entries(DURUM_ETIKET).map(([k, [l]]) => `<option value="${k}">${l}</option>`).join("")}
        </select></label>
    ` : `
      <div class="alan-grup"><span class="alan-baslik">Sektörler</span>${cipSecici("zf-sektorler", SEKTORLER)}</div>
      <div class="alan-grup"><span class="alan-baslik">Araç parkı</span>
        <div class="yanyana4">
          <label>Çekici<input type="number" class="giris" id="zf-cekici" min="0"></label>
          <label>Dorse<input type="number" class="giris" id="zf-dorse" min="0"></label>
          <label>Kamyon<input type="number" class="giris" id="zf-kamyon" min="0"></label>
          <label>İş mak.<input type="number" class="giris" id="zf-ismak" min="0"></label>
        </div></div>
      <div class="alan-grup"><span class="alan-baslik">Kullanılan markalar</span>${cipSecici("zf-marka", MARKALAR)}</div>
      <div class="alan-grup"><span class="alan-baslik">Mevcut tedarikçi</span>${cipSecici("zf-tedarikci", RAKIPLER)}</div>
      <label>Yıllık potansiyel (adet)<input type="number" class="giris" id="zf-potansiyel" min="0"></label>`}
    <label>Notlar<textarea class="giris" id="zf-not" rows="3" placeholder="Ziyaret notları…"></textarea></label>
    ${mod !== "planla" ? `
      <div class="yanyana">
        <button class="btn cizgili" id="zf-konum">📍 Check-in</button>
        <label class="btn cizgili dosya-btn">📷 Foto Ekle<input type="file" id="zf-foto" accept="image/*" capture="environment" multiple hidden></label>
      </div>
      <div id="zf-konum-durum" class="mini-durum"></div>
      <label id="zf-pin-label" style="display:none;font-size:13px;color:#0284c7;align-items:center;gap:6px;margin:2px 0 6px;cursor:pointer">
        <input type="checkbox" id="zf-pin-musteri" checked style="width:16px;height:16px;cursor:pointer;flex-shrink:0">
        Bu konumu müşteri adresine kaydet
      </label>
      <div id="zf-foto-liste" class="foto-izgara"></div>` : ""}
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      ${mod !== "planla" ? `<button class="btn cizgili" id="zf-planla">🗓️ Planla</button>` : ""}
      <button class="btn" id="zf-kaydet">${mod === "planla" ? "Planla" : "✓ Kaydet"}</button>
    </div>`);

  // ⚠ PROFIL_V1 — form artik musteriyi HATIRLIYOR.
  //   Eski hali: sadece sektorler ve tedarikci_markalar seciliydi; digerleri
  //   her ziyarette SIFIRDAN giriliyordu ve hicbir yere birikmiyordu.
  //   Olcum: 2.420 ziyaretin 16'sinda arac parki vardi. Cunku kimse iki kez girmez.
  const _cip = (kap, deger) => {
    const arr = Array.isArray(deger) ? deger : [];
    document.querySelectorAll(`#${kap} .cip`).forEach(b => {
      if (arr.includes(b.dataset.v)) b.classList.add('on');
    });
  };
  const _say = (id, deger) => {
    const el = document.getElementById(id);
    if (el && deger != null && deger !== "") el.value = deger;
  };
  if (!tuketici) {
    _cip('zf-sektorler', mus.sektorler);
    _cip('zf-tedarikci', mus.tedarikci_markalar);
    _cip('zf-marka',     mus.kullanilan_markalar);
    const ap = mus.arac_parki || {};
    _say('zf-cekici', ap.cekici); _say('zf-dorse', ap.dorse);
    _say('zf-kamyon', ap.kamyon); _say('zf-ismak',  ap.is_makinesi);
    _say('zf-potansiyel', mus.yillik_potansiyel);
  } else {
    _cip('zf-raf',     mus.raf_markalar);
    _cip('zf-bayilik', mus.bayilikler);
    _cip('zf-rakip',   mus.rakip_toptancilar);
    _say('zf-kis', mus.kis_stok);
    _say('zf-yaz', mus.yaz_stok);
  }
  // ⚠ BU BILGI NE ZAMANKI? Tarihi gorunmeyen bir bilgi BUGUNUN bilgisi sanilir.
  if (mus.profil_guncel_at) {
    const _t = new Date(mus.profil_guncel_at);
    const _g = Math.floor((Date.now() - _t.getTime()) / 86400000);
    const _ilk = document.querySelector('.alan-grup');
    if (_ilk) {
      const _uy = document.createElement('div');
      _uy.style.cssText = 'font-size:12px;color:' + (_g > 180 ? '#b45309' : '#64748b') + ';margin:0 0 8px';
      _uy.textContent = (_g > 180 ? '⚠ ' : '') + 'Aşağıdaki bilgiler ' +
        _t.toLocaleDateString('tr-TR') + ' tarihli ziyaretten geliyor' +
        (_g > 180 ? ' — ' + Math.round(_g/30) + ' ay önce. Değişmiş olabilir.' : '.');
      _ilk.parentNode.insertBefore(_uy, _ilk);
    }
  }

  const konum = { lat: null, lng: null };
  const fotolar = [];
  document.getElementById("zf-konum")?.addEventListener("click", () => {
    const st = document.getElementById("zf-konum-durum");
    st.textContent = "Konum alınıyor…";
    navigator.geolocation.getCurrentPosition(
      p => { konum.lat = p.coords.latitude; konum.lng = p.coords.longitude; st.textContent = `✓ Konum alındı (±${Math.round(p.coords.accuracy)}m)`; const pinLabel = document.getElementById("zf-pin-label"); if (pinLabel) pinLabel.style.display = "flex"; },
      () => { st.textContent = "⚠ Konum alınamadı — izinleri kontrol edin."; },
      { enableHighAccuracy: true, timeout: 10000 });
  });
  document.getElementById("zf-foto")?.addEventListener("change", async ev => {
    for (const file of ev.target.files) {
      const kucuk = await kucult(file);
      fotolar.push(kucuk);
      document.getElementById("zf-foto-liste").insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ev.target.value = "";
  });

  const kaydet = async (planla) => {
    const g = id => document.getElementById(id)?.value.trim() || "";
    const n = id => { const v = g(id); return v ? Number(v) : null; };
    // Capture array values before DOM changes
    const sektorSecim = tuketici ? [] : cipDegerler("zf-sektorler");
    const tedarikSecim = tuketici ? [] : cipDegerler("zf-tedarikci");
    const detay = tuketici ? {
      raf_markalari: cipDegerler("zf-raf"), bayilikler: cipDegerler("zf-bayilik"),
      rakipler: cipDegerler("zf-rakip"), kis_stok: n("zf-kis"), yaz_stok: n("zf-yaz")
    } : {
      sektorler: sektorSecim,
      arac_parki: { cekici: n("zf-cekici"), dorse: n("zf-dorse"), kamyon: n("zf-kamyon"), is_makinesi: n("zf-ismak") },
      kullanilan_markalar: cipDegerler("zf-marka"),
      tedarikci_markalar: tedarikSecim, yillik_potansiyel: n("zf-potansiyel")
    };
    try {
      const { ziyaret } = await api("/api/saha/ziyaretler", {
        method: "POST",
        body: JSON.stringify({
          musteri_id: mus.id, tip,
          lokasyon_id: document.getElementById("zf-lokasyon")?.value || null,
          tamamla: !planla,
          ziyaret_tarihi: planla ? null : g("zf-tarih"),
          planlanan_tarih: planla ? g("zf-tarih") : null,
          katilimci: g("zf-katilimci") || null, notlar: g("zf-not") || null, detay
        })
      });
      if (!planla && konum.lat != null) {
        const pinMusteri = document.getElementById("zf-pin-musteri")?.checked !== false;
        await api(`/api/saha/ziyaretler/${ziyaret.id}`, {
          method: "PUT", body: JSON.stringify({ action: "checkin", lat: konum.lat, lng: konum.lng, pin_musteri: pinMusteri })
        }).catch(() => {});
      }
      for (const f of fotolar) {
        await api(`/api/saha/ziyaretler/${ziyaret.id}/foto`, {
          method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" })
        }).catch(() => {});
      }
      // ⚠ UC_ARIZA_V1 — 'durum' ARTIK GONDERILMIYOR.
      //   durum ERP satis gecmisinden HESAPLANIYOR (saha_musteri_durum_yenile).
      //   Sunucu PUT'ta kabul etmiyor; arayuz yine de gonderdigi icin
      //   Eftal bugun 11:28 ve 11:54'te "Guncellenecek alan yok" (400) aldi.
      //   Sessiz 403'u duzeltirken gorunur 400 uretmisim. Kaynak: BU ISTEK.
      // ⚠ PROFIL_V1 — TUM profil musteriye yaziliyor, sadece iki alan degil.
      //   Boylece bir sonraki ziyarette form BOMBOS acilmiyor.
      //   ⚠ Hata artik YUTULMUYOR: .catch(()=>{}) sessiz kayip uretiyordu.
      try {
        const _profil = !tuketici
          ? { sektorler: sektorSecim, tedarikci_markalar: tedarikSecim,
              kullanilan_markalar: cipDegerler("zf-marka"),
              arac_parki: { cekici: n("zf-cekici"), dorse: n("zf-dorse"),
                            kamyon: n("zf-kamyon"), is_makinesi: n("zf-ismak") },
              yillik_potansiyel: n("zf-potansiyel") }
          : { raf_markalar: cipDegerler("zf-raf"),
              bayilikler: cipDegerler("zf-bayilik"),
              rakip_toptancilar: cipDegerler("zf-rakip"),
              kis_stok: n("zf-kis"), yaz_stok: n("zf-yaz") };
        await api(`/api/saha/musteriler/${mus.id}`, {
          method: "PUT", body: JSON.stringify(_profil)
        });
      } catch (e) {
        // ⚠ SUSMAZ. Profil yazilamadiysa temsilci BILSIN.
        console.error("[saha] musteri profili yazilamadi:", e && e.message);
        uyari("⚠ Ziyaret kaydedildi ama müşteri profili güncellenemedi: " + (e.message || ""));
      }
      kapatModal();
      if (!planla) {
        await loadView("ziyaretler");
        ziyaretDetayModal(ziyaret.id);
      } else {
        loadView("plan");
      }
    } catch (e) { uyari(e.message); }
  };
  document.getElementById("zf-kaydet").addEventListener("click", () => kaydet(mod === "planla"));
  document.getElementById("zf-planla")?.addEventListener("click", () => kaydet(true));
}

// ── PLAN ─────────────────────────────────────────────────────────────────────

async function vPlan() {
  try {
    const { ziyaretler } = await api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`);
    const bugun = new Date().toISOString().slice(0, 10);
    let takvimAy = new Date();
    let seciliGun = bugun;

    function renderTakvim() {
      const gunZiyaret = {};
      ziyaretler.forEach(z => {
        if (z.planlanan_tarih) {
          const d = z.planlanan_tarih.slice(0, 10);
          gunZiyaret[d] = (gunZiyaret[d] || 0) + 1;
        }
      });
      const yil = takvimAy.getFullYear();
      const ay  = takvimAy.getMonth();
      const ayAdi = takvimAy.toLocaleDateString("tr-TR", { month: "long", year: "numeric" });
      const ilkGunPazartesi = ((new Date(yil, ay, 1).getDay() + 6) % 7);
      const sonGun = new Date(yil, ay + 1, 0).getDate();
      const satirSayisi = Math.ceil((ilkGunPazartesi + sonGun) / 7);

      let hucreler = "";
      let gun = 1;
      for (let s = 0; s < satirSayisi; s++) {
        hucreler += `<div class="tak-hafta">`;
        for (let g = 0; g < 7; g++) {
          const pos = s * 7 + g;
          if (pos < ilkGunPazartesi || gun > sonGun) {
            hucreler += `<div class="tak-gun bos"></div>`;
          } else {
            const tarih = `${yil}-${String(ay + 1).padStart(2,"0")}-${String(gun).padStart(2,"0")}`;
            const bugunmu  = tarih === bugun;
            const secilimi = tarih === seciliGun;
            const gecmismi = tarih < bugun;
            const sayi = gunZiyaret[tarih] || 0;
            hucreler += `<div class="tak-gun${bugunmu ? " bugun" : ""}${secilimi ? " secili" : ""}${gecmismi ? " gecmis-gun" : ""}" data-tarih="${tarih}">
              <span class="tak-sayi">${gun}</span>
              ${sayi ? `<span class="tak-rozet">${sayi}</span>` : ""}
            </div>`;
            gun++;
          }
        }
        hucreler += `</div>`;
      }

      const gunZiyaretleri = ziyaretler.filter(z => z.planlanan_tarih?.slice(0, 10) === seciliGun);
      const seciliTarihStr = new Date(seciliGun + "T12:00:00").toLocaleDateString("tr-TR", { weekday:"long", day:"numeric", month:"long" });

      return `
        <div class="takvim-kont">
          <div class="tak-baslik">
            <button class="btn kucuk gri" id="tak-prev">◀</button>
            <span class="tak-ay-adi">${ayAdi}</span>
            <button class="btn kucuk gri" id="tak-next">▶</button>
          </div>
          <div class="tak-gunler-baslik">
            ${["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"].map(h => `<div class="tak-hb">${h}</div>`).join("")}
          </div>
          <div class="tak-izgara">${hucreler}</div>
        </div>
        <div class="tak-gun-panel">
          <div class="tak-gun-baslik">
            <b>${seciliTarihStr}</b>
            <button class="btn kucuk" id="tak-yeni">＋ Ekle</button>
          </div>
          ${gunZiyaretleri.length ? gunZiyaretleri.map(z => `
            <div class="kart${z.planlanan_tarih?.slice(0,10) < bugun ? " gecmis" : ""}">
              <div class="kart-ust"><b>${esc(z.firma)}</b>
                ${S.role !== "rep" ? `<span>👤 ${esc(z.rep_full_name || "")}</span>` : ""}</div>
              <div class="kart-alt"><span>${esc([z.il, z.ilce].filter(Boolean).join(" / "))}</span></div>
              <div class="kart-btnlar">
                <button class="btn kucuk" data-basla="${z.id}">▶ Başlat</button>
                <button class="btn kucuk gri" data-iptal="${z.id}">İptal</button>
              </div>
            </div>`).join("")
          : `<div class="saha-bos" style="padding:12px 0">Bu gün için ziyaret planı yok.</div>`}
        </div>`;
    }

    function wire() {
      const m = main();
      m.innerHTML = renderTakvim();

      m.querySelectorAll(".tak-gun[data-tarih]").forEach(el => {
        el.addEventListener("click", () => {
          seciliGun = el.dataset.tarih;
          wire();
        });
      });
      m.querySelector("#tak-prev").addEventListener("click", () => {
        takvimAy = new Date(takvimAy.getFullYear(), takvimAy.getMonth() - 1, 1);
        wire();
      });
      m.querySelector("#tak-next").addEventListener("click", () => {
        takvimAy = new Date(takvimAy.getFullYear(), takvimAy.getMonth() + 1, 1);
        wire();
      });
      m.querySelector("#tak-yeni").addEventListener("click", () => {
        musteriSecModal(mus => ziyaretFormModal(mus, "planla", seciliGun));
      });
      m.querySelectorAll("[data-basla]").forEach(b => b.addEventListener("click", () => {
        planTamamlaModal(ziyaretler.find(x => x.id === b.dataset.basla));
      }));
      m.querySelectorAll("[data-iptal]").forEach(b => b.addEventListener("click", async () => {
        if (!confirm("Ziyaret planı iptal edilsin mi?")) return;
        try {
          await api(`/api/saha/ziyaretler/${b.dataset.iptal}`, { method: "PUT", body: JSON.stringify({ action: "iptal" }) });
          const i = ziyaretler.findIndex(x => x.id === b.dataset.iptal);
          if (i !== -1) ziyaretler.splice(i, 1);
          wire();
        } catch (e) { uyari(e.message); }
      }));
    }

    wire();
  } catch (e) { main().innerHTML = hata(e); }
}

async function planTamamlaModal(z) {
  const tuketici = z.tip === "TUKETICI";

  // Fetch customer from cache or API for chip pre-population
  let musteri = (S.musteriler || []).find(m => m.id === z.musteri_id) || null;
  if (!musteri && z.musteri_id) {
    try {
      const { musteriler } = await api(`/api/saha/musteriler?q=${encodeURIComponent(z.firma || "")}`);
      musteri = musteriler.find(m => m.id === z.musteri_id) || null;
    } catch {}
  }
  let lokasyonlar = [];
  try { lokasyonlar = (await api(`/api/saha/musteriler/${z.musteri_id}/lokasyonlar`)).lokasyonlar || []; } catch {}

  modal(`
    <h3>Ziyareti Tamamla — ${esc(z.firma)}</h3>
    ${lokasyonlar.length ? `
    <label>Lokasyon
      <select class="giris" id="pt-lokasyon">
        <option value="">Merkez / belirtilmedi</option>
        ${lokasyonlar.map(l => `<option value="${l.id}">${esc(l.ad)}${l.il ? " — " + esc([l.il, l.ilce].filter(Boolean).join("/")) : ""}</option>`).join("")}
      </select></label>` : ""}
    <label>Görüşülen kişi<input class="giris" id="pt-katilimci" value="${esc(z.katilimci || "")}"></label>
    ${tuketici ? `
      <div class="alan-grup"><span class="alan-baslik">Raftaki markalar</span>${cipSecici("pt-raf", MARKALAR)}</div>
      <div class="alan-grup"><span class="alan-baslik">Bayilikler</span>${cipSecici("pt-bayilik", BAYILIKLER)}</div>
      <div class="alan-grup"><span class="alan-baslik">Rakip toptancılar</span>${cipSecici("pt-rakip", RAKIPLER)}</div>
      <div class="yanyana">
        <label>Kış stok (adet)<input type="number" class="giris" id="pt-kis" min="0"></label>
        <label>Yaz stok (adet)<input type="number" class="giris" id="pt-yaz" min="0"></label>
      </div>
      <label>Nokta durumu
        <select class="giris" id="pt-durum">
          <option value="">Değişmedi</option>
          ${Object.entries(DURUM_ETIKET).map(([k, [l]]) => `<option value="${k}">${l}</option>`).join("")}
        </select></label>
    ` : `
      <div class="alan-grup"><span class="alan-baslik">Sektörler</span>${cipSecici("pt-sektorler", SEKTORLER)}</div>
      <div class="alan-grup"><span class="alan-baslik">Araç parkı</span>
        <div class="yanyana4">
          <label>Çekici<input type="number" class="giris" id="pt-cekici" min="0"></label>
          <label>Dorse<input type="number" class="giris" id="pt-dorse" min="0"></label>
          <label>Kamyon<input type="number" class="giris" id="pt-kamyon" min="0"></label>
          <label>İş mak.<input type="number" class="giris" id="pt-ismak" min="0"></label>
        </div></div>
      <div class="alan-grup"><span class="alan-baslik">Kullanılan markalar</span>${cipSecici("pt-marka", MARKALAR)}</div>
      <div class="alan-grup"><span class="alan-baslik">Mevcut tedarikçi</span>${cipSecici("pt-tedarikci", RAKIPLER)}</div>
      <label>Yıllık potansiyel (adet)<input type="number" class="giris" id="pt-potansiyel" min="0"></label>`}
    <label>Notlar<textarea class="giris" id="pt-not" rows="3">${esc(z.notlar || "")}</textarea></label>
    <div class="yanyana">
      <button class="btn cizgili" id="pt-konum">📍 Check-in</button>
      <label class="btn cizgili dosya-btn">📷 Foto<input type="file" id="pt-foto" accept="image/*" capture="environment" multiple hidden></label>
    </div>
    <div id="pt-konum-durum" class="mini-durum"></div>
    <div id="pt-foto-liste" class="foto-izgara"></div>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="pt-tamamla">✓ Tamamla</button>
    </div>`);

  // Pre-select chips from customer profile (ticari only)
  if (!tuketici && musteri) {
    const mSek = Array.isArray(musteri.sektorler) ? musteri.sektorler : [];
    const mTed = Array.isArray(musteri.tedarikci_markalar) ? musteri.tedarikci_markalar : [];
    document.querySelectorAll('#pt-sektorler .cip').forEach(b => { if (mSek.includes(b.dataset.v)) b.classList.add('on'); });
    document.querySelectorAll('#pt-tedarikci .cip').forEach(b => { if (mTed.includes(b.dataset.v)) b.classList.add('on'); });
  }

  const konum = { lat: null, lng: null };
  const fotolar = [];
  document.getElementById("pt-konum").addEventListener("click", () => {
    const st = document.getElementById("pt-konum-durum");
    st.textContent = "Konum alınıyor…";
    navigator.geolocation.getCurrentPosition(
      p => { konum.lat = p.coords.latitude; konum.lng = p.coords.longitude; st.textContent = `✓ Konum alındı`; },
      () => { st.textContent = "⚠ Konum alınamadı."; }, { enableHighAccuracy: true, timeout: 10000 });
  });
  document.getElementById("pt-foto").addEventListener("change", async ev => {
    for (const file of ev.target.files) {
      const kucuk = await kucult(file);
      fotolar.push(kucuk);
      document.getElementById("pt-foto-liste").insertAdjacentHTML("beforeend", `<img src="${kucuk}" alt="">`);
    }
    ev.target.value = "";
  });
  document.getElementById("pt-tamamla").addEventListener("click", async () => {
    const g = id => document.getElementById(id)?.value.trim() || "";
    const n = id => { const v = g(id); return v ? Number(v) : null; };
    const sektorSecim = tuketici ? [] : cipDegerler("pt-sektorler");
    const tedarikSecim = tuketici ? [] : cipDegerler("pt-tedarikci");
    const detay = tuketici
      ? { raf_markalari: cipDegerler("pt-raf"), bayilikler: cipDegerler("pt-bayilik"),
          rakipler: cipDegerler("pt-rakip"), kis_stok: n("pt-kis"), yaz_stok: n("pt-yaz") }
      : { sektorler: sektorSecim,
          arac_parki: { cekici: n("pt-cekici"), dorse: n("pt-dorse"), kamyon: n("pt-kamyon"), is_makinesi: n("pt-ismak") },
          kullanilan_markalar: cipDegerler("pt-marka"),
          tedarikci_markalar: tedarikSecim,
          yillik_potansiyel: n("pt-potansiyel") };
    try {
      if (konum.lat != null) {
        await api(`/api/saha/ziyaretler/${z.id}`, { method: "PUT", body: JSON.stringify({ action: "checkin", lat: konum.lat, lng: konum.lng }) }).catch(() => {});
      }
      const lokSecim = document.getElementById("pt-lokasyon")?.value || null;
      await api(`/api/saha/ziyaretler/${z.id}`, {
        method: "PUT",
        body: JSON.stringify({ action: "tamamla", katilimci: g("pt-katilimci") || null, notlar: g("pt-not") || null, detay, lokasyon_id: lokSecim })
      });
      for (const f of fotolar) {
        await api(`/api/saha/ziyaretler/${z.id}/foto`, { method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" }) }).catch(() => {});
      }
      // ⚠ UC_ARIZA_V1 — 'durum' ARTIK GONDERILMIYOR (ERP'den hesaplaniyor).
      // Update customer profile with sektorler + tedarikci_markalar (ticari)
      if (!tuketici && z.musteri_id) {
        await api(`/api/saha/musteriler/${z.musteri_id}`, { method: "PUT", body: JSON.stringify({ sektorler: sektorSecim, tedarikci_markalar: tedarikSecim }) }).catch(() => {});
      }
      kapatModal();
      await loadView("ziyaretler");   // populates S.ziyaretler
      ziyaretDetayModal(z.id);        // auto-open detail → "＋ Teklif" one tap away
    } catch (e) { uyari(e.message); }
  });
}

// ── MÜŞTERİLER ───────────────────────────────────────────────────────────────
async function vMusteriler() {
  const PAGE_SIZE = 50;
  let currentQ = "";
  let currentOffset = 0;

  function kartHtml(m) {
    const [dl, dc] = DURUM_ETIKET[m.durum] || ["", "#999"];
    return `
      <div class="kart" data-mid="${m.id}">
        <div class="kart-ust"><b>${esc(m.firma)}</b>
          <div style="display:flex;gap:4px;align-items:center">
            ${Number(m.aktif_teklif) > 0
              ? `<span class="rozet" style="background:#0ea5e9;font-size:10px;padding:2px 6px" title="Aktif teklif var">📋 ${m.aktif_teklif}</span>`
              : ""}
            ${S.role !== "rep" && !m.musteri_kodu && m.erp_eslestirme_tipi === 'BEKLIYOR'
              ? `<span class="rozet" style="background:#f59e0b;font-size:10px;padding:2px 5px" title="ERP'de benzer kayıt var, onay bekleniyor">ERP?</span>`
              : S.role !== "rep" && !m.musteri_kodu && m.erp_eslestirme_tipi === 'YENI_NOKTA'
              ? `<span class="rozet" style="background:#6366f1;font-size:10px;padding:2px 5px" title="ERP'de kayıt yok, yeni müşteri">Yeni</span>`
              : ""}
          </div>
        </div>
        <div class="kart-alt">
          ${dl ? `<span class="rozet-cizgi" style="color:${dc};border-color:${dc};font-size:10px;padding:1px 5px">${dl}</span>` : ""}
          <span>${esc([m.il, m.ilce].filter(Boolean).join(" / "))}</span>
          ${m.musteri_kodu ? `<span class="erp-kod">${esc(m.musteri_kodu)}</span>` : ""}
          <span>${m.ziyaret_sayisi || 0} ziyaret</span>
          ${m.son_ziyaret ? `<span>Son: ${new Date(m.son_ziyaret).toLocaleDateString("tr-TR")}</span>` : ""}
        </div>
      </div>`;
  }

  function wireKartlar(liste) {
    liste.querySelectorAll("[data-mid]:not([data-wired])").forEach(el => {
      el.dataset.wired = "1";
      el.addEventListener("click", () => {
        const m = S.musteriler.find(x => x.id === el.dataset.mid);
        if (!m) return;
        if (S.birlestirSecim) {
          if (S.birlestirSecim.has(m.id)) { S.birlestirSecim.delete(m.id); el.classList.remove("secili"); }
          else { S.birlestirSecim.add(m.id); el.classList.add("secili"); }
          const s = document.getElementById("birlestir-sayi");
          if (s) s.textContent = `${S.birlestirSecim.size} kart seçili`;
          return;
        }
        musteriDetayModal(m);
      });
    });
  }

  const yukle = async (q = "", offset = 0, append = false) => {
    currentQ = q; currentOffset = offset;
    const qs = `/api/saha/musteriler?q=${encodeURIComponent(q)}${tipQS()}&limit=${PAGE_SIZE}&offset=${offset}`;
    const { musteriler, hasMore } = await api(qs);
    if (!append) {
      S.musteriler = musteriler;
    } else {
      S.musteriler = [...(S.musteriler || []), ...musteriler];
    }
    const liste = document.getElementById("mus-liste");
    if (!liste) return;
    // Remove existing "load more" button before updating
    document.getElementById("daha-fazla-btn")?.remove();
    if (!append) {
      liste.innerHTML = S.musteriler.length ? S.musteriler.map(kartHtml).join("") : `<div class="saha-bos">Müşteri bulunamadı.</div>`;
    } else {
      if (musteriler.length) liste.insertAdjacentHTML("beforeend", musteriler.map(kartHtml).join(""));
    }
    wireKartlar(liste);
    if (hasMore) {
      const daha = document.createElement("button");
      daha.id = "daha-fazla-btn";
      daha.className = "ghost-button";
      daha.style.cssText = "width:100%;margin-top:8px;padding:10px;font-size:13px;border-radius:8px";
      daha.textContent = "↓ Daha fazla yükle";
      daha.addEventListener("click", async () => {
        daha.disabled = true; daha.textContent = "Yükleniyor…";
        await yukle(currentQ, currentOffset + PAGE_SIZE, true);
      });
      liste.appendChild(daha);
    }
  };

  S.birlestirSecim = null; // null = normal mod; Set = birleştirme modu
  main().innerHTML = `
    <button class="saha-cta" id="yeni-musteri">＋ Müşteri</button>
    <input class="giris" id="mus-filtre" placeholder="🔍 Ara — firma, şehir, ilçe, ERP kodu, vergi no" autocomplete="off">
    <div id="kontrol-paneli"></div>
    ${S.role !== "rep" ? `<div id="bakim-paneli"></div>` : ""}
    <div id="mus-liste"><div class="saha-load">Yükleniyor…</div></div>`;
  if (S.role !== "rep") bakimPaneliYukle();
  kontrolPaneliYukle();
  main().querySelector("#yeni-musteri").addEventListener("click", () =>
    musteriSecModal(async m => {
      await loadView("musteriler");
      musteriDetayModal(m);
    }));
  let t = null;
  document.getElementById("mus-filtre").addEventListener("input", ev => {
    clearTimeout(t); t = setTimeout(() => yukle(ev.target.value.trim(), 0, false), 300);
  });
  try { await yukle("", 0, false); } catch (e) { main().innerHTML = hata(e); }
}

// ── Veri bakımı: eşleştirme onayı + mükerrer birleştirme (GM/müdür) ─────────
async function kontrolPaneliYukle() {
  const box = document.getElementById("kontrol-paneli");
  if (!box) return;
  let list = [];
  try { list = (await api("/api/saha/kontrol-musteriler")).musteriler || []; } catch { box.innerHTML = ""; return; }
  if (!list.length) { box.innerHTML = ""; return; }
  box.innerHTML = `
    <div style="background:#fffbeb;border:1px solid #fcd34d;border-radius:10px;padding:10px 12px;margin:8px 0">
      <div style="font-weight:700;color:#92400e;font-size:13px;margin-bottom:4px">🔎 Kontrol Bekleyen Müşteri (${list.length})</div>
      <div style="font-size:11px;color:#b45309;margin-bottom:8px">Excel'den gelen bu kayıtlar mevcut bir müşteriyle aynı olabilir. Karar ver:</div>
      ${list.map(m => `
        <div class="kart" style="margin-bottom:6px;padding:8px 10px;background:#fff">
          <div style="font-weight:600">${esc(m.firma)}${(m.il || m.ilce) ? ` <span style="color:#0f766e;font-size:11px">· 📍${esc([m.il, m.ilce].filter(Boolean).join(" / "))}</span>` : ""} <span style="color:#94a3b8;font-size:11px">· ${m.ziyaret_sayisi} ziyaret</span></div>
          ${m.oneri_firma
            ? `<div style="font-size:11px;color:#64748b;margin:3px 0">Olası eş: <b>${esc(m.oneri_firma)}</b>${m.oneri_il ? ` · 📍${esc(m.oneri_il)}` : ""} <span style="color:#94a3b8">(benzerlik ${m.oneri_skor ?? "-"})</span></div>`
            : (m.notlar ? `<div style="font-size:11px;color:#64748b;margin:3px 0">${esc(m.notlar)}</div>` : "")}
          <div style="display:flex;gap:6px;margin-top:6px;flex-wrap:wrap">
            <button class="btn" data-kb="${m.id}" style="font-size:12px;padding:5px 10px">🔗 Saha müşterisi</button>
            <button class="btn" data-kl="${m.id}" style="font-size:12px;padding:5px 10px;background:#7c3aed">📍 Şube olarak bağla</button>
            <button class="btn" data-ke="${m.id}" style="font-size:12px;padding:5px 10px;background:#0891b2">🏢 ERP'den eşleştir</button>
            <button class="btn cizgili" data-ky="${m.id}" style="font-size:12px;padding:5px 10px">✓ Yeni müşteri</button>
          </div>
        </div>`).join("")}
    </div>`;
  box.querySelectorAll("[data-ky]").forEach(b => b.addEventListener("click", async () => {
    if (!confirm("Bu kayıt YENİ müşteri olarak onaylansın mı?")) return;
    try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: b.dataset.ky, karar: "YENI" }) }); uyari("✓ Yeni müşteri olarak onaylandı.", true); kontrolPaneliYukle(); }
    catch (e) { uyari(e.message); }
  }));
  box.querySelectorAll("[data-kb]").forEach(b => b.addEventListener("click", () => {
    const kid = b.dataset.kb;
    musteriSecModal(async target => {
      if (!target || target.id === kid) { uyari("Farklı, mevcut bir müşteri seç."); return; }
      try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: kid, karar: "BIRLESTIR", hedef_id: target.id }) }); uyari("✓ Birleştirildi.", true); await loadView("musteriler"); }
      catch (e) { uyari(e.message); }
    });
  }));
  box.querySelectorAll("[data-ke]").forEach(b => b.addEventListener("click", () => erpEslesModal(b.dataset.ke)));
  box.querySelectorAll("[data-kl]").forEach(b => b.addEventListener("click", () => {
    const kid = b.dataset.kl;
    musteriSecModal(async target => {
      if (!target || target.id === kid) { uyari("Bağlanacak ana müşteriyi seç."); return; }
      if (!confirm(`Bu kayıt "${target.firma || "seçilen müşteri"}" firmasının şubesi/lokasyonu olarak bağlansın mı? Ziyaretleri o müşteriye taşınır.`)) return;
      try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: kid, karar: "LOKASYON", hedef_id: target.id }) }); uyari("✓ Şube olarak bağlandı.", true); await loadView("musteriler"); }
      catch (e) { uyari(e.message); }
    });
  }));
}

function erpEslesModal(kid) {
  modal(`
    <h3>🏢 ERP'den Eşleştir</h3>
    <div style="font-size:11px;color:#64748b;margin-bottom:6px">ERP müşteri veritabanında (tüm kayıtlar) doğru firmayı ara ve seç.</div>
    <input class="giris" id="erp-q" placeholder="Firma adı ara…" autocomplete="off">
    <div id="erp-sonuc" style="max-height:280px;overflow:auto;margin-top:8px"></div>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Vazgeç</button></div>`);
  const qEl = document.getElementById("erp-q");
  const rEl = document.getElementById("erp-sonuc");
  let t = null;
  qEl.focus();
  qEl.addEventListener("input", () => {
    clearTimeout(t);
    t = setTimeout(async () => {
      const q = qEl.value.trim();
      if (q.length < 2) { rEl.innerHTML = ""; return; }
      rEl.innerHTML = "<div style='color:#94a3b8;font-size:12px;padding:8px'>Aranıyor…</div>";
      try {
        const { sonuclar } = await api(`/api/saha/erp-ara?q=${encodeURIComponent(q)}`);
        rEl.innerHTML = sonuclar.length ? sonuclar.map(x => `
          <div class="kart" data-erp="${esc(x.kod)}" style="cursor:pointer;padding:8px 10px;margin-bottom:4px">
            <div style="font-weight:600;font-size:13px">${esc(x.musteri_adi)}</div>
            <div style="font-size:11px;color:#64748b">${esc(x.sehir || "")} · ${esc(x.kod)}</div>
          </div>`).join("") : "<div style='color:#94a3b8;font-size:12px;padding:8px'>Sonuç yok.</div>";
        rEl.querySelectorAll("[data-erp]").forEach(el => el.addEventListener("click", async () => {
          if (!confirm("Bu ERP müşterisiyle eşleştirilsin mi?")) return;
          try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: kid, karar: "ERP_ESLE", erp_kod: el.dataset.erp }) }); kapatModal(); uyari("✓ ERP'den eşleştirildi.", true); await loadView("musteriler"); }
          catch (e) { uyari(e.message); }
        }));
      } catch (e) { rEl.innerHTML = "<div style='color:#ef4444;font-size:12px;padding:8px'>Hata: " + esc(e.message) + "</div>"; }
    }, 300);
  });
}

async function bakimPaneliYukle() {
  const kutu = document.getElementById("bakim-paneli");
  if (!kutu) return;
  try {
    const { toplam: eslsizToplam } = await api("/api/saha/eslestirilmemis");
    kutu.innerHTML = eslsizToplam
      ? `<div class="esik-kutu" style="margin-bottom:8px;font-size:13px;color:#888">📋 ${eslsizToplam} eşleşmemiş müşteri</div>`
      : "";
  } catch { /* rep veya hata — panel gösterme */ }
}

async function eslestirmeGenislet() {
  const btn = document.getElementById("esl-genislet");
  if (btn) { btn.disabled = true; btn.textContent = "🔄 Taranıyor…"; }
  try {
    const r = await api("/api/saha/eslestirme-genislet", { method: "POST" });
    const otoPart = r.otomatik ? ` (${r.otomatik} tam eşleşme otomatik onaylandı)` : "";
    uyari(`✓ ${r.eklenen} eşleşme${otoPart} — ${r.tarandi} kayıt tarandı. Kalanlar için İncele butonunu kullanın.`, true);
    await bakimPaneliYukle();
    // Müşteri listesini de yenile ki rozetler güncellensin
    if (S.musteriler) {
      const { musteriler } = await api(`/api/saha/musteriler`);
      S.musteriler = musteriler;
      const liste = document.getElementById("mus-liste");
      if (liste) {
        // Trigger re-render by simulating a filter change
        const filtre = document.getElementById("mus-filtre");
        filtre?.dispatchEvent(new Event("input"));
      }
    }
  } catch (e) {
    uyari(e.message || "Tarama başarısız.");
    if (btn) { btn.disabled = false; btn.textContent = "🔎 Algoritmayı Genişlet"; }
  }
}

function eslestirmeModal() {
  const BANTLAR = [
    { id: "90", label: "Yüksek", min: 90, max: 101, renk: "#10b981" },
    { id: "80", label: "Orta",   min: 80, max: 90,  renk: "#0284c7" },
    { id: "70", label: "Düşük",  min: 70, max: 80,  renk: "#f59e0b" },
    { id: "00", label: "Zayıf",  min: 0,  max: 70,  renk: "#ef4444" },
  ];
  let aktifBant = "90";

  function bantOneriler(b) {
    return S.oneriler.filter(o => Number(o.skor) >= b.min && Number(o.skor) < b.max);
  }

  function kartHtml(o) {
    const sk = Number(o.skor);
    const bg = sk >= 90 ? "#10b981" : sk >= 80 ? "#0284c7" : sk >= 70 ? "#f59e0b" : "#ef4444";
    return `
    <div class="kart" id="oneri-${o.id}">
      <div class="kart-ust"><b>${esc(o.firma)}</b><span class="rozet" style="background:${bg}">%${Math.round(sk)}</span></div>
      <div class="kart-alt"><span>${esc(o.il || "")}</span><span>${o.ziyaret_sayisi} ziyaret</span></div>
      <div class="kart-not">→ <b>${esc(o.oneri_musteri_adi)}</b><br>
        <small>${esc(o.oneri_musteri_kodu)}${o.toplam_ciro != null ? ` · Ciro ${Math.round(o.toplam_ciro / 1000).toLocaleString("tr-TR")}K₺ (${o.fatura_sayisi} fatura)` : " · ERP'de satış verisi yok"}${o.son_fatura ? ` · Son alım ${new Date(o.son_fatura).toLocaleDateString("tr-TR")}` : ""}${o.sehir ? ` · ${esc(o.sehir)}` : ""}</small></div>
      <div class="kart-btnlar">
        <button class="btn kucuk" data-esl="${o.id}|ONAY">✓ Doğru</button>
        <button class="btn kucuk kirmizi-btn" data-esl="${o.id}|RED">✕ Yanlış</button>
      </div>
    </div>`;
  }

  async function topluOnayla(bant) {
    const b = BANTLAR.find(x => x.id === bant);
    const liste = bantOneriler(b);
    if (!liste.length) { uyari("Bu bantta onaylanacak öneri yok."); return; }
    const ornekler = liste.slice(0, 3).map(o => `• ${o.firma} → ${o.oneri_musteri_adi}`).join("\n");
    const devam = confirm(`${liste.length} eşleştirme onaylanacak:\n\n${ornekler}${liste.length > 3 ? `\n...ve ${liste.length - 3} daha` : ""}\n\nOnaylıyor musunuz?`);
    if (!devam) return;
    const btn = document.getElementById("esl-toplu");
    if (btn) btn.disabled = true;
    try {
      const body = { min_skor: b.min };
      if (b.max < 101) body.max_skor = b.max;
      const r = await api("/api/saha/eslestirme-toplu-onayla", { method: "POST", body: JSON.stringify(body) });
      S.oneriler = S.oneriler.filter(o => !(Number(o.skor) >= b.min && Number(o.skor) < b.max));
      uyari(`✓ ${r.guncellenen} eşleştirme onaylandı.`, true);
      renderEslIcerik();
      const sayi = document.getElementById("esl-sayi");
      if (sayi) sayi.textContent = S.oneriler.length;
      if (!S.oneriler.length) { kapatModal(); bakimPaneliYukle(); }
    } catch (e) { if (btn) btn.disabled = false; uyari(e.message); }
  }

  function renderEslIcerik() {
    const icerik = document.getElementById("esl-icerik");
    if (!icerik) return;
    const b = BANTLAR.find(x => x.id === aktifBant);
    const liste = bantOneriler(b);
    const tabsHtml = BANTLAR.map(bnt => {
      const n = bantOneriler(bnt).length;
      return `<button class="chip ${bnt.id === aktifBant ? "on" : ""}" data-bant="${bnt.id}" style="${bnt.id === aktifBant ? `background:${bnt.renk};color:#fff` : ""}">${bnt.label} <span style="background:rgba(0,0,0,.15);border-radius:9px;padding:1px 6px;font-size:11px">${n}</span></button>`;
    }).join("");
    icerik.innerHTML = `
      <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px">${tabsHtml}</div>
      ${liste.length ? `<button class="btn" id="esl-toplu" style="width:100%;margin-bottom:8px;background:#f59e0b;color:#fff;font-weight:600">⚡ Bu banttaki ${liste.length} öneriyi toplu onayla</button>` : ""}
      <div id="esl-liste" style="max-height:52vh;overflow-y:auto">${liste.length ? liste.map(kartHtml).join("") : `<p class="mini-durum" style="padding:24px;text-align:center">Bu bantta öneri yok.</p>`}</div>`;
    icerik.querySelectorAll("[data-bant]").forEach(b => b.addEventListener("click", () => { aktifBant = b.dataset.bant; renderEslIcerik(); }));
    document.getElementById("esl-toplu")?.addEventListener("click", () => topluOnayla(aktifBant));
    document.getElementById("esl-liste")?.addEventListener("click", async ev => {
      const btn = ev.target.closest("[data-esl]");
      if (!btn) return;
      const [id, karar] = btn.dataset.esl.split("|");
      btn.disabled = true;
      try {
        await api(`/api/saha/eslestirme-onerileri/${id}/karar`, { method: "POST", body: JSON.stringify({ karar }) });
        document.getElementById("oneri-" + id)?.remove();
        S.oneriler = S.oneriler.filter(o => o.id !== id);
        const sayi = document.getElementById("esl-sayi");
        if (sayi) sayi.textContent = S.oneriler.length;
        if (!S.oneriler.length) { kapatModal(); uyari("✓ Tüm öneriler karara bağlandı.", true); bakimPaneliYukle(); }
      } catch (e) { btn.disabled = false; uyari(e.message); }
    });
  }

  modal(`
    <h3>ERP Eşleştirme Onayı <span class="rozet" style="background:#0284c7" id="esl-sayi">${S.oneriler.length}</span></h3>
    <p class="mini-durum">Saha kartı → önerilen ERP carisi. Onaylanan kart bakiye/ciro/satış geçmişine bağlanır.</p>
    <div id="esl-icerik"></div>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Kapat</button></div>`);
  renderEslIcerik();
}

async function eslestirmeManuelModal() {
  let kayitlar = [];
  let arama = "";

  async function yukle() {
    const r = await api(`/api/saha/eslestirilmemis${arama.length >= 2 ? `?q=${encodeURIComponent(arama)}` : ""}`);
    kayitlar = r.kayitlar;
    return r.toplam;
  }

  async function erpAra(q) {
    if (q.length < 2) return [];
    const r = await api(`/api/saha/musteri-ara?q=${encodeURIComponent(q)}`);
    return r.sonuclar.filter(s => s.kaynak === "ERP");
  }

  function kartHtml(k) {
    return `
    <div class="kart" id="esls-${k.id}">
      <div class="kart-ust"><b>${esc(k.firma)}</b><span style="color:#94a3b8;font-size:12px">${esc(k.il || "")}</span></div>
      <div class="kart-alt"><span>${k.tip}</span><span>${k.ziyaret_sayisi} ziyaret</span></div>
      <div id="esls-ara-${k.id}">
        <div style="display:flex;gap:6px;margin-top:6px">
          <input class="input" placeholder="ERP müşteri ara..." id="esls-input-${k.id}" style="flex:1;font-size:13px;padding:6px 10px">
          <button class="btn kucuk gri" data-ara="${k.id}">Ara</button>
        </div>
        <div id="esls-sonuc-${k.id}" style="margin-top:4px"></div>
      </div>
    </div>`;
  }

  function renderListe(toplam) {
    const icerik = document.getElementById("esls-icerik");
    if (!icerik) return;
    icerik.innerHTML = `
      <div style="display:flex;gap:6px;margin-bottom:10px">
        <input class="input" id="esls-filtre" placeholder="Firma ara..." value="${esc(arama)}" style="flex:1;font-size:13px;padding:6px 10px">
        <button class="btn kucuk" id="esls-filtre-btn">Filtrele</button>
      </div>
      <p class="mini-durum" style="margin-bottom:8px">Toplam ${toplam} eşleştirilmemiş${kayitlar.length < toplam ? ` (ilk ${kayitlar.length} gösteriliyor)` : ""}</p>
      <div id="esls-liste" style="max-height:55vh;overflow-y:auto">${kayitlar.map(kartHtml).join("")}</div>`;

    document.getElementById("esls-filtre-btn")?.addEventListener("click", async () => {
      arama = document.getElementById("esls-filtre")?.value.trim() || "";
      const top = await yukle();
      renderListe(top);
    });
    document.getElementById("esls-filtre")?.addEventListener("keydown", async e => {
      if (e.key === "Enter") { arama = e.target.value.trim(); const top = await yukle(); renderListe(top); }
    });

    document.getElementById("esls-liste")?.addEventListener("click", async ev => {
      // Ara butonu
      const araBtn = ev.target.closest("[data-ara]");
      if (araBtn) {
        const kid = araBtn.dataset.ara;
        const q = document.getElementById(`esls-input-${kid}`)?.value.trim() || "";
        const sonuclar = await erpAra(q);
        const sonucDiv = document.getElementById(`esls-sonuc-${kid}`);
        if (!sonucDiv) return;
        if (!sonuclar.length) { sonucDiv.innerHTML = `<p class="mini-durum">Sonuç yok.</p>`; return; }
        sonucDiv.innerHTML = sonuclar.map(s => `
          <div style="display:flex;justify-content:space-between;align-items:center;padding:6px 0;border-bottom:1px solid #f1f5f9">
            <span style="font-size:13px"><b>${esc(s.firma)}</b> <small style="color:#94a3b8">${esc(s.musteri_kodu)}${s.toplam_ciro != null ? ` · ${Math.round(s.toplam_ciro/1000).toLocaleString("tr-TR")}K₺` : ""}</small></span>
            <button class="btn kucuk" data-sec="${kid}|${s.musteri_kodu}">Seç</button>
          </div>`).join("");
        return;
      }
      // Seç butonu
      const secBtn = ev.target.closest("[data-sec]");
      if (secBtn) {
        const [kid, mk] = secBtn.dataset.sec.split("|");
        secBtn.disabled = true;
        try {
          await api("/api/saha/musteri-manuel-esles", { method: "POST", body: JSON.stringify({ saha_musteri_id: kid, musteri_kodu: mk }) });
          document.getElementById(`esls-${kid}`)?.remove();
          kayitlar = kayitlar.filter(k => k.id !== kid);
          uyari("✓ Eşleştirildi.", true);
          if (!kayitlar.length) { kapatModal(); bakimPaneliYukle(); }
        } catch (e) { secBtn.disabled = false; uyari(e.message); }
      }
    });
  }

  modal(`
    <h3>Manuel ERP Eşleştirme</h3>
    <p class="mini-durum">Algoritmanın öneri veremediği müşterileri ERP'de arayarak eşleştirin.</p>
    <div id="esls-icerik"><p class="mini-durum">Yükleniyor…</p></div>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Kapat</button></div>`);
  try {
    const toplam = await yukle();
    renderListe(toplam);
  } catch (e) { document.getElementById("esls-icerik").innerHTML = hata(e); }
}

function mukerrerModal() {
  let incelenmesi = []; // flagged groups needing manual review

  function grupHtml(gruplar) {
    return gruplar.map((g, gi) => {
      if (!g) return "";
      const enCok = g.kartlar.reduce((a, b) => (Number(b.ziyaret) > Number(a.ziyaret) ? b : a), g.kartlar[0]);
      return `
      <div class="muk-grup" id="supra-${gi}">
        <div class="muk-grup-baslik">
          <div class="muk-grup-baslik-sol">
            <span class="muk-grup-baslik-erp">${esc(g.erp_adi || g.musteri_kodu)}</span>
            <span class="erp-kod">${esc(g.musteri_kodu)}</span>
          </div>
          <span style="font-size:11px;color:#94a3b8">${g.kartlar.length} kart</span>
        </div>
        ${g.kartlar.map(k => `
          <div class="muk-radio${k.id === enCok.id ? " muk-radio-secili" : ""}">
            <span class="muk-radio-icerik">
              <span class="muk-radio-ad">${esc(k.firma)}${k.id === enCok.id ? " ★" : ""}</span>
              <span class="muk-radio-meta">${esc(k.il || "")} · ${k.ziyaret} ziyaret</span>
            </span>
          </div>`).join("")}
        <div class="muk-grup-btn" style="display:flex;gap:6px">
          <button class="btn kucuk" style="flex:1" data-mi="${gi}">✓ Birleştir</button>
          <button class="btn kucuk cizgili" style="flex:1;border-color:#ef4444;color:#ef4444" data-mr="${gi}">✗ Hatalı</button>
        </div>
      </div>`;
    }).join("");
  }

  function wireGruplar() {
    document.querySelectorAll("[data-mi]").forEach(b => b.addEventListener("click", async () => {
      const gi = Number(b.dataset.mi);
      const g = incelenmesi[gi];
      if (!g) return;
      const enCok = g.kartlar.reduce((a, b) => (Number(b.ziyaret) > Number(a.ziyaret) ? b : a), g.kartlar[0]);
      const digerler = g.kartlar.map(k => k.id).filter(id => id !== enCok.id);
      b.disabled = true;
      try {
        await api("/api/saha/mukerrer-birlestir", { method: "POST", body: JSON.stringify({ ana_id: enCok.id, diger_ids: digerler }) });
        document.getElementById(`supra-${gi}`)?.remove();
        incelenmesi[gi] = null;
        uyari(`✓ ${g.erp_adi || g.musteri_kodu} birleştirildi.`, true);
        if (incelenmesi.every(x => !x)) { kapatModal(); bakimPaneliYukle(); }
      } catch (e) { b.disabled = false; uyari(e.message); }
    }));
    document.querySelectorAll("[data-mr]").forEach(b => b.addEventListener("click", async () => {
      const gi = Number(b.dataset.mr);
      const g = incelenmesi[gi];
      if (!g) return;
      if (!confirm(`"${g.erp_adi || g.musteri_kodu}" — ${g.kartlar.length} kartın ERP bağlantısı kaldırılsın mı?`)) return;
      b.disabled = true;
      try {
        await api("/api/saha/mukerrer-reddet", { method: "POST", body: JSON.stringify({ ids: g.kartlar.map(k => k.id) }) });
        document.getElementById(`supra-${gi}`)?.remove();
        incelenmesi[gi] = null;
        uyari("✓ ERP bağlantısı kaldırıldı.", true);
        if (incelenmesi.every(x => !x)) { kapatModal(); bakimPaneliYukle(); }
      } catch (e) { b.disabled = false; uyari(e.message); }
    }));
  }

  modal(`
    <h3>Mükerrer Kartlar <span class="rozet" style="background:#0284c7">${S.mukerrerler.length} grup</span></h3>
    <div id="muk-icerik"><div class="saha-load">⏳ Çok lokasyonlu müşteriler otomatik birleştiriliyor…</div></div>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Kapat</button></div>`);

  // Smart merge on open — runs in background
  api("/api/saha/mukerrer-akilli-birlestir", { method: "POST" }).then(r => {
    incelenmesi = r.incelenmesi || [];
    S.mukerrerler = incelenmesi; // update local state
    const icerik = document.getElementById("muk-icerik");
    if (!icerik) return;
    if (!incelenmesi.length) {
      uyari(`✓ ${r.birlestirilen} grup otomatik birleştirildi — incelenmesi gereken yok.`, true);
      kapatModal(); bakimPaneliYukle(); return;
    }
    icerik.innerHTML = `
      <p class="mini-durum" style="margin-bottom:10px">✓ <b>${r.birlestirilen}</b> çok lokasyonlu grup otomatik birleştirildi. Aşağıdaki <b>${incelenmesi.length}</b> grup farklı şirket adları içeriyor — manuel inceleyin.</p>
      <div style="max-height:55vh;overflow-y:auto">${grupHtml(incelenmesi)}</div>`;
    wireGruplar();
    bakimPaneliYukle(); // refresh panel counts
  }).catch(e => {
    const icerik = document.getElementById("muk-icerik");
    if (icerik) icerik.innerHTML = `<p class="mini-durum" style="color:#ef4444">${esc(e.message)}</p>`;
  });
}

function kartBirlestirModal(ids) {
  const kartlar = ids.map(id => S.musteriler.find(x => x.id === id)).filter(Boolean);
  modal(`
    <h3>Kartları Birleştir</h3>
    <p class="mini-durum">Ana kartı seç — diğer kartların ziyaret/teklif/iskonto kayıtları ona taşınır,
    adresleri ana kartın <b>lokasyonları</b> olur, kendileri pasife alınır.</p>
    ${kartlar.map((k, i) => `
      <label style="display:flex;align-items:center;gap:8px;padding:8px 0;border-bottom:1px solid #f1f5f9;cursor:pointer">
        <input type="radio" name="kb-ana" value="${k.id}" ${i === 0 ? "checked" : ""}>
        <span style="flex:1"><b>${esc(k.firma)}</b> <small style="color:#94a3b8">${esc([k.il, k.ilce].filter(Boolean).join("/"))} · ${k.ziyaret_sayisi || 0} ziyaret${k.musteri_kodu ? " · " + esc(k.musteri_kodu) : ""}</small></span>
      </label>`).join("")}
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="kb-onayla">Birleştir</button>
    </div>`);
  document.getElementById("kb-onayla").addEventListener("click", async () => {
    const ana = document.querySelector('input[name="kb-ana"]:checked')?.value;
    if (!ana) { uyari("Ana kart seçin."); return; }
    const digerler = ids.filter(id => id !== ana);
    try {
      await api("/api/saha/mukerrer-birlestir", {
        method: "POST", body: JSON.stringify({ ana_id: ana, diger_ids: digerler })
      });
      kapatModal();
      uyari(`✓ ${digerler.length} kart birleştirildi — adresler lokasyona dönüştü.`, true);
      loadView("musteriler");
    } catch (e) { uyari(e.message); }
  });
}

function musteriDetayModal(m) {
  const [dl, dc] = DURUM_ETIKET[m.durum] || ["", "#999"];
  modal(`
    <h3>${esc(m.firma)}</h3>
    <div class="det-satir"><span>Tip</span><b>${m.tip === "TUKETICI" ? "Tüketici" : "Ticari"}</b></div>
    <div class="det-satir"><span>Durum</span>
      <span style="display:flex;align-items:center;gap:6px">
        <select class="giris" id="md-durum-sec" style="font-size:13px;padding:4px 8px;display:inline-block;width:auto;margin-bottom:0">
          ${Object.entries(DURUM_ETIKET).map(([k,[l]]) => `<option value="${k}" ${m.durum===k?"selected":""}>${l}</option>`).join("")}
        </select>
        <button class="btn kucuk" id="md-durum-kaydet">Kaydet</button>
      </span></div>
    ${m.musteri_kodu ? `<div class="det-satir"><span>ERP Kodu</span><b>${esc(m.musteri_kodu)}</b></div>` : ""}
    ${m.musteri_kodu
      ? (m.kimlik_vergi_no ? `<div class="det-satir"><span>VKN</span><b>${esc(m.kimlik_vergi_no)}</b></div>` : "")
      : `<div class="det-satir"><span>VKN</span>
          <span style="display:flex;align-items:center;gap:6px">
            <input class="giris" id="md-vkn" inputmode="numeric" placeholder="10 hane — sonradan eklenebilir" value="${esc(m.vergi_no || "")}" style="font-size:13px;padding:4px 8px;display:inline-block;width:auto;margin-bottom:0">
            <button class="btn kucuk" id="md-vkn-kaydet">Kaydet</button>
          </span></div>`}
    ${m.kimlik_tc_no ? `<div class="det-satir"><span>TC No</span><b>${esc(m.kimlik_tc_no)}</b></div>` : ""}
    ${m.il ? `<div class="det-satir"><span>Konum</span><b>${esc([m.il, m.ilce].filter(Boolean).join(" / "))}</b></div>` : ""}
    ${m.yetkili ? `<div class="det-satir"><span>Yetkili</span><b>${esc(m.yetkili)}</b></div>` : ""}
    ${m.telefon ? `<div class="det-satir"><span>Telefon</span><b><a href="tel:${esc(m.telefon)}">${esc(m.telefon)}</a></b></div>` : ""}
    <div class="det-satir"><span>Ziyaret</span><b>${m.ziyaret_sayisi || 0} kez${m.son_ziyaret ? " — son: " + new Date(m.son_ziyaret).toLocaleDateString("tr-TR") : ""}</b></div>
    <h4 class="bolum-baslik">Ziyaret Geçmişi</h4>
    <div id="mus-gecmis" class="mini-durum">Yükleniyor…</div>
    ${["manager","admin"].includes(S.role) ? `
    <div style="margin:8px 0 4px">
      <button class="btn kucuk cizgili" id="ai-ozet-btn" style="border-color:#8b5cf6;color:#8b5cf6">🤖 AI Özeti</button>
      <div id="ai-ozet-kutu" style="display:none;margin-top:10px;background:#faf5ff;border:1px solid #e9d5ff;border-radius:10px;padding:12px;font-size:13px;line-height:1.65;white-space:pre-wrap;color:#1e1b4b"></div>
    </div>` : ""}
    <h4 class="bolum-baslik">Lokasyonlar</h4>
    <div id="lok-liste" class="mini-durum">Yükleniyor…</div>
    <div class="yanyana">
      <label>Lokasyon adı<input class="giris" id="lok-ad" placeholder="Gebze Şube / Merkez Depo"></label>
      <label>İl<input class="giris" id="lok-il"></label>
      <label>İlçe<input class="giris" id="lok-ilce"></label>
    </div>
    <button class="btn kucuk cizgili" id="lok-ekle">＋ Lokasyon Ekle</button>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn cizgili" id="md-planla">🗓️ Planla</button>
      <button class="btn cizgili" id="md-teklif">＋ Teklif</button>
      <button class="btn" id="md-ziyaret">＋ Ziyaret</button>
    </div>`);
  document.getElementById("md-ziyaret").addEventListener("click", () => { kapatModal(); ziyaretFormModal(m, "kaydet"); });
  document.getElementById("md-planla").addEventListener("click", () => { kapatModal(); ziyaretFormModal(m, "planla"); });
  document.getElementById("md-teklif").addEventListener("click", () => { kapatModal(); teklifFormModal(m, null); });
  document.getElementById("md-durum-kaydet").addEventListener("click", async () => {
    const yeniDurum = document.getElementById("md-durum-sec")?.value;
    if (!yeniDurum || yeniDurum === m.durum) { uyari("Durum değişmedi."); return; }
    try {
      await api(`/api/saha/musteriler/${m.id}`, { method: "PUT", body: JSON.stringify({ durum: yeniDurum }) });
      const [nl] = DURUM_ETIKET[yeniDurum] || [yeniDurum];
      uyari(`✓ Durum güncellendi: ${nl}`, true);
      m.durum = yeniDurum;
      // Refresh the musteriler list in background so it reflects on next tab visit
      if (S.musteriler) { const idx = S.musteriler.findIndex(x => x.id === m.id); if (idx !== -1) S.musteriler[idx].durum = yeniDurum; }
    } catch (e) { uyari(e.message); }
  });
  document.getElementById("md-vkn-kaydet")?.addEventListener("click", async () => {
    const v = (document.getElementById("md-vkn")?.value || "").replace(/\D/g, "");
    if (v && (v.length < 10 || v.length > 11)) { uyari("Vergi No 10, TC 11 hane olmalı."); return; }
    try {
      await api(`/api/saha/musteriler/${m.id}`, { method: "PUT", body: JSON.stringify({ vergi_no: v || null }) });
      uyari(v ? "✓ Vergi No kaydedildi." : "✓ Vergi No temizlendi.", true);
      m.vergi_no = v || null; m.kimlik_vergi_no = v || null;
      if (S.musteriler) { const idx = S.musteriler.findIndex(x => x.id === m.id); if (idx !== -1) S.musteriler[idx].vergi_no = v || null; }
    } catch (e) { uyari(e.message); }
  });
  // Ziyaret geçmişi: tarih + temsilci + not (tıklayınca tam detay)
  (async () => {
    try {
      const { ziyaretler } = await api(`/api/saha/ziyaretler?musteri_id=${m.id}&durum=TAMAMLANDI`);
      const el = document.getElementById("mus-gecmis");
      if (!el) return;
      if (!ziyaretler.length) { el.textContent = "Tamamlanmış ziyaret yok."; return; }
      el.classList.remove("mini-durum");
      el.innerHTML = ziyaretler.slice(0, 15).map(z => `
        <div class="det-satir" data-gecmis="${z.id}" style="cursor:pointer;flex-direction:column;align-items:flex-start;gap:2px">
          <span style="color:#0f172a"><b>${z.ziyaret_tarihi ? new Date(z.ziyaret_tarihi).toLocaleDateString("tr-TR") : "—"}</b>
            <small style="color:#64748b">· ${esc(z.rep_full_name || z.rep_adi || "")}${z.lokasyon_adi ? " · 📍" + esc(z.lokasyon_adi) : ""}${Number(z.foto_sayisi) ? " · 📷" + z.foto_sayisi : ""}</small></span>
          ${z.notlar ? `<span style="color:#475569;font-size:12px">${esc(z.notlar.slice(0, 160))}${z.notlar.length > 160 ? "…" : ""}</span>` : `<span style="color:#cbd5e1;font-size:12px">not girilmemiş</span>`}
        </div>`).join("") + (ziyaretler.length > 15 ? `<div class="mini-durum">+ ${ziyaretler.length - 15} eski ziyaret daha (Ziyaretler sekmesinde)</div>` : "");
      el.querySelectorAll("[data-gecmis]").forEach(g => g.addEventListener("click", () => {
        S.ziyaretler = ziyaretler;
        ziyaretDetayModal(g.dataset.gecmis);
      }));
    } catch { const el = document.getElementById("mus-gecmis"); if (el) el.textContent = "Geçmiş yüklenemedi."; }
  })();
  const lokYukle = async () => {
    try {
      const { lokasyonlar } = await api(`/api/saha/musteriler/${m.id}/lokasyonlar`);
      const el = document.getElementById("lok-liste");
      if (!el) return;
      el.innerHTML = lokasyonlar.length ? lokasyonlar.map(l => `
        <span class="cip on" style="margin:2px 4px 2px 0;display:inline-flex;align-items:center;gap:6px">
          📍 ${esc(l.ad)}${l.il ? " · " + esc([l.il, l.ilce].filter(Boolean).join("/")) : ""}
          <b data-lok-sil="${l.id}" style="cursor:pointer">✕</b>
        </span>`).join("") : "Lokasyon yok — tek adresli müşteri.";
      el.querySelectorAll("[data-lok-sil]").forEach(b => b.addEventListener("click", async () => {
        if (!confirm("Lokasyon silinsin mi?")) return;
        try { await api(`/api/saha/lokasyonlar/${b.dataset.lokSil}`, { method: "DELETE" }); await lokYukle(); }
        catch (e) { uyari(e.message); }
      }));
    } catch { /* yok say */ }
  };
  lokYukle();
  document.getElementById("lok-ekle")?.addEventListener("click", async () => {
    const g = id => document.getElementById(id).value.trim();
    if (!g("lok-ad")) { uyari("Lokasyon adı zorunlu."); return; }
    try {
      await api(`/api/saha/musteriler/${m.id}/lokasyonlar`, {
        method: "POST",
        body: JSON.stringify({ ad: g("lok-ad"), il: g("lok-il") || null, ilce: g("lok-ilce") || null })
      });
      ["lok-ad", "lok-il", "lok-ilce"].forEach(id => document.getElementById(id).value = "");
      await lokYukle();
    } catch (e) { uyari(e.message); }
  });

  // AI özeti butonu
  document.getElementById("ai-ozet-btn")?.addEventListener("click", async () => {
    const btn = document.getElementById("ai-ozet-btn");
    const kutu = document.getElementById("ai-ozet-kutu");
    if (!btn || !kutu) return;
    if (kutu.style.display !== "none") { kutu.style.display = "none"; btn.textContent = "🤖 AI Özeti"; return; }
    btn.textContent = "⏳ Analiz ediliyor…"; btn.disabled = true;
    kutu.style.display = "block";
    kutu.innerHTML = `<div style="color:#7c3aed;font-size:12px">Ziyaret notları ve teklif geçmişi analiz ediliyor…</div>`;
    try {
      const { json, ozet, not_sayisi, teklif_sayisi, tarih_araligi, trend } = await api(`/api/saha/ai/musteri-ozeti/${m.id}`);
      if (json) {
        const trendC = trend === "artıyor" ? "#10b981" : trend === "azalıyor" ? "#ef4444" : "#6b7280";
        const trendI = trend === "artıyor" ? "↑" : trend === "azalıyor" ? "↓" : "→";
        kutu.innerHTML = `
          <div style="display:flex;gap:8px;flex-wrap:wrap;font-size:11px;color:#7c3aed;font-weight:600;margin-bottom:10px">
            ${not_sayisi ? `<span>📊 ${not_sayisi} not</span>` : ""}
            ${teklif_sayisi ? `<span>💼 ${teklif_sayisi} teklif</span>` : ""}
            ${tarih_araligi ? `<span>📅 ${tarih_araligi}</span>` : ""}
            ${trend ? `<span style="color:${trendC}">${trendI} Ziyaret ${trend}</span>` : ""}
          </div>
          <div style="font-size:13px;color:#1e1b4b;line-height:1.65;margin-bottom:10px">${esc(json.genel_durum)}</div>
          ${json.one_cikan_konular?.length ? `
          <div style="margin-bottom:10px">
            <div style="font-size:10px;font-weight:700;color:#374151;margin-bottom:4px;text-transform:uppercase;letter-spacing:0.4px">Öne Çıkan Konular</div>
            ${json.one_cikan_konular.map(k => `<div style="font-size:12px;color:#374151;padding:2px 0">• ${esc(k)}</div>`).join("")}
          </div>` : ""}
          ${json.risk ? `
          <div style="background:#fef2f2;border:1px solid #fecaca;border-radius:8px;padding:9px 11px;margin-bottom:8px">
            <div style="font-size:10px;font-weight:700;color:#ef4444;margin-bottom:3px">⚠ RİSK</div>
            <div style="font-size:12px;color:#7f1d1d;line-height:1.5">${esc(json.risk)}</div>
          </div>` : ""}
          ${json.firsat ? `
          <div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;padding:9px 11px;margin-bottom:8px">
            <div style="font-size:10px;font-weight:700;color:#16a34a;margin-bottom:3px">✨ FIRSAT</div>
            <div style="font-size:12px;color:#14532d;line-height:1.5">${esc(json.firsat)}</div>
          </div>` : ""}
          ${json.aksiyon ? `
          <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:8px;padding:9px 11px">
            <div style="font-size:10px;font-weight:700;color:#1d4ed8;margin-bottom:3px">→ ÖNERİLEN AKSİYON</div>
            <div style="font-size:12px;color:#1e3a8a;line-height:1.5;font-weight:500">${esc(json.aksiyon)}</div>
          </div>` : ""}`;
      } else {
        kutu.innerHTML = `
          <div style="font-size:11px;color:#7c3aed;font-weight:600;margin-bottom:8px">📊 ${not_sayisi} not${tarih_araligi ? " · " + tarih_araligi : ""}</div>
          <div style="font-size:13px;line-height:1.6">${esc(ozet||"").replace(/\n/g,"<br>")}</div>`;
      }
      btn.textContent = "🤖 AI Özeti ✓";
    } catch(e) {
      kutu.innerHTML = `<div style="color:#ef4444;font-size:12px">Hata: ${esc(e.message)}</div>`;
      btn.textContent = "🤖 AI Özeti";
    }
    btn.disabled = false;
  });
}

// ── TEKLİF & İSKONTO ─────────────────────────────────────────────────────────
let _iskontoAC = null; // AbortController for delegated click listener

const KAYNAK_ETK = { ZIYARET: "🚶 Ziyaret", TELEFON: "📞 Telefon", WHATSAPP: "💬 WhatsApp", EMAIL: "✉️ E-posta", DIGER: "Diğer" };
const TEKLIF_DURUM = {
  TASLAK:        ["Taslak",            "#64748b"],
  ONAY_BEKLIYOR: ["Onay Bekliyor",     "#f59e0b"],
  ONAYLANDI:     ["Onaylandı",         "#0ea5e9"],
  SUNULDU:       ["Sunuldu",           "#8b5cf6"],
  KAZANILDI:     ["Kazanıldı ✓",       "#10b981"],
  KAYBEDILDI:    ["Kaybedildi",        "#ef4444"],
  IPTAL:         ["İptal",             "#94a3b8"]
};
const KAYIP_NEDEN = { FIYAT: "Fiyat", VADE: "Vade", STOK: "Stok", ILISKI: "İlişki", DIGER: "Diğer", BELIRTILMEDI: "Belirtilmedi" };

async function vIskonto() {
  try {
    const [{ teklifler }, { ayarlar }] = await Promise.all([
      api("/api/saha/teklifler"), api("/api/saha/ayarlar")
    ]);
    S.teklifler = teklifler; S.ayarlar = ayarlar;
    const yonetici = S.role !== "rep";

    // Partition by status
    const taslaklar    = teklifler.filter(t => t.durum === "TASLAK");
    const bekleyenler  = teklifler.filter(t => t.durum === "ONAY_BEKLIYOR");
    const onaylananlar = teklifler.filter(t => t.durum === "ONAYLANDI");
    const sunulanlar   = teklifler.filter(t => t.durum === "SUNULDU");
    const gecmis       = teklifler.filter(t => ["KAZANILDI","KAYBEDILDI","IPTAL"].includes(t.durum));

    main().innerHTML = `
      <button class="saha-cta" id="yeni-teklif" style="margin-bottom:8px">＋ Teklif</button>
      ${yonetici ? `
        <div class="esik-kutu">
          Genel eşik: ≤%${ayarlar.oto_onay_max} oto · %${ayarlar.oto_onay_max}–${ayarlar.mudur_max} müdür · >%${ayarlar.mudur_max} GM
          ${S.role === "admin" ? `<button class="btn kucuk cizgili" id="esik-duzenle">Eşik & Kural</button>
          <button class="btn kucuk cizgili" id="kullanici-yonet">👤 Kullanıcılar</button>` : ""}
        </div>` : ""}
      ${bekleyenler.length ? `
        <h4 class="bolum-baslik" style="color:#f59e0b">⏳ ${yonetici ? "Onay Bekleyen" : "Onay Bekleniyor — yönetici onayında"} (${bekleyenler.length})</h4>
        ${bekleyenler.map(t => teklifKart(t)).join("")}` : ""}
      ${taslaklar.length ? `<h4 class="bolum-baslik">${S.role === "rep" ? "Gönderilmeyi Bekleyenler" : "Taslak"} (${taslaklar.length})</h4>${taslaklar.map(t => teklifKart(t)).join("")}` : ""}
      ${onaylananlar.length ? `<h4 class="bolum-baslik">Onaylandı — Sunulmayı Bekliyor (${onaylananlar.length})</h4>${onaylananlar.map(t => teklifKart(t)).join("")}` : ""}
      ${sunulanlar.length ? `<h4 class="bolum-baslik">Müşteriye Sunuldu (${sunulanlar.length})</h4>${sunulanlar.map(t => teklifKart(t)).join("")}` : ""}
      ${!taslaklar.length && !bekleyenler.length && !onaylananlar.length && !sunulanlar.length ? `<div class="saha-bos">Aktif teklif yok.</div>` : ""}
      <h4 class="bolum-baslik">Teklif Geçmişi</h4>
      ${gecmis.length ? gecmis.map(t => teklifKart(t)).join("") : `<div class="saha-bos">Sonuçlanmış teklif yok.</div>`}`;

    main().querySelector("#yeni-teklif").addEventListener("click", () =>
      musteriSecModal(m => teklifFormModal(m, null)));
    main().querySelector("#esik-duzenle")?.addEventListener("click", esikModal);
    main().querySelector("#kullanici-yonet")?.addEventListener("click", kullaniciModal);

    // Card actions (event delegation) — abort previous listener to prevent accumulation
    if (_iskontoAC) _iskontoAC.abort();
    _iskontoAC = new AbortController();
    main().addEventListener("click", async ev => {
      // Gönder
      const gondBtn = ev.target.closest("[data-gonder]");
      if (gondBtn) {
        ev.stopPropagation();
        const t = S.teklifler.find(x => x.id === gondBtn.dataset.gonder);
        if (!t) return;
        try {
          await api(`/api/saha/teklifler/${t.id}`, { method: "PUT", body: JSON.stringify({ action: "gonder" }) });
          uyari("✓ Teklif gönderildi.", true);
          loadView("iskonto");
        } catch (e) { uyari(e.message); }
        return;
      }
      // Müşteriye Sun
      const sunBtn = ev.target.closest("[data-sun]");
      if (sunBtn) {
        ev.stopPropagation();
        try {
          await api(`/api/saha/teklifler/${sunBtn.dataset.sun}`, { method: "PUT", body: JSON.stringify({ action: "sun" }) });
          uyari("✓ Müşteriye sunuldu.", true);
          loadView("iskonto");
        } catch (e) { uyari(e.message); }
        return;
      }
      // Onayla (manager/admin)
      const onayBtn = ev.target.closest("[data-onayla]");
      if (onayBtn) {
        ev.stopPropagation();
        try {
          await api(`/api/saha/teklifler/${onayBtn.dataset.onayla}`, { method: "PUT", body: JSON.stringify({ action: "onayla" }) });
          uyari("✓ Teklif onaylandı.", true);
          loadView("iskonto");
        } catch (e) { uyari(e.message); }
        return;
      }
      // Reddet (manager/admin)
      const redBtn = ev.target.closest("[data-reddet]");
      if (redBtn) {
        ev.stopPropagation();
        const not = prompt("Red gerekçesi (opsiyonel):");
        try {
          await api(`/api/saha/teklifler/${redBtn.dataset.reddet}`, { method: "PUT", body: JSON.stringify({ action: "reddet", not: not || null }) });
          uyari("Teklif reddedildi — taslağa döndü.", true);
          loadView("iskonto");
        } catch (e) { uyari(e.message); }
        return;
      }
      // Sonuç (kazandık/kaybettik)
      const sonucBtn = ev.target.closest("[data-sonuc]");
      if (sonucBtn) {
        ev.stopPropagation();
        const t = S.teklifler.find(x => x.id === sonucBtn.dataset.sonuc);
        if (t) teklifSonucModal(t, sonucBtn.dataset.tip);
        return;
      }
      // Card click → detail
      const kart = ev.target.closest("[data-teklif-id]");
      if (kart) {
        const t = S.teklifler.find(x => x.id === kart.dataset.teklifId);
        if (t) teklifDetayModal(t);
      }
    }, { signal: _iskontoAC.signal });

    // Tab badge: reps see how many approved quotes need presenting; managers see pending approvals
    const badgeSayi = yonetici ? bekleyenler.length : onaylananlar.length;
    tabBadge("iskonto", badgeSayi);

    // Toast rep once per newly-approved quote (not seen before in this session)
    if (!yonetici && onaylananlar.length) {
      const yeniler = onaylananlar.filter(t => !S.gosterilmisOnaylandi.has(t.id));
      if (yeniler.length) {
        uyari(`✓ ${yeniler.length} teklifiniz onaylandı — müşteriye sunmayı unutmayın!`, true);
        yeniler.forEach(t => S.gosterilmisOnaylandi.add(t.id));
      }
    }

  } catch (e) { main().innerHTML = hata(e); }
}

function teklifKart(t) {
  const [dl, dc] = TEKLIF_DURUM[t.durum] || [t.durum, "#999"];
  const yonetici = S.role !== "rep";
  const pct = v => v != null ? `%${Number(v)}` : null;
  const indirimler = [pct(t.tedarikci_destek_pct), pct(t.musteri_ek_iskonto_pct)].filter(Boolean).join(" + ");
  return `
  <div class="kart" id="kayit-${t.id}" data-teklif-id="${t.id}" style="cursor:pointer">
    <div class="kart-ust">
      <b>${esc(t.firma)}</b>
      ${Number(t.kalem_sayisi) > 1
        ? `<span style="font-size:11px;color:#64748b;font-weight:400"> · ${t.kalem_sayisi} kalem</span>`
        : t.marka ? `<span style="font-size:12px;color:#334155;font-weight:400"> — ${esc(t.marka)}${t.model ? " " + esc(t.model) : ""}</span>` : ""}
      <span class="rozet" style="background:${dc}">${dl}</span>
    </div>
    <div class="kart-alt">
      ${Number(t.kalem_sayisi) > 1
        ? `<span>${t.kalem_sayisi} ürün · ${t.toplam_tutar ? `<b>${Number(t.toplam_tutar).toLocaleString("tr-TR")}₺</b>` : ""}</span>`
        : `
          ${[t.ebat, t.kategori, KURAL_ETIKET.sezon[t.sezon]].filter(Boolean).map(x => `<span>${esc(x)}</span>`).join("")}
          <span>${t.adet} adet</span>
          ${t.toplam_tutar ? `<span><b>${Number(t.toplam_tutar).toLocaleString("tr-TR")}₺</b></span>` : ""}`}
      ${yonetici ? `<span>👤 ${esc(t.rep_full_name || "")}</span>` : ""}
      <span>${new Date(t.created_at).toLocaleDateString("tr-TR")}</span>
      ${t.kaynak ? `<span>${KAYNAK_ETK[t.kaynak] || t.kaynak}</span>` : ""}
    </div>
    ${t.durum === "KAYBEDILDI" ? `
      <div class="kart-not kirmizi-kenar">
        Kaybedildi → <b>${esc(t.rakip_marka || "?")}${t.rakip_model ? " " + esc(t.rakip_model) : ""}</b>
        ${t.rakip_fiyat ? ` · ${Number(t.rakip_fiyat).toLocaleString("tr-TR")}₺` : ""}
        ${t.kayip_nedeni ? ` · Neden: ${KAYIP_NEDEN[t.kayip_nedeni] || t.kayip_nedeni}` : ""}
      </div>` : ""}
    ${t.notlar ? `<div class="kart-not">${esc(t.notlar)}</div>` : ""}
    ${t.durum === "TASLAK" ? `
      <div class="kart-btnlar">
        <button class="btn kucuk" data-gonder="${t.id}">▶ Onaya Gönder</button>
      </div>` : ""}
    ${t.durum === "ONAY_BEKLIYOR" ? `
      <div style="margin:6px 0 4px;padding:6px 10px;background:#fef3c7;border-radius:6px;font-size:12px;color:#92400e">
        ⚠️ Onay Bekleniyor · ${t.onay_seviyesi === "GM" ? "GM" : "Müdür"} onayı gerekli
        ${t.musteri_ek_iskonto_pct != null ? ` · <b>Ek İskonto: %${Number(t.musteri_ek_iskonto_pct)}</b>` : ""}
      </div>` : ""}
    ${t.durum === "ONAY_BEKLIYOR" && yonetici ? `
      <div class="kart-btnlar">
        <button class="btn kucuk kirmizi-btn" data-reddet="${t.id}">✕ Reddet</button>
        <button class="btn kucuk" data-onayla="${t.id}">✓ Onayla</button>
      </div>` : ""}
    ${t.durum === "ONAYLANDI" ? `
      <div class="kart-btnlar">
        <button class="btn kucuk" data-sun="${t.id}">📋 Müşteriye Sun</button>
      </div>` : ""}
    ${t.durum === "SUNULDU" ? `
      <div class="kart-btnlar">
        <button class="btn kucuk kirmizi-btn" data-sonuc="${t.id}" data-tip="KAYBEDILDI">✕ Kaybettik</button>
        <button class="btn kucuk" data-sonuc="${t.id}" data-tip="KAZANILDI">✓ Kazandık</button>
      </div>` : ""}
  </div>`;
}

async function teklifDetayModal(t) {
  const fiyat = v => v != null ? `₺${Number(v).toLocaleString("tr-TR", { minimumFractionDigits: 2 })}` : "—";
  const pct   = v => v != null ? `%${Number(v)}` : "—";
  const [dl, dc] = TEKLIF_DURUM[t.durum] || [t.durum, "#999"];
  // Normalize kalemler — may come as JSON string from pg
  const kalemler = (() => {
    if (Array.isArray(t.kalemler) && t.kalemler.length) return t.kalemler;
    if (typeof t.kalemler === "string") {
      try { const p = JSON.parse(t.kalemler); if (Array.isArray(p) && p.length) return p; } catch(_) {}
    }
    // fallback: single-line from header
    if (t.marka) return [{ marka: t.marka, model: t.model, ebat: t.ebat, kategori: t.kategori,
      sezon: t.sezon, adet: t.adet, birim_fiyat: t.birim_fiyat, toplam_tutar: t.toplam_tutar,
      tesvik_garantili_pct: t.tesvik_garantili_pct, tedarikci_destek_pct: t.tedarikci_destek_pct }];
    return [];
  })();

  const approverMode = t.durum === "ONAY_BEKLIYOR" && S.role !== "rep";

  const kalemlerHTML = kalemler.length ? `
    <div style="margin-bottom:14px">
      <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:6px">
        Ürün Kalemleri (${kalemler.length})
      </div>
      <div style="overflow-x:auto;max-width:100%;border-radius:8px;border:1px solid #e2e8f0">
        <div style="display:grid;grid-template-columns:24px minmax(52px,1fr) 32px ${approverMode ? "50px 64px" : "56px 80px"} 80px 88px${approverMode ? " auto" : ""};background:#e2e8f0;padding:6px 0;font-size:11px;font-weight:600;color:#1e293b">
          <span style="padding:0 8px">#</span>
          <span style="padding:0 8px">Marka / Model / Ebat</span>
          <span style="padding:0 8px;text-align:right">Adet</span>
          <span style="padding:0 8px;text-align:right">İstenen İsk.</span>
          <span style="padding:0 8px;text-align:right">${approverMode ? "Onay İsk." : "Birim Fiyat"}</span>
          <span style="padding:0 8px;text-align:right">${approverMode ? "Birim Fiyat" : "Toplam"}</span>
          <span style="padding:0 8px;text-align:right">${approverMode ? "Toplam" : "Teşvik"}</span>
          ${approverMode ? `<span style="padding:0 8px;text-align:center">Karar</span>` : ""}
        </div>
        ${kalemler.map((k, i) => {
          const hasIsk = k.musteri_ek_iskonto_pct != null && Number(k.musteri_ek_iskonto_pct) > 0;
          const od = k.onay_durumu || "BEKLIYOR";
          const odColor = od === "ONAYLANDI" ? "#16a34a" : od === "REDDEDILDI" ? "#dc2626" : "#f59e0b";
          const odLabel = od === "ONAYLANDI" ? "✓" : od === "REDDEDILDI" ? "✕" : "⏳";
          return `
          <div style="display:grid;grid-template-columns:24px minmax(52px,1fr) 32px ${approverMode ? "50px 64px" : "56px 80px"} 80px 88px${approverMode ? " auto" : ""};padding:8px 0;border-top:1px solid #f1f5f9;font-size:12px;background:#fff;color:#0f172a;align-items:center">
            <span style="padding:0 8px;color:#94a3b8">${i + 1}</span>
            <span style="padding:0 8px">
              <b style="color:#0f172a">${esc(k.marka || "")}</b> <span style="color:#334155">${k.model ? esc(k.model) : ""}</span>
              ${k.ebat ? `<br><span style="color:#64748b;font-size:11px">${esc(k.ebat)}</span>` : ""}
              ${k.kategori ? ` <span style="color:#94a3b8;font-size:10px">${esc(k.kategori)}</span>` : ""}
              ${k.onay_notu ? `<br><span style="color:#64748b;font-size:10px;font-style:italic">${esc(k.onay_notu)}</span>` : ""}
            </span>
            <span style="padding:0 8px;text-align:right;color:#0f172a">${k.adet || 1}</span>
            <span style="padding:0 8px;text-align:right;${hasIsk ? "color:#dc2626;font-weight:700" : "color:#94a3b8"}">${hasIsk ? `%${Number(k.musteri_ek_iskonto_pct)}` : "—"}</span>
            ${approverMode ? `
            <span style="padding:0 8px;text-align:right">
              ${od !== "BEKLIYOR"
                ? `<span style="color:${odColor};font-weight:700">${k.onaylayan_iskonto_pct != null ? `%${Number(k.onaylayan_iskonto_pct)}` : "—"}</span>`
                : `<input type="number" data-kalem-isk="${k.kalem_id}" value="${k.musteri_ek_iskonto_pct || 0}" min="0" max="100" step="0.5"
                    style="width:56px;padding:3px 4px;border:1px solid #cbd5e1;border-radius:5px;font-size:12px;text-align:right;color:#0f172a;background:#fff">`
              }
            </span>` : ""}
            <span style="padding:0 8px;text-align:right;color:#0f172a">${k.birim_fiyat != null ? fiyat(k.birim_fiyat) : "—"}</span>
            <span style="padding:0 8px;text-align:right;font-weight:600;color:#0f172a">${k.toplam_tutar != null ? fiyat(k.toplam_tutar) : "—"}</span>
            ${!approverMode ? `<span style="padding:0 8px;text-align:right;color:#0ea5e9">${k.tesvik_garantili_pct != null ? pct(k.tesvik_garantili_pct) : "—"}</span>` : ""}
            ${approverMode ? `
            <span style="padding:0 8px;text-align:center">
              ${od !== "BEKLIYOR"
                ? `<span style="color:${odColor};font-weight:700;font-size:13px">${odLabel}</span>`
                : `<span style="display:inline-flex;gap:4px">
                    <button data-kalem-reddet="${k.kalem_id}" style="padding:3px 8px;background:#fee2e2;color:#dc2626;border:none;border-radius:5px;font-size:11px;font-weight:600;cursor:pointer">✕</button>
                    <button data-kalem-onayla="${k.kalem_id}" style="padding:3px 8px;background:#dcfce7;color:#16a34a;border:none;border-radius:5px;font-size:11px;font-weight:600;cursor:pointer">✓</button>
                  </span>`}
            </span>` : ""}
          </div>`;}).join("")}
        <div style="display:grid;grid-template-columns:24px minmax(52px,1fr) 32px ${approverMode ? "50px 64px" : "56px 80px"} 80px 88px${approverMode ? " auto" : ""};padding:8px 0;border-top:1px solid #e2e8f0;background:#f8fafc;font-size:12px;color:#0f172a">
          <span></span><span></span><span></span><span></span>${approverMode ? "<span></span>" : ""}
          <span style="padding:0 8px;text-align:right;color:#64748b;font-size:11px">Genel Toplam</span>
          <span style="padding:0 8px;text-align:right;font-weight:700;color:#0f172a">${fiyat(t.toplam_tutar)}</span>
          <span></span>${approverMode ? "<span></span>" : ""}
        </div>
      </div>
    </div>` : "";

  modal(`
    <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:12px">
      <h3 style="margin:0">${esc(t.firma)}</h3>
      <span class="rozet" style="background:${dc};flex-shrink:0">${dl}</span>
    </div>
    ${kalemlerHTML}
    ${t.durum === "ONAY_BEKLIYOR" ? `
    <div style="padding:8px 12px;background:#fef3c7;border-radius:8px;margin-bottom:12px;font-size:13px;color:#92400e">
      <b>⚠️ Onay Bekleniyor</b> — ${t.onay_seviyesi === "GM" ? "GM" : "Müdür"} onayı gerekli
      ${t.musteri_ek_iskonto_pct != null ? ` · İstenen ek iskonto: <b style="color:#dc2626">%${Number(t.musteri_ek_iskonto_pct)}</b>` : ""}
    </div>` : ""}
<div id="td-analiz-kutu" style="margin-bottom:12px"></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px 16px;font-size:13px;margin-bottom:14px">
      ${satirDet("Oluşturan", t.rep_full_name)}
      ${satirDet("Tarih",     new Date(t.created_at).toLocaleDateString("tr-TR"))}
    </div>
    ${t.notlar ? `<div class="kart-not" style="margin-bottom:12px">${esc(t.notlar)}</div>` : ""}
    ${t.durum === "KAYBEDILDI" ? `
      <div class="kart-not kirmizi-kenar" style="margin-bottom:12px">
        Rakip: <b>${esc(t.rakip_marka || "?")}${t.rakip_model ? " " + esc(t.rakip_model) : ""}</b>
        ${t.rakip_fiyat ? ` · ${fiyat(t.rakip_fiyat)}` : ""}
        ${t.kayip_nedeni ? ` · ${KAYIP_NEDEN[t.kayip_nedeni] || t.kayip_nedeni}` : ""}
      </div>` : ""}
    <div id="td-log-kutu" style="margin-bottom:12px">
      <div style="font-size:12px;color:#94a3b8">Değişiklik geçmişi yükleniyor…</div>
    </div>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      ${t.durum === "TASLAK" ? `
        <button class="btn" id="td-gonder">▶ Onaya Gönder</button>` : ""}
      ${t.durum === "ONAY_BEKLIYOR" && S.role !== "rep" ? `
        <button class="btn kucuk kirmizi-btn" id="td-reddet">✕ Tümünü Reddet</button>` : ""}
      ${t.durum === "ONAYLANDI" ? `
        <button class="btn" id="td-sun">📋 Müşteriye Sun</button>` : ""}
      ${t.durum === "SUNULDU" ? `
        <button class="btn kucuk kirmizi-btn" id="td-kaybet">✕ Kaybettik</button>
        <button class="btn kucuk" id="td-kazan">✓ Kazandık</button>` : ""}
      ${!["KAZANILDI","KAYBEDILDI","IPTAL","ONAY_BEKLIYOR"].includes(t.durum) ? `
        <button class="btn" id="td-duzenle">✏ Düzenle</button>` : ""}
    </div>`);

  // Load change history
  try {
    const { log } = await api(`/api/saha/teklifler/${t.id}/log`);
    const kutu = document.getElementById("td-log-kutu");
    if (!log.length) {
      kutu.innerHTML = `<div style="font-size:12px;color:#94a3b8">Değişiklik kaydı yok.</div>`;
    } else {
      kutu.innerHTML = `
        <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:6px">Değişiklik Geçmişi</div>
        ${log.map(l => `
          <div style="font-size:12px;border-left:2px solid #e2e8f0;padding:4px 8px;margin-bottom:4px;color:#64748b">
            <b style="color:#0f172a">${esc(l.alan)}</b>:
            ${l.eski_deger != null ? `<span style="text-decoration:line-through;opacity:.6">${esc(l.eski_deger)}</span> → ` : ""}
            <span style="color:#0ea5e9">${esc(l.yeni_deger)}</span>
            <span style="float:right">${new Date(l.degisim_tarihi).toLocaleString("tr-TR", { dateStyle: "short", timeStyle: "short" })}
              ${l.degistiren_ad ? `· ${esc(l.degistiren_ad)}` : ""}</span>
          </div>`).join("")}`;
    }
  } catch (_) { /* log fetch failure is non-critical */ }

  // Load per-line stock + rival decision context
  try {
    const _az = await api(`/api/saha/teklifler/${t.id}/analiz`);
    const _ak = document.getElementById("td-analiz-kutu");
    if (_ak) _ak.innerHTML = _teklifAnalizHTML(_az);
  } catch (_) {}

  // Action buttons
  document.getElementById("td-gonder")?.addEventListener("click", async () => {
    try {
      await api(`/api/saha/teklifler/${t.id}`, { method: "PUT", body: JSON.stringify({ action: "gonder" }) });
      kapatModal(); uyari("✓ Teklif gönderildi.", true); loadView("iskonto");
    } catch (e) { uyari(e.message); }
  });
  // Per-line approval buttons
  document.querySelectorAll("[data-kalem-onayla]").forEach(btn => {
    btn.addEventListener("click", async () => {
      const kalemId = btn.dataset.kalemOnayla;
      const iskInput = document.querySelector(`[data-kalem-isk="${kalemId}"]`);
      const onaylayan_iskonto_pct = iskInput ? Number(iskInput.value) : null;
      const onay_notu = prompt("Not ekle (opsiyonel):") || null;
      try {
        await api(`/api/saha/teklifler/${t.id}`, { method: "PUT",
          body: JSON.stringify({ action: "kalem-karar", kalem_id: kalemId, karar: "ONAYLANDI", onaylayan_iskonto_pct, onay_notu }) });
        kapatModal(); loadView("iskonto"); uyari("✓ Kalem onaylandı.", true);
      } catch (e) { uyari(e.message); }
    });
  });
  document.querySelectorAll("[data-kalem-reddet]").forEach(btn => {
    btn.addEventListener("click", async () => {
      const kalemId = btn.dataset.kalemReddet;
      const onay_notu = prompt("Red gerekçesi:") || null;
      try {
        await api(`/api/saha/teklifler/${t.id}`, { method: "PUT",
          body: JSON.stringify({ action: "kalem-karar", kalem_id: kalemId, karar: "REDDEDILDI", onay_notu }) });
        kapatModal(); loadView("iskonto"); uyari("Kalem reddedildi.", true);
      } catch (e) { uyari(e.message); }
    });
  });
  // Bulk reject (all lines at once)
  document.getElementById("td-reddet")?.addEventListener("click", async () => {
    if (!confirm(`Tüm kalemler reddedilsin mi?\n\n"${t.firma}" teklifindeki ${Number(t.kalem_sayisi) > 1 ? t.kalem_sayisi + " kalem" : "1 kalem"} taslağa döner.`)) return;
    const not = prompt("Red gerekçesi (opsiyonel):") || null;
    try {
      await api(`/api/saha/teklifler/${t.id}`, { method: "PUT", body: JSON.stringify({ action: "reddet", not }) });
      kapatModal(); uyari("Teklif reddedildi — taslağa döndü.", true); loadView("iskonto");
    } catch (e) { uyari(e.message); }
  });
  document.getElementById("td-sun")?.addEventListener("click", async () => {
    try {
      await api(`/api/saha/teklifler/${t.id}`, { method: "PUT", body: JSON.stringify({ action: "sun" }) });
      kapatModal(); uyari("✓ Müşteriye sunuldu.", true); loadView("iskonto");
    } catch (e) { uyari(e.message); }
  });
  document.getElementById("td-kazan")?.addEventListener("click", () => {
    kapatModal(); teklifSonucModal(t, "KAZANILDI");
  });
  document.getElementById("td-kaybet")?.addEventListener("click", () => {
    kapatModal(); teklifSonucModal(t, "KAYBEDILDI");
  });
  document.getElementById("td-duzenle")?.addEventListener("click", () => {
    kapatModal(); teklifDuzenleModal(t);
  });
}

// Helper for detail grid rows
function _marjHTML(k) {
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  if (k.fiyat_durumu === "liste_yok") return `<span style="color:#94a3b8;font-style:italic">Fiyat listesi yok — marj hesaplanamıyor</span>`;
  const marjColor = (k.marj_pct != null && k.marj_pct < 10) ? "#dc2626" : (k.marj_pct != null && k.marj_pct < 20) ? "#f59e0b" : "#16a34a";
  const karStr = k.kar_adet != null ? (` · Kâr: <b>₺${Number(k.kar_adet).toLocaleString("tr-TR")}/adet</b>`) : "";
  const iskStr = k.fiyat_durumu === "tesvik_yok" ? ` · <span style="color:#b45309">teşvik yok</span>` : (k.iskonto_pct != null ? ` · İndirim: <b>%${k.iskonto_pct}</b>` : "");
  return `Liste: <b>${tl(k.liste_fiyati)}</b>${iskStr} · Net maliyet: <b>${tl(k.net_maliyet)}</b> · Marj: <b style="color:${marjColor}">${k.marj_pct != null ? "%" + k.marj_pct : "—"}</b>${karStr}`;
}

// SEZON_UI_V1 ─────────────────────────────────────────────────────────
// Ikame maliyeti = liste - tesvik. Hangi tesvik kademesi uygulandi?
// Tesvik yoksa marj UYDURMUYORUZ — "tanimli degil" diyoruz.
function _tesvikHTML(k) {
  const t = k.tesvik;
  if (!t) return "";
  const SEZ = { KIS: "Kış", YAZ: "Yaz", "4MEVSIM": "4 Mevsim", TUM: "Tüm sezon" };
  const ARC = { BINEK: "Binek", SUV: "SUV", HAFIF_TICARI: "Hafif Ticari",
                KAMYON: "Kamyon/TBR", OTOBUS: "Otobüs", IS_MAKINESI: "İş Makinesi", TUM: "Tüm araçlar" };
  const urun = (SEZ[t.sezon] || t.sezon || "—") + " · " + (ARC[t.arac_tipi] || t.arac_tipi || "—");

  // ── BAYILIK_UI_V1: NET ALIM markasi (KRB bayisi degil) ────────────────
  //   Tesvik yok cunku tesvik KAVRAMI yok. Ikame maliyeti = son net alis.
  if (t.tedarik === "net_alim") {
    const n = t.net_alim;
    if (!n) {
      return `
        <div style="margin-top:5px;padding:5px 7px;background:#fef2f2;border-radius:5px;border-left:3px solid #dc2626">
          <div style="font-size:11px;color:#991b1b;font-weight:700">⚠ Bu ürünü hiç almamışız</div>
          <div style="font-size:11px;color:#7f1d1d;margin-top:2px">
            ${esc(k.marka || "")} bayilik markamız değil — net alım yapılır, teşvik yoktur.
            Ama bu kalemin <b>hiç alış faturası yok</b>, dolayısıyla ikame maliyeti bilinmiyor.
            Fiyat vermeden önce alış maliyetini teyit edin.
          </div>
        </div>`;
    }
    const tar = String(n.tarih || "").slice(0, 10).split("-").reverse().join(".");
    return `
      <div style="margin-top:5px;padding:5px 7px;background:${n.bayat ? "#fffbeb" : "#f0fdf4"};border-radius:5px;border-left:3px solid ${n.bayat ? "#f59e0b" : "#16a34a"}">
        <div style="font-size:11px;color:${n.bayat ? "#b45309" : "#15803d"};font-weight:700">
          ${n.bayat ? "⚠" : "✅"} Net alım · son alış <b>₺${Number(n.fiyat).toLocaleString("tr-TR")}</b>
        </div>
        <div style="font-size:11px;color:#64748b;margin-top:2px">
          ${esc(tar)} · ${n.gun_once} gün önce${n.tedarikci ? " · " + esc(n.tedarikci) : ""}${n.vade_gun != null ? " · " + n.vade_gun + " gün vade" : ""}<br>
          ${esc(k.marka || "")} bayilik markamız değil; net fiyata alınır, teşvik uygulanmaz.
          <b>İkame maliyeti = bu fiyat.</b>
          ${n.bayat ? `<br><span style="color:#b45309">Bu fiyat ${n.gun_once} günlük — güncel olmayabilir, marja temkinli bakın.</span>` : ""}
        </div>
      </div>`;
  }

  // ── BAYILIK_UI_V2: bayilik markasi, tesvik tablosu EKSIK, ama son alis VAR
  //   ⚠ Alis faturasindaki fiyat TESVIKLERI ZATEN ICINDE TASIR (Brisa'ya odenen
  //     net fiyat = liste - tesvik). Yani maliyet BILINIYOR; sadece biraz bayat.
  //     Marji gosteriyoruz AMA hangi temele bakildigini SOYLUYORUZ.
  if (t.tedarik === "bayilik" && t.ikame_kaynak === "son_alis" && t.net_alim) {
    const n = t.net_alim;
    const tar = String(n.tarih || "").slice(0, 10).split("-").reverse().join(".");
    return `
      <div style="margin-top:5px;padding:5px 7px;background:#fffbeb;border-radius:5px;border-left:3px solid #f59e0b">
        <div style="font-size:11px;color:#b45309;font-weight:700">
          ⚠ BRÜT maliyet — <b>₺${Number(n.fiyat).toLocaleString("tr-TR")}</b> · prim hariç
        </div>
        <div style="font-size:11px;color:#64748b;margin-top:2px">
          <b>Bu rakam ne:</b> ${esc(k.marka || "")} · ${esc(urun)} için teşvik tablosu
          henüz yüklenmedi. Bu maliyet, <b>KRB'nin kendi alış faturasından türetildi</b>
          (${esc(tar)} · ${n.gun_once} gün önce${n.tedarikci ? " · " + esc(n.tedarikci) : ""}).<br>
          <b>Bu rakam ne DEĞİL:</b> nihai maliyet. Brisa/Continental teşvik modeliyle
          çalışıyor; <b>primi KRB ayrıca fatura ediyor</b>, alış faturasına girmiyor.
          Bu yıl <b>33,5M TL prim hakedişi</b> kesilmiş. Yani gerçek maliyet
          <b>bundan düşük</b>.<br>
          <b>Sonuç:</b> aşağıdaki marj <b>gerçek marjın ALT SINIRIDIR</b> — gerçeği
          daha iyidir. Negatif görünmesi zarar demek değildir.
          ${n.bayat ? `<br><span style="color:#b45309">Ayrıca bu fiyat ${n.gun_once} günlük.</span>` : ""}
          <br><span style="color:#0369a1">Teşvik tablosu yüklendiğinde hesap otomatik olarak
          liste−teşvike (net maliyet) geçer ve bu uyarı kalkar.</span>
        </div>
      </div>`;
  }

  // ── Maliyet HIC BILINMIYOR -> marj gosterme, sebebini soyle ───────────
  if (t.ikame_kaynak === "yok" || !t.tanimli) {
    return `
      <div style="margin-top:5px;padding:5px 7px;background:#fef2f2;border-radius:5px;border-left:3px solid #dc2626">
        <div style="font-size:11px;color:#991b1b;font-weight:700">⚠ Maliyet bilinmiyor — ${esc(k.marka || "")}</div>
        <div style="font-size:11px;color:#7f1d1d;margin-top:2px">
          <b>${esc(urun)}</b> için ne teşvik tanımlı, ne de bu kalemin <b>alış faturası</b> var
          — yani bu ürünü hiç almamışız.<br>
          İkame maliyeti bilinmediği için <b>marj hesaplanamıyor</b>. Yanlış bir oran
          uydurmuyoruz; liste fiyatını maliyet saymak marjı olduğundan düşük gösterirdi.
          Fiyat vermeden önce alış maliyetini teyit edin.
        </div>
      </div>`;
  }

  // Tam eslesme degilse, hangi kademeye dusuldugunu SOYLE.
  const kademeNot = {
    tam_eslesme: null,
    sezon_genel: "Bu sezona özel teşvik yok; aynı araç tipinin genel oranı kullanıldı.",
    arac_genel:  "Bu araç tipine özel teşvik yok; aynı sezonun genel oranı kullanıldı.",
    genel:       "Ne sezona ne araç tipine özel teşvik var; markanın genel oranı kullanıldı."
  }[t.kademe];

  const es = t.eslesen || {};
  const eslesenStr = (SEZ[es.sezon] || es.sezon || "?") + " · " + (ARC[es.arac_tipi] || es.arac_tipi || "?");
  const tam = t.kademe === "tam_eslesme";

  return `
    <div style="margin-top:5px;padding:5px 7px;background:${tam ? "#f0fdf4" : "#fffbeb"};border-radius:5px;border-left:3px solid ${tam ? "#16a34a" : "#f59e0b"}">
      <div style="font-size:11px;color:${tam ? "#15803d" : "#b45309"};font-weight:700">
        ${tam ? "✅" : "⚠"} Teşvik: ${esc(eslesenStr)}${k.iskonto_pct != null ? ` · <b>%${k.iskonto_pct}</b> indirim` : ""}
      </div>
      <div style="font-size:11px;color:#64748b;margin-top:2px">
        Ürün: ${esc(urun)}${kademeNot ? `<br><span style="color:#b45309">${esc(kademeNot)}</span>` : ""}
      </div>
    </div>`;
}

// AYKIRI_UI_V1 ────────────────────────────────────────────────────────
// Araliktan cikarilan satislari GOSTER. Gizlemiyoruz — tiklayinca aciliyor.
// Aykiri kayitlari kalem bazinda saklariz; DOM'a JSON gommekten kacinmak icin.
window._AYKIRI_KAYIT = window._AYKIRI_KAYIT || {};

function _aykiriGoster(anahtar) {
  const d = window._AYKIRI_KAYIT[anahtar];
  if (!d || !d.liste || !d.liste.length) return;
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const tarih = t => t ? new Date(t).toLocaleDateString("tr-TR") : "—";
  const satirlar = d.liste.map(function (x) {
    return `
      <tr style="border-top:1px solid #f1f5f9">
        <td style="padding:6px 8px;font-size:12px"><b>${esc(x.musteri || "—")}</b></td>
        <td style="padding:6px 8px;font-size:12px;text-align:right;color:#dc2626;font-weight:700">${tl(x.fiyat)}</td>
        <td style="padding:6px 8px;font-size:12px;text-align:right">${x.adet != null ? x.adet : "—"}</td>
        <td style="padding:6px 8px;font-size:12px;color:#64748b">${tarih(x.tarih)}</td>
        <td style="padding:6px 8px;font-size:11px;color:#94a3b8">${esc(x.fatura_no || "—")}</td>
        <td style="padding:6px 8px;font-size:11px;color:#94a3b8">${esc(x.temsilci || "—")}</td>
      </tr>`;
  }).join("");
  modal(`
    <h3>⚠ Aralık dışında tutulan satışlar — ${esc(d.urun)}</h3>
    <div style="font-size:12px;color:#475569;margin-bottom:8px">
      Bu satışlar fiyat aralığı hesabına <b>dahil edilmedi</b>, çünkü birim fiyatları
      medyanın (<b>${tl(d.medyan)}</b>) %30'unun altında — yani <b>${tl(d.esik)}</b> altı.
      Genelde numune, garanti değişimi, iade düzeltmesi ya da giriş hatasıdır.
      <b>Silinmediler; sadece aralığı çarpıtmasınlar diye ayrıldılar.</b>
    </div>
    <div style="max-height:320px;overflow:auto;border:1px solid #e2e8f0;border-radius:6px">
      <table style="width:100%;border-collapse:collapse">
        <thead><tr style="background:#f8fafc">
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Müşteri</th>
          <th style="padding:6px 8px;text-align:right;font-size:11px;color:#64748b">Birim fiyat</th>
          <th style="padding:6px 8px;text-align:right;font-size:11px;color:#64748b">Adet</th>
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Tarih</th>
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Fatura</th>
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Temsilci</th>
        </tr></thead>
        <tbody>${satirlar}</tbody>
      </table>
    </div>
    <div style="margin-top:8px;font-size:11px;color:#94a3b8">
      Bir tanesi gerçek bir satışsa, fiyat politikası açısından ayrıca incelenmeli.
    </div>
  `);
}

// TEKLIF_UI_V2 ────────────────────────────────────────────────────────
// Teklifin SATIS VADESI. Temsilci girmediyse musterinin ERP'deki son odeme
// kosulunu gosteriyoruz — ama VARSAYILAN oldugunu acikca yaziyoruz. Uydurmuyoruz.
function _vadeHTML(v) {
  if (!v) return "";
  const varsayilan = v.kaynak !== "teklif";
  const gunStr = v.gun != null ? (v.gun === 0 ? "Peşin" : v.gun + " gün") : (v.tur || "—");
  return `
    <div style="padding:8px 10px;border-bottom:1px solid #f1f5f9;background:${varsayilan ? "#fffbeb" : "#f0fdf4"}">
      <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:3px">💳 Satış vadesi</div>
      <div style="font-size:13px;font-weight:700;color:${varsayilan ? "#b45309" : "#15803d"}">${esc(gunStr)}${v.tur && v.gun != null ? ` <span style="font-weight:400;color:#64748b">(${esc(v.tur)})</span>` : ""}</div>
      ${varsayilan ? `<div style="font-size:11px;color:#b45309;margin-top:2px">⚠ Temsilci vade girmemiş — müşterinin son faturasındaki koşul gösteriliyor.</div>` : ""}
    </div>`;
}

// KENDI SATIS GECMISIMIZ (bu yil): min / medyan / max + KIM aldi.
// Fatih: "min fiyata tiklayinca kim aldigini gorsun" -> tiklamaya gerek yok,
// isim zaten yaninda. Ayni lastigi kime kaca satmisiz, ekranda.
function _kendiSatisHTML(k) {
  const ks = k.kendi_satis;
  if (!ks) return `<div style="margin-top:3px;color:#94a3b8;font-style:italic;font-size:11px">Bu ürünü bu yıl hiç satmamışız.</div>`;
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const talep = k.talep_fiyat;

  // AYKIRI_UI_V1 — araliktan cikarilanlari GORUNUR yap (tiklanabilir).
  let aykiriHTML = "";
  if (ks.aykiri_sayisi > 0) {
    const anahtar = "ay_" + (k.kalem_sira || 0) + "_" + String(k.ebat || "").replace(/\W/g, "");
    window._AYKIRI_KAYIT[anahtar] = {
      urun: (k.marka || "") + " " + (k.ebat || ""),
      medyan: ks.medyan, esik: ks.aykiri_esigi, liste: ks.aykirilar || []
    };
    aykiriHTML = `
      <div style="margin-top:3px;font-size:11px;color:#b45309">
        ⚠ <b>${ks.aykiri_sayisi}</b> aykırı satış aralık dışında tutuldu
        <span style="color:#94a3b8">(medyanın %30'u = ${tl(ks.aykiri_esigi)} altı)</span>
        · <a href="#" onclick="event.preventDefault();_aykiriGoster('${anahtar}')"
             style="color:#2563eb;text-decoration:underline;font-weight:600">göster</a>
      </div>`;
  }
  // Talep, kendi medyanimizin NERESINDE? Karar icin en net sinyal bu.
  let konum = "";
  if (talep != null && ks.medyan != null) {
    const fark = Math.round((talep - ks.medyan) / ks.medyan * 100);
    const renk = fark < -15 ? "#dc2626" : fark < -5 ? "#f59e0b" : "#16a34a";
    const ok = fark < 0 ? "▼" : fark > 0 ? "▲" : "=";
    konum = `<span style="color:${renk};font-weight:700">${ok} medyandan %${Math.abs(fark)} ${fark < 0 ? "DÜŞÜK" : fark > 0 ? "yüksek" : ""}</span>`;
  }
  return `
    <div style="margin-top:5px;padding:5px 7px;background:#f8fafc;border-radius:5px;border-left:3px solid #6366f1">
      <div style="font-size:11px;color:#4338ca;font-weight:700;margin-bottom:2px">📗 Bu ürünü bu yıl kaça sattık (${ks.satis_adedi} satış)</div>
      <div style="font-size:12px;color:#0f172a">
        <b>${tl(ks.min)}</b> — <b>${tl(ks.medyan)}</b> — <b>${tl(ks.max)}</b> ${konum ? "· " + konum : ""}
      </div>
      <div style="font-size:11px;color:#64748b;margin-top:2px">
        En ucuz: <b>${esc(ks.en_ucuz.musteri || "—")}</b> (${tl(ks.en_ucuz.fiyat)})<br>
        En pahalı: <b>${esc(ks.en_pahali.musteri || "—")}</b> (${tl(ks.en_pahali.fiyat)})
      </div>
      ${aykiriHTML}
    </div>`;
}

// AGIRLIKLI VADELER + IKI MALIYET.
// ⚠ IKAME (liste-tesvik) = fiyatlama temeli: bu lastigi BUGUN yerine koyma bedeli.
//   BATIK (alis faturasi) = gecmiste odenen: gerceklesen marj raporu icin.
//   Ikisi ayrisiyorsa tedarikci zam yapmis demektir — onaylayan gormeli.
function _vadeMaliyetHTML(k) {
  const ag = k.agirlikli;
  if (!ag) return "";
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const gun = v => v != null ? Number(v) + " gün" : "—";
  const zam = ag.ikame_batik_fark_pct;
  const nakitUyari = (ag.alis_vade_gun != null && ag.satis_vade_gun != null && ag.satis_vade_gun > ag.alis_vade_gun)
    ? `<div style="font-size:11px;color:#dc2626;margin-top:2px">⚠ Tahsilat (${gun(ag.satis_vade_gun)}) ödemeden (${gun(ag.alis_vade_gun)}) UZUN — nakit akışı aleyhimize.</div>` : "";
  const zamUyari = (zam != null && zam > 5)
    ? `<div style="font-size:11px;color:#dc2626;margin-top:2px">⚠ İkame maliyeti geçmişte ödediğimizden <b>%${zam}</b> yüksek — tedarikçi zam yapmış. Eski ucuz maliyete göre indirim vermek YARINKİ marjı yer.</div>` : "";
  return `
    <div style="margin-top:5px;padding:5px 7px;background:#fefce8;border-radius:5px;border-left:3px solid #ca8a04">
      <div style="font-size:11px;color:#854d0e;font-weight:700;margin-bottom:2px">⏱ Vade & Maliyet (bu yıl, ağırlıklı)</div>
      <div style="font-size:11px;color:#0f172a">
        Alış: <b>${tl(ag.alis_fiyat)}</b> / <b>${gun(ag.alis_vade_gun)}</b> vade <span style="color:#94a3b8">(geçmişte ödenen)</span><br>
        Satış: ${ag.satis_fiyat != null ? `<b>${tl(ag.satis_fiyat)}</b> / ` : ""}<b>${gun(ag.satis_vade_gun)}</b> vade
      </div>
      ${nakitUyari}${zamUyari}
    </div>`;
}

function _teklifAnalizHTML(az) {
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const aralik = r => (r && r.en_dusuk != null) ? (tl(r.en_dusuk) + " – " + tl(r.en_yuksek)) : null;
  const lineNotes = (az.kalemler || []).filter(k => k.notlar)
    .map(k => `<div style="font-size:12px;color:#334155;margin-top:2px">• <b>${esc(k.marka || "")} ${esc(k.ebat || "")}</b>: ${esc(k.notlar)}</div>`).join("");
  const notlarHTML = (az.notlar || lineNotes)
    ? `${az.notlar ? `<div style="font-size:12px;color:#0f172a">${esc(az.notlar)}</div>` : ""}${lineNotes}`
    : `<div style="font-size:12px;color:#94a3b8;font-style:italic">Not girilmemiş.</div>`;
  const rr = az.rep_rakip || [];
  const headerR = az.header_rakip;
  const _nz = e => String(e || "").toLowerCase().replace(/\s/g, "");
  const _rrEbat = eb => rr.filter(x => x.ebat && _nz(x.ebat) === _nz(eb));
  const _rrTop = rr.filter(x => !x.ebat || !(az.kalemler || []).some(k => _nz(k.ebat) === _nz(x.ebat)));
  const _rivalStr = x => (x.marka || "Rakip") + (x.ebat ? (" " + x.ebat) : "") + (x.fiyat != null ? (" · " + tl(x.fiyat)) : " · fiyat yok") + (x.supheli ? " ⚠ şüpheli" : "");
  let repRakipHTML;
  if (_rrTop.length || headerR) {
    const items = [];
    if (headerR) items.push((headerR.marka || "Rakip") + (headerR.fiyat != null ? (" · " + tl(headerR.fiyat)) : ""));
    _rrTop.forEach(x => items.push(_rivalStr(x)));
    repRakipHTML = `<div style="font-size:12px;color:#0f172a">${items.map(esc).join("<br>")}</div>`;
  } else {
    repRakipHTML = `<div style="font-size:12px;color:#94a3b8;font-style:italic">Rakip bilgisi girilmemiş.</div>`;
  }
  const lineHTML = (az.kalemler || []).map(k => {
    const stokStr = k.mevcut_stok != null ? (k.mevcut_stok + " adet") : "—";
    const stokColor = (k.mevcut_stok != null && k.mevcut_stok <= 0) ? "#dc2626" : "#0f172a";
    const marjStr = k.marj_pct != null ? ("%" + k.marj_pct) : "—";
    const marjColor = (k.marj_pct != null && k.marj_pct < 10) ? "#dc2626" : (k.marj_pct != null && k.marj_pct < 20) ? "#f59e0b" : "#16a34a";
    const et = aralik(k.eticaret);
    const ma = aralik(k.marka_araligi);
    const sa = k.saha_teklifler;
    const hasRival = et || ma || (sa && sa.adet);
    return `
      <div style="border-top:1px solid #f1f5f9;padding:8px 10px;font-size:12px">
        <b style="color:#0f172a">${esc(k.marka || "")} ${esc(k.ebat || "")}</b>
        <div style="margin-top:3px;color:#475569">Stok: <b style="color:${stokColor}">${stokStr}</b>${k.talep_fiyat != null ? ` · İstenen: <b>${tl(k.talep_fiyat)}</b>` : ""}</div>
        <div style="margin-top:3px;color:#475569">${_marjHTML(k)}</div>
        ${_rrEbat(k.ebat).length ? `<div style="margin-top:3px;color:#b45309;font-weight:600">🏁 Temsilci: ${_rrEbat(k.ebat).map(_rivalStr).map(esc).join(" · ")}</div>` : ""}
        ${hasRival
          ? `<div style="margin-top:3px;color:#475569">${et ? `Piyasa (e-ticaret): <b>${et}</b>${k.eticaret.ilan ? ` <span style="color:#94a3b8">(${k.eticaret.ilan} ilan)</span>` : ""}<br>` : ""}${ma ? `Marka aralığı: <b>${ma}</b><br>` : ""}${(sa && sa.adet) ? `Saha teklifleri: <b>${aralik(sa)}</b> <span style="color:#94a3b8">(ort ${tl(sa.ortalama)}, ${sa.adet} kayıt${sa.son_tarih ? `, son ${new Date(sa.son_tarih).toLocaleDateString("tr-TR")}` : ""})</span>` : ""}</div>`
          : `<div style="margin-top:3px;color:#94a3b8;font-style:italic">Piyasa/e-ticaret verisi yok.</div>`}
        ${_tesvikHTML(k)}
        ${_kendiSatisHTML(k)}
        ${_vadeMaliyetHTML(k)}
      </div>`;
  }).join("");
  return `
    <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden">
      <div style="background:#eef2ff;padding:8px 10px;font-weight:700;font-size:12px;color:#3730a3">📊 Karar Bilgisi — Vade, Kendi Satışımız, Maliyet & Rakip</div>
      ${_vadeHTML(az.vade)}
      <div style="padding:8px 10px;border-bottom:1px solid #f1f5f9">
        <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:3px">🏁 Temsilcinin belirttiği rakip</div>
        ${repRakipHTML}
      </div>
      ${lineHTML}
      <div style="padding:8px 10px;border-top:1px solid #f1f5f9;background:#fafafa">
        <div style="font-weight:600;font-size:12px;color:#475569;margin-bottom:3px">📝 Notlar</div>
        ${notlarHTML}
      </div>
    </div>`;
}

function satirDet(label, val) {
  if (val == null || val === "") return "";
  return `<div style="color:#64748b">${esc(label)}</div><div style="font-weight:600;color:#0f172a">${esc(String(val))}</div>`;
}

async function teklifDuzenleModal(t) {
  if (Number(t.kalem_sayisi) > 1) {
    modal(`
      <h3>Teklif Düzenle — ${esc(t.firma)}</h3>
      <div class="bilgi-kutu" style="background:#fef3c7;border-color:#fde68a;color:#92400e">
        ⚠️ Bu teklif ${t.kalem_sayisi} kalem içeriyor. Çok kalemli tekliflerin toplu düzenlenmesi henüz desteklenmiyor.<br>
        Her kalemi ayrı teklif olarak onay akışına alın veya teklifi iptal edip yeniden oluşturun.
      </div>
      <div class="modal-btnlar"><button class="btn gri" data-kapat>Kapat</button></div>`);
    return;
  }
  const sec = await getSecenekler();
  modal(`
    <h3>Teklif Düzenle — ${esc(t.firma)}</h3>
    <div class="yanyana">
      <label>Marka *<input class="giris" id="te-marka" value="${esc(t.marka || "")}" list="te-markalar">
        <datalist id="te-markalar">${sec.markalar.map(m => `<option>${esc(m)}</option>`).join("")}</datalist>
      </label>
      <label>Model / Desen<input class="giris" id="te-model" value="${esc(t.model || "")}"></label>
    </div>
    <div class="yanyana">
      <label>Ebat<input class="giris" id="te-ebat" value="${esc(t.ebat || "")}"></label>
      <label>Adet<input type="number" class="giris" id="te-adet" value="${t.adet || 1}" min="1"></label>
    </div>
    <div class="yanyana">
      <label>Kategori<input class="giris" id="te-kategori" value="${esc(t.kategori || "")}" list="te-kategoriler">
        <datalist id="te-kategoriler">${sec.kategoriler.map(([v,l]) => `<option value="${esc(v)}">${esc(l)}</option>`).join("")}</datalist>
      </label>
      <label id="te-sezon-kutu">Sezon
        <select class="giris" id="te-sezon">
          ${secOpts(sec.sezonlar, t.sezon)}
        </select>
      </label>
    </div>
    <div style="margin:14px 0 6px;font-weight:600;font-size:13px;color:#475569;border-top:1px solid #e2e8f0;padding-top:12px">Fiyat</div>
    <div class="yanyana">
      <label>Liste Fiyatı
        <div style="padding:8px 12px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;font-size:14px;color:#475569;min-height:38px;display:flex;align-items:center">
          ${t.liste_fiyati != null ? `₺${Number(t.liste_fiyati).toLocaleString("tr-TR", { minimumFractionDigits: 2 })}` : "—"}
        </div>
      </label>
      <label>Ek İskonto (%)<input type="number" class="giris" id="te-ek-iskonto" value="${t.musteri_ek_iskonto_pct || ""}" min="0" max="100" step="0.1"></label>
    </div>
    <div id="te-hesap-goster" style="background:#f0f9ff;border:1px solid #bae6fd;border-radius:8px;padding:8px 12px;font-size:13px;color:#0c4a6e;margin-bottom:8px"></div>
    <label>Tedarikçi Destek (%)<input type="number" class="giris" id="te-destek" value="${t.tedarikci_destek_pct || ""}" min="0" max="100" step="0.1"></label>
    <label>Notlar<textarea class="giris" id="te-not" rows="2">${esc(t.notlar || "")}</textarea></label>
    <div class="modal-btnlar">
      <button class="btn gri" id="te-geri">← Geri</button>
      <button class="btn" id="te-kaydet">Değişiklikleri Kaydet</button>
    </div>`);

  // Show/hide sezon based on category
  const SEASONAL_KATEGORILER = ["BINEK", "TICARI", ""];
  function teSezonGoster(kat) {
    const s = !kat || SEASONAL_KATEGORILER.includes(kat.toUpperCase());
    document.getElementById("te-sezon-kutu").style.display = s ? "" : "none";
  }
  teSezonGoster(t.kategori || "");
  document.getElementById("te-kategori").addEventListener("input", ev => teSezonGoster(ev.target.value));

  // Live price computation
  const teListeFiyati = t.liste_fiyati != null ? Number(t.liste_fiyati) : null;
  function teUpdateHesap() {
    const el = document.getElementById("te-hesap-goster");
    if (!teListeFiyati) { el.textContent = "Liste fiyatı yok — satış fiyatı hesaplanamıyor."; el.style.color = "#94a3b8"; return; }
    const ek    = Number(document.getElementById("te-ek-iskonto").value || 0);
    const adet  = Number(document.getElementById("te-adet").value       || 1);
    const birim  = Math.round(teListeFiyati * (1 - ek / 100) * 100) / 100;
    const toplam = Math.round(birim * adet * 100) / 100;
    el.style.color = "#0c4a6e";
    el.innerHTML = `Satış Fiyatı: <b>₺${birim.toLocaleString("tr-TR", { minimumFractionDigits: 2 })}</b> &nbsp;·&nbsp; Toplam: <b>₺${toplam.toLocaleString("tr-TR", { minimumFractionDigits: 2 })}</b>`;
  }
  teUpdateHesap();
  document.getElementById("te-ek-iskonto").addEventListener("input", teUpdateHesap);
  document.getElementById("te-adet").addEventListener("input", teUpdateHesap);

  document.getElementById("te-geri").addEventListener("click", () => {
    kapatModal();
    teklifDetayModal(t);
  });

  document.getElementById("te-kaydet").addEventListener("click", async () => {
    const g    = id => document.getElementById(id).value.trim();
    const gNum = id => { const v = g(id); return v !== "" ? Number(v) : null; };
    if (!g("te-marka")) { uyari("Marka zorunlu."); return; }
    try {
      const { teklif } = await api(`/api/saha/teklifler/${t.id}`, {
        method: "PUT",
        body: JSON.stringify({
          marka       : g("te-marka")    || null,
          model       : g("te-model")    || null,
          ebat        : g("te-ebat")     || null,
          kategori    : g("te-kategori") || null,
          sezon       : g("te-sezon")    || null,
          adet        : gNum("te-adet"),
          // birim_fiyat is server-computed from liste_fiyati × (1 − ek_iskonto%)
          tedarikci_destek_pct  : gNum("te-destek"),
          musteri_ek_iskonto_pct: gNum("te-ek-iskonto"),
          notlar      : g("te-not")      || null
        })
      });
      kapatModal();
      uyari("✓ Teklif güncellendi.", true);
      // Refresh view and re-open detail with updated data
      await loadView("iskonto");
      const yeni = S.teklifler?.find(x => x.id === t.id) || teklif;
      teklifDetayModal(yeni);
    } catch (e) { uyari(e.message); }
  });
}

async function teklifFormModal(mus, ziyaretId) {
  const sec = await getSecenekler();
  modal(`
    <h3>Yeni Teklif — ${esc(mus.firma)}</h3>

    <!-- Eklenen kalemler listesi -->
    <div id="tf-kalemler-listesi" style="display:none;margin-bottom:12px">
      <div style="font-weight:600;font-size:13px;margin-bottom:6px;color:#475569;border-bottom:1px solid #e2e8f0;padding-bottom:6px">Teklif Kalemleri</div>
      <div id="tf-kalemler-satirlar"></div>
    </div>

    <!-- Ürün arama typeahead -->
    <label>Ürün Ara
      <div style="position:relative">
        <input class="giris" id="tf-urun-ara" placeholder="Kod, marka veya ürün adı…" autocomplete="off">
        <div id="tf-urun-sonuc" style="display:none;position:absolute;z-index:200;background:#fff;border:1px solid #e2e8f0;border-radius:8px;max-height:220px;overflow-y:auto;width:100%;top:calc(100% + 2px);box-shadow:0 4px 16px rgba(0,0,0,.12)"></div>
      </div>
    </label>
    <div id="tf-secilen-urun" style="display:none;background:#f0f9ff;border:1px solid #bae6fd;border-radius:8px;padding:8px 12px;margin-bottom:4px;font-size:13px;justify-content:space-between;align-items:center">
      <span id="tf-secilen-isim" style="flex:1;line-height:1.4"></span>
      <button type="button" id="tf-urun-kaldir" style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:18px;padding:0 4px;line-height:1" title="Seçimi kaldır">×</button>
    </div>
    <input type="hidden" id="tf-kalem-kodu">

    <!-- Ürün bilgileri -->
    <div class="yanyana">
      <label>Marka *<input class="giris" id="tf-marka" list="tf-markalar"><datalist id="tf-markalar">${sec.markalar.map(m => `<option>${esc(m)}</option>`).join("")}</datalist></label>
      <label>Model / Desen<input class="giris" id="tf-model" placeholder="WinterContact TS 860…"></label>
    </div>
    <div class="yanyana">
      <label>Ebat<input class="giris" id="tf-ebat" placeholder="205/55R16"></label>
      <label>Adet<input type="number" class="giris" id="tf-adet" value="4" min="1"></label>
    </div>
    <div class="yanyana">
      <label>Kategori<input class="giris" id="tf-kategori" list="tf-kategoriler" placeholder="BINEK, TBR…"><datalist id="tf-kategoriler">${sec.kategoriler.map(([v,l]) => `<option value="${esc(v)}">${esc(l)}</option>`).join("")}</datalist></label>
      <label id="tf-sezon-kutu">Sezon<select class="giris" id="tf-sezon">${secOpts(sec.sezonlar)}</select></label>
    </div>
    <label id="tf-altgrup-kutu" style="display:none">Ticari grup<select class="giris" id="tf-altgrup">${secOpts(sec.alt_gruplar)}</select></label>

    <!-- Fiyat & Teşvik bölümü -->
    <div style="margin:14px 0 6px;font-weight:600;font-size:13px;color:#475569;border-top:1px solid #e2e8f0;padding-top:12px">Fiyat & Teşvik</div>

    <div class="yanyana">
      <label style="flex:1">Talep Edilen Fiyat (₺/adet) *
        <input type="number" class="giris" id="tf-talep-fiyat" min="0" step="0.01" placeholder="Satmak istediğiniz birim fiyat" style="font-weight:600;border-color:#3182ce">
      </label>
      <label style="flex:1">Mevcut Stok
        <div id="tf-stok-goster" style="padding:8px 12px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;font-size:14px;color:#475569;min-height:38px;display:flex;align-items:center">—</div>
        <input type="hidden" id="tf-mevcut-stok">
      </label>
    </div>

    <div class="yanyana">
      <label>Liste Fiyatı
        <div id="tf-liste-fiyat-goster" style="padding:8px 12px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;font-size:14px;color:#475569;min-height:38px;display:flex;align-items:center">—</div>
        <input type="hidden" id="tf-liste-fiyati">
      </label>
      <label>Ek İskonto (%)
        <input type="number" class="giris" id="tf-ek-iskonto" min="0" max="100" step="0.1" placeholder="0.0">
      </label>
    </div>
    <div id="tf-hesap-goster" style="display:none;background:#f0f9ff;border:1px solid #bae6fd;border-radius:8px;padding:8px 12px;font-size:13px;color:#0c4a6e;margin-bottom:4px"></div>

    <!-- Tedarikçi Teşvik Sistemi (read-only, auto-fetched) -->
    <div id="tf-tesvik-kutu" style="display:none;margin-bottom:8px">
      <label style="margin-bottom:0">Tedarikçi Teşvik Sistemi
        <div id="tf-tesvik-bilgi" style="padding:8px 12px;background:#f0fdf4;border:1px solid #86efac;border-radius:8px;font-size:13px;color:#166534;line-height:1.6"></div>
      </label>
      <input type="hidden" id="tf-tesvik-garantili">
      <input type="hidden" id="tf-tesvik-maksimum">
    </div>

    <!-- Tedarikçi Destek İskontosu (per-customer, editable, can be made permanent) -->
    <div style="display:flex;gap:8px;align-items:flex-end;margin-bottom:0">
      <label style="flex:1;margin-bottom:0">Tedarikçi Destek İskontosu (%)
        <input type="number" class="giris" id="tf-destek-pct" min="0" max="100" step="0.1" placeholder="0.0" style="margin-bottom:0">
      </label>
      <button type="button" id="tf-destek-kaydet-btn" class="btn gri" style="white-space:nowrap;margin-bottom:1px;padding:8px 12px;font-size:13px">Kalıcı Kaydet</button>
    </div>
    <div id="tf-destek-bilgi" style="font-size:12px;color:#64748b;margin:4px 0 10px;min-height:16px"></div>

    <!-- Tedarikçi Kampanyası (auto-fetched, read-only info + hidden snapshot) -->
    <div id="tf-kampanya-kutu" style="display:none;margin-bottom:8px">
      <label style="margin-bottom:0">Tedarikçi Kampanyası
        <div id="tf-kampanya-bilgi" style="padding:8px 12px;background:#fefce8;border:1px solid #fde047;border-radius:8px;font-size:13px;color:#713f12;line-height:1.6"></div>
      </label>
      <input type="hidden" id="tf-kampanya-id">
      <input type="hidden" id="tf-kampanya-turu">
      <input type="hidden" id="tf-kampanya-deger">
    </div>

    <label>Satır Notu<textarea class="giris" id="tf-not" rows="2" placeholder="Bu kalem için not…"></textarea></label>
    <label>Genel Not<textarea class="giris" id="tf-genel-not" rows="2" placeholder="Teklif geneli için not…"></textarea></label>
    ${ziyaretId ? "" : `<label>Kaynak *<select class="giris" id="tf-kaynak"><option value="">— Nereden geldi? —</option><option value="TELEFON">📞 Telefon</option><option value="WHATSAPP">💬 WhatsApp</option><option value="EMAIL">✉️ E-posta</option><option value="DIGER">Diğer</option></select></label>`}
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn gri" id="tf-satir-ekle">＋ Satıra Ekle</button>
      <button class="btn" id="tf-kaydet">Teklifi Kaydet</button>
    </div>`);

  // ── Refs ──
  let araTimer;
  const araEl         = document.getElementById("tf-urun-ara");
  const sonucEl       = document.getElementById("tf-urun-sonuc");
  const secilenEl     = document.getElementById("tf-secilen-urun");
  const secilenIsimEl = document.getElementById("tf-secilen-isim");
  let _secilenUrun    = null; // last selected master_urun record
  let _kalemler       = [];   // accumulated product lines

  // ── Kalemler listesi render ──
  function renderKalemler() {
    const listesi = document.getElementById("tf-kalemler-listesi");
    const satirlar = document.getElementById("tf-kalemler-satirlar");
    if (!_kalemler.length) { listesi.style.display = "none"; return; }
    listesi.style.display = "";
    satirlar.innerHTML = _kalemler.map((k, i) => {
      const fiyatStr = k.birim_fiyat
        ? ` · ₺${Number(k.birim_fiyat).toLocaleString("tr-TR", {minimumFractionDigits:2})}/ad`
        : "";
      const toplamStr = k.toplam_tutar
        ? ` · <b>₺${Number(k.toplam_tutar).toLocaleString("tr-TR", {minimumFractionDigits:2})}</b>`
        : "";
      return `<div style="display:flex;justify-content:space-between;align-items:center;
                           padding:6px 10px;background:#f8fafc;border-radius:6px;margin-bottom:4px;font-size:13px">
        <span>${esc(k.marka)} ${esc(k.ebat||"")} ${esc(k.model||"")} · <b>${k.adet} adet</b>${fiyatStr}${toplamStr}</span>
        <button type="button" data-kalem-idx="${i}" style="background:none;border:none;color:#94a3b8;cursor:pointer;font-size:16px;padding:0 4px">×</button>
      </div>`;
    }).join("");
    satirlar.querySelectorAll("[data-kalem-idx]").forEach(btn => {
      btn.addEventListener("click", () => {
        _kalemler.splice(Number(btn.dataset.kalemIdx), 1);
        renderKalemler();
      });
    });
  }

  // ── Formdan kalem objesi oku ──
  function kalemdenOku() {
    const g    = id => document.getElementById(id).value.trim();
    const gNum = id => { const v = g(id); return v ? Number(v) : null; };
    const marka = g("tf-marka");
    if (!marka) return null;
    const talepFiyat  = gNum("tf-talep-fiyat");
    const listeFiyati = gNum("tf-liste-fiyati");
    const ekIsk       = gNum("tf-ek-iskonto") || 0;
    const adet        = Number(g("tf-adet")) || 1;
    const birim       = talepFiyat != null ? talepFiyat : (listeFiyati != null ? Math.round(listeFiyati * (1 - ekIsk / 100) * 100) / 100 : null);
    return {
      kalem_kodu            : g("tf-kalem-kodu")   || null,
      marka, model          : g("tf-model")         || null,
      ebat                  : g("tf-ebat")           || null,
      kategori              : g("tf-kategori")       || null,
      sezon                 : g("tf-sezon")          || null,
      alt_grup              : g("tf-kategori") === "TICARI" ? (g("tf-altgrup") || null) : null,
      adet, liste_fiyati    : listeFiyati,
      talep_fiyat           : talepFiyat,
      mevcut_stok           : gNum("tf-mevcut-stok"),
      birim_fiyat           : birim,
      toplam_tutar          : birim != null ? Math.round(birim * adet * 100) / 100 : null,
      musteri_ek_iskonto_pct: ekIsk > 0 ? ekIsk : null,
      tesvik_garantili_pct  : gNum("tf-tesvik-garantili"),
      tesvik_maksimum_pct   : gNum("tf-tesvik-maksimum"),
      tedarikci_destek_pct  : gNum("tf-destek-pct"),
      kampanya_id           : gNum("tf-kampanya-id"),
      kampanya_indirim_turu : g("tf-kampanya-turu") || null,
      kampanya_indirim_deger: gNum("tf-kampanya-deger"),
      notlar                : g("tf-not")           || null,
    };
  }

  // ── Form temizle (satır ekledikten sonra) ──
  function clearProductForm() {
    _secilenUrun = null;
    ["tf-kalem-kodu","tf-marka","tf-model","tf-ebat","tf-liste-fiyati","tf-talep-fiyat","tf-mevcut-stok",
     "tf-ek-iskonto","tf-tesvik-garantili","tf-tesvik-maksimum",
     "tf-destek-pct","tf-kampanya-id","tf-kampanya-turu","tf-kampanya-deger","tf-not"]
      .forEach(id => { const el = document.getElementById(id); if (el) el.value = ""; });
    document.getElementById("tf-adet").value = "4";
    document.getElementById("tf-liste-fiyat-goster").textContent = "—";
    document.getElementById("tf-liste-fiyat-goster").style.color = "#94a3b8";
    (function(){ var sg=document.getElementById("tf-stok-goster"); if(sg){sg.textContent="—";sg.style.color="#94a3b8";} })();
    document.getElementById("tf-tesvik-kutu").style.display = "none";
    document.getElementById("tf-kampanya-kutu").style.display = "none";
    document.getElementById("tf-hesap-goster").style.display = "none";
    document.getElementById("tf-destek-bilgi").textContent = "";
    secilenEl.style.display = "none";
    araEl.value = "";
    araEl.focus();
  }

  // ── Helper: fetch teşvik + destek + kampanya for current marka/kategori/ürün ──
  async function fetchPricingInfo(marka, kategori, kalemKodu, jantCapi) {
    if (!marka) return;
    // Parallel fetch — fire-and-forget style with independent error handling
    const [tesvikRes, destekRes, kampanyaRes] = await Promise.allSettled([
      api(`/api/saha/tesvik-bilgi?marka=${encodeURIComponent(marka)}&kategori=${encodeURIComponent(kategori || "")}`),
      api(`/api/saha/musteri-destek?musteri_id=${encodeURIComponent(mus.id)}&marka=${encodeURIComponent(marka)}`),
      api(`/api/saha/kampanya-ara?marka=${encodeURIComponent(marka)}&kalem_kodu=${encodeURIComponent(kalemKodu || "")}&kategori=${encodeURIComponent(kategori || "")}&jant_capi=${encodeURIComponent(jantCapi || "")}`)
    ]);

    // Teşvik
    const tesvikKutu = document.getElementById("tf-tesvik-kutu");
    if (tesvikRes.status === "fulfilled" && tesvikRes.value.tesvik) {
      const t = tesvikRes.value.tesvik;
      document.getElementById("tf-tesvik-garantili").value = t.garantili_pct ?? "";
      document.getElementById("tf-tesvik-maksimum").value  = t.maksimum_pct ?? "";
      let html = "";
      if (t.garantili_pct != null) html += `<b>Garantili:</b> %${t.garantili_pct}`;
      if (t.maksimum_pct  != null) html += `  ·  <b>Maks.:</b> %${t.maksimum_pct}`;
      if (t.detay) {
        const parts = [
          t.detay.fatura_alti   ? `Fatura altı %${t.detay.fatura_alti}` : null,
          t.detay.donem_primi   ? `Dönem primi %${t.detay.donem_primi}` : null,
          t.detay.sellout_primi ? `Sell-out %${t.detay.sellout_primi}` : null,
          t.detay.kesin_siparis ? `Kesin sipariş %${t.detay.kesin_siparis}` : null,
        ].filter(Boolean);
        if (parts.length) html += `<br><span style="opacity:.8">${parts.join("  ·  ")}</span>`;
      }
      if (t.notlar) html += `<br><span style="opacity:.7;font-style:italic">${esc(t.notlar)}</span>`;
      document.getElementById("tf-tesvik-bilgi").innerHTML = html;
      tesvikKutu.style.display = "";
    } else {
      tesvikKutu.style.display = "none";
    }

    // Tedarikçi Destek
    const destekBilgi = document.getElementById("tf-destek-bilgi");
    if (destekRes.status === "fulfilled" && destekRes.value.destek) {
      const d = destekRes.value.destek;
      document.getElementById("tf-destek-pct").value = d.destek_pct ?? "";
      document.getElementById("tf-destek-pct").dataset.destekId = d.id;
      const tarih = d.guncelleme_tarihi ? new Date(d.guncelleme_tarihi).toLocaleDateString("tr-TR") : "";
      destekBilgi.textContent = `Kalıcı kayıt: %${d.destek_pct}${tarih ? " · " + tarih : ""}${d.olusturan_kullanici ? " · " + d.olusturan_kullanici : ""}`;
    } else {
      document.getElementById("tf-destek-pct").value = "";
      document.getElementById("tf-destek-pct").dataset.destekId = "";
      destekBilgi.textContent = "Bu müşteri için kayıtlı destek yok.";
    }

    // Kampanya
    const kampanyaKutu = document.getElementById("tf-kampanya-kutu");
    if (kampanyaRes.status === "fulfilled" && kampanyaRes.value.kampanyalar?.length) {
      const ks = kampanyaRes.value.kampanyalar;
      // Prefer the most specific (first in the ordered list)
      const best = ks[0];
      document.getElementById("tf-kampanya-id").value    = best.id;
      document.getElementById("tf-kampanya-turu").value  = best.indirim_turu;
      document.getElementById("tf-kampanya-deger").value = best.indirim_deger;
      const degerStr = best.indirim_turu === "PCT"
        ? `%${best.indirim_deger} indirim`
        : `₺${Number(best.indirim_deger).toLocaleString("tr-TR")} destek`;
      let html = `<b>${esc(best.kampanya_adi)}</b>  ·  ${degerStr}`;
      if (best.kapsam_turu !== "GENEL") html += `  ·  Kapsam: ${esc(best.kapsam_deger || "")}`;
      if (best.bitis_tarihi) html += `  ·  Bitiş: ${new Date(best.bitis_tarihi).toLocaleDateString("tr-TR")}`;
      if (best.aciklama)    html += `<br><span style="opacity:.8">${esc(best.aciklama)}</span>`;
      if (ks.length > 1)    html += `<br><span style="opacity:.7">${ks.length - 1} ek kampanya mevcut.</span>`;
      document.getElementById("tf-kampanya-bilgi").innerHTML = html;
      kampanyaKutu.style.display = "";
    } else {
      document.getElementById("tf-kampanya-id").value    = "";
      document.getElementById("tf-kampanya-turu").value  = "";
      document.getElementById("tf-kampanya-deger").value = "";
      kampanyaKutu.style.display = "none";
    }
  }

  // ── Ürün seçimi: tüm alanları doldur + fiyat bilgisini getir ──
  function urunSec(u) {
    _secilenUrun = u;
    document.getElementById("tf-kalem-kodu").value = u.kalem_kodu || "";
    document.getElementById("tf-marka").value      = u.marka || "";
    document.getElementById("tf-model").value      = u.kalem_tanimi || "";
    document.getElementById("tf-ebat").value       = u.ebat_norm || "";

    // Liste fiyatı (read-only display)
    const lfEl = document.getElementById("tf-liste-fiyat-goster");
    if (u.liste_fiyati) {
      lfEl.textContent = `₺${Number(u.liste_fiyati).toLocaleString("tr-TR", { minimumFractionDigits: 2 })}`;
      lfEl.style.color = "#0f172a";
      document.getElementById("tf-liste-fiyati").value = u.liste_fiyati;
    } else {
      lfEl.textContent = "—";
      lfEl.style.color = "#94a3b8";
      document.getElementById("tf-liste-fiyati").value = "";
    }
    updateHesap();

    // Kategori: auto-fill from master_urun (free-text with datalist)
    if (u.kategori) {
      document.getElementById("tf-kategori").value = u.kategori;
      document.getElementById("tf-altgrup-kutu").style.display = u.kategori === "TICARI" ? "" : "none";
      updateSezonVisibility(u.kategori);
    }

    // Sezon: auto-detect from product name (only if seasonal category)
    const nm = (u.kalem_tanimi || "").toLowerCase();
    const sezonEl = document.getElementById("tf-sezon");
    const isSeasonalKat = !u.kategori || SEASONAL_KATEGORILER.includes((u.kategori || "").toUpperCase());
    if (isSeasonalKat) {
      if      (/kı[sş]|winter/.test(nm))              sezonEl.value = "KIS";
      else if (/\byaz\b|summer/.test(nm))              sezonEl.value = "YAZ";
      else if (/mevsim|season|quattro|4s\b/.test(nm)) sezonEl.value = "4MEV";
    }

    // Selection chip
    const fiyatStr = u.liste_fiyati ? ` · Liste: ₺${Number(u.liste_fiyati).toLocaleString("tr-TR")}` : "";
    const kodStr   = u.eslesme_durumu === "KOD" ? " ✓" : "";
    secilenIsimEl.textContent = `${u.kalem_kodu}  ${u.marka || ""} ${u.ebat_norm || ""}  ${u.kalem_tanimi || ""}${fiyatStr}${kodStr}`;
    secilenEl.style.display = "flex";
    araEl.value = "";
    sonucEl.style.display = "none";

    // Fetch teşvik + destek + kampanya
    const jantCapi = u.jant_capi || (u.ebat_norm ? (u.ebat_norm.match(/R(\d{2})/i) || [])[1] : null);
    fetchPricingInfo(u.marka, u.kategori, u.kalem_kodu, jantCapi).catch(() => {});

    // Mevcut stok — bi_stok_durumu, kalem_kodu ile (TEKLIF_TALEP_STOK_V1)
    (function(){
      var sg = document.getElementById("tf-stok-goster"), sh = document.getElementById("tf-mevcut-stok");
      if (sh) sh.value = "";
      if (!u.kalem_kodu) { if (sg) { sg.textContent = "—"; sg.style.color = "#94a3b8"; } return; }
      if (sg) { sg.textContent = "…"; sg.style.color = "#94a3b8"; }
      api("/api/saha/stok-durumu?kalem_kodu=" + encodeURIComponent(u.kalem_kodu)).then(function(r){
        var adet = r && r.eldeki_miktar != null ? Number(r.eldeki_miktar) : null;
        if (adet != null) {
          if (sg) { sg.textContent = adet.toLocaleString("tr-TR") + " adet"; sg.style.color = adet > 0 ? "#166534" : "#dc2626"; }
          if (sh) sh.value = adet;
        } else if (sg) { sg.textContent = "Stok bilgisi yok"; sg.style.color = "#94a3b8"; }
      }).catch(function(){ if (sg) { sg.textContent = "—"; sg.style.color = "#94a3b8"; } });
    })();
  }

  // ── Typeahead ──
  araEl.addEventListener("input", () => {
    clearTimeout(araTimer);
    const q = araEl.value.trim();
    if (q.length < 2) { sonucEl.style.display = "none"; return; }
    araTimer = setTimeout(async () => {
      try {
        const { urunler } = await api(`/api/saha/urun-ara?q=${encodeURIComponent(q)}`);
        if (!urunler || !urunler.length) {
          sonucEl.innerHTML = `<div style="padding:10px 14px;color:#94a3b8;font-size:13px">Ürün bulunamadı.</div>`;
        } else {
          sonucEl.innerHTML = urunler.map(u => `
            <div data-kalem="${esc(u.kalem_kodu)}"
                 style="padding:10px 14px;cursor:pointer;border-bottom:1px solid #f1f5f9;transition:background .15s"
                 onmouseover="this.style.background='#f8fafc'" onmouseout="this.style.background=''"
                 onmousedown="event.preventDefault()">
              <div style="font-weight:600;font-size:13px">${esc(u.marka || "")} — ${esc(u.kalem_tanimi || "")}</div>
              <div style="font-size:12px;color:#64748b;margin-top:2px">
                ${u.ebat_norm ? `<b>${esc(u.ebat_norm)}</b>` : ""}
                ${u.liste_fiyati ? ` · ₺${Number(u.liste_fiyati).toLocaleString("tr-TR")}` : ""}
                ${u.eslesme_durumu === "KOD" ? ` <span style="color:#10b981;font-weight:600">✓ fiyatlı</span>` : ""}
                · ${esc(u.kalem_kodu)}
              </div>
            </div>`).join("");
          sonucEl.querySelectorAll("[data-kalem]").forEach(el => {
            el.addEventListener("mousedown", () => {
              const u = urunler.find(x => x.kalem_kodu === el.dataset.kalem);
              if (u) urunSec(u);
            });
          });
        }
        sonucEl.style.display = "block";
      } catch (_) { /* sessiz hata */ }
    }, 280);
  });

  araEl.addEventListener("blur", () => setTimeout(() => { sonucEl.style.display = "none"; }, 160));

  // ── Hesap göster: liste × (1 − ek%) × adet ──
  function updateHesap() {
    const liste = Number(document.getElementById("tf-liste-fiyati").value || 0);
    const ek    = Number(document.getElementById("tf-ek-iskonto").value  || 0);
    const adet  = Number(document.getElementById("tf-adet").value         || 1);
    const el    = document.getElementById("tf-hesap-goster");
    if (!liste) { el.style.display = "none"; return; }
    const birim  = Math.round(liste * (1 - ek / 100) * 100) / 100;
    const toplam = Math.round(birim * adet * 100) / 100;
    el.style.display = "";
    let onayHint = "";
    if (S.role === "rep" && S.ayarlar && ek > 0) {
      if (ek <= S.ayarlar.oto_onay_max)      onayHint = ` &nbsp;<span style="color:#16a34a;font-size:11px">✓ Oto-onay</span>`;
      else if (ek <= S.ayarlar.mudur_max)    onayHint = ` &nbsp;<span style="color:#f59e0b;font-size:11px">→ Müdür onayına gidecek</span>`;
      else                                   onayHint = ` &nbsp;<span style="color:#ef4444;font-size:11px">→ GM onayına gidecek</span>`;
    }
    el.innerHTML = `Satış Fiyatı: <b>₺${birim.toLocaleString("tr-TR", { minimumFractionDigits: 2 })}</b> &nbsp;·&nbsp; Toplam: <b>₺${toplam.toLocaleString("tr-TR", { minimumFractionDigits: 2 })}</b>${onayHint}`;
  }
  document.getElementById("tf-ek-iskonto").addEventListener("input", updateHesap);
  document.getElementById("tf-adet").addEventListener("input", updateHesap);

  document.getElementById("tf-urun-kaldir").addEventListener("click", () => {
    _secilenUrun = null;
    document.getElementById("tf-kalem-kodu").value = "";
    document.getElementById("tf-liste-fiyati").value = "";
    document.getElementById("tf-liste-fiyat-goster").textContent = "—";
    document.getElementById("tf-liste-fiyat-goster").style.color = "#94a3b8";
    (function(){ var sg=document.getElementById("tf-stok-goster"); if(sg){sg.textContent="—";sg.style.color="#94a3b8";} })();
    document.getElementById("tf-tesvik-kutu").style.display = "none";
    document.getElementById("tf-kampanya-kutu").style.display = "none";
    document.getElementById("tf-destek-bilgi").textContent = "";
    document.getElementById("tf-destek-pct").value = "";
    secilenEl.style.display = "none";
    araEl.focus();
  });

  // ── Sezon: hide for non-seasonal categories (TBR, TARIM, etc.) ──
  const SEASONAL_KATEGORILER = ["BINEK", "TICARI", ""];
  function updateSezonVisibility(kat) {
    const seasonal = !kat || SEASONAL_KATEGORILER.includes(kat.toUpperCase());
    document.getElementById("tf-sezon-kutu").style.display = seasonal ? "" : "none";
    if (!seasonal) document.getElementById("tf-sezon").value = "";
  }

  // ── Kategori change: show/hide alt_grup + sezon + re-fetch tesvik ──
  document.getElementById("tf-kategori").addEventListener("change", ev => {
    const kat = ev.target.value;
    document.getElementById("tf-altgrup-kutu").style.display = kat === "TICARI" ? "" : "none";
    updateSezonVisibility(kat);
    const marka = document.getElementById("tf-marka").value.trim();
    if (marka) {
      const kalemKodu = document.getElementById("tf-kalem-kodu").value;
      const ebat = document.getElementById("tf-ebat").value;
      const jantCapi = ebat ? (ebat.match(/R(\d{2})/i) || [])[1] : null;
      fetchPricingInfo(marka, kat, kalemKodu, jantCapi).catch(() => {});
    }
  });

  // ── Kalıcı Destek Kaydet ──
  document.getElementById("tf-destek-kaydet-btn").addEventListener("click", async () => {
    const marka = document.getElementById("tf-marka").value.trim();
    const pctStr = document.getElementById("tf-destek-pct").value.trim();
    if (!marka)   { uyari("Önce marka seçin."); return; }
    if (!pctStr)  { uyari("Destek oranı girin."); return; }
    const pct = Number(pctStr);
    if (isNaN(pct) || pct < 0 || pct > 100) { uyari("Geçersiz oran — 0 ile 100 arasında olmalı."); return; }
    try {
      const res = await api("/api/saha/musteri-destek", {
        method: "POST",
        body: JSON.stringify({ musteri_id: mus.id, marka, destek_pct: pct })
      });
      const d = res.destek;
      const tarih = d.guncelleme_tarihi ? new Date(d.guncelleme_tarihi).toLocaleDateString("tr-TR") : "";
      document.getElementById("tf-destek-bilgi").textContent = `✓ Kalıcı kaydedildi: %${d.destek_pct}  ·  ${tarih}`;
      document.getElementById("tf-destek-pct").dataset.destekId = d.id;
    } catch (e) { uyari(e.message); }
  });

  // ── Satıra Ekle ──
  document.getElementById("tf-satir-ekle").addEventListener("click", () => {
    const k = kalemdenOku();
    if (!k) { uyari("Marka zorunlu."); return; }
    _kalemler.push(k);
    renderKalemler();
    clearProductForm();
  });

  // ── Teklifi Kaydet ──
  document.getElementById("tf-kaydet").addEventListener("click", async () => {
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
          kalemler  : allKalemler
        })
      });
      kapatModal();
      uyari("✓ Teklif kaydedildi.", true);
      if (S.view === "iskonto") loadView("iskonto");
    } catch (e) { uyari(e.message); }
  });
}

async function teklifSonucModal(t, tip) {
  if (tip === "KAZANILDI") {
    const teklifOzet = Number(t.kalem_sayisi) > 1 ? `${t.kalem_sayisi} kalem` : (t.marka || "");
    if (!confirm(`"${t.firma}${teklifOzet ? " — " + teklifOzet : ""}" teklifi KAZANILDI olarak işaretlensin mi?`)) return;
    try {
      await api(`/api/saha/teklifler/${t.id}`, {
        method: "PUT", body: JSON.stringify({ action: "sonuc", durum: "KAZANILDI" })
      });
      uyari("✓ Tebrikler — kazanıldı olarak kaydedildi.", true);
      loadView("iskonto");
    } catch (e) { uyari(e.message); }
    return;
  }
  const sec = await getSecenekler();
  modal(`
    <h3>Kaybedilen Teklif — ${esc(t.firma)}</h3>
    <p class="mini-durum">${esc(t.marka)}${t.model ? " " + esc(t.model) : ""} · ${t.adet} adet — hangi rakibe kaybedildi?</p>
    <div class="yanyana">
      <label>Rakip marka *<input class="giris" id="ts-rmarka" list="ts-markalar"><datalist id="ts-markalar">${[...new Set([...sec.markalar, ...MARKALAR])].map(m => `<option>${esc(m)}</option>`).join("")}</datalist></label>
      <label>Rakip model<input class="giris" id="ts-rmodel"></label>
    </div>
    <div class="yanyana">
      <label>Rakip fiyat (₺)<input type="number" class="giris" id="ts-rfiyat" min="0" step="0.01"></label>
      <label>Kayıp nedeni
        <select class="giris" id="ts-neden">
          <option value="FIYAT">Fiyat</option><option value="VADE">Vade</option>
          <option value="STOK">Stok</option><option value="ILISKI">İlişki</option>
          <option value="DIGER">Diğer</option>
        </select></label>
    </div>
    <label>Not<textarea class="giris" id="ts-not" rows="2"></textarea></label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn kirmizi-btn" id="ts-kaydet">Kaybedildi Olarak Kaydet</button>
    </div>`);
  document.getElementById("ts-kaydet").addEventListener("click", async () => {
    const g = id => document.getElementById(id).value.trim();
    if (!g("ts-rmarka")) { uyari("Rakip marka zorunlu."); return; }
    try {
      await api(`/api/saha/teklifler/${t.id}`, {
        method: "PUT",
        body: JSON.stringify({
          action: "sonuc", durum: "KAYBEDILDI",
          rakip_marka: g("ts-rmarka"), rakip_model: g("ts-rmodel") || null,
          rakip_fiyat: g("ts-rfiyat") ? Number(g("ts-rfiyat")) : null,
          kayip_nedeni: g("ts-neden"), not: null, notlar: g("ts-not") || null
        })
      });
      kapatModal();
      uyari("Kayıp kaydedildi — rakip analizine eklendi.", true);
      loadView("iskonto");
    } catch (e) { uyari(e.message); }
  });
}

function talepKart(t, onayModu) {
  const [dl, dc] = ISK_DURUM[t.durum] || [t.durum, "#999"];
  const yonetici = S.role !== "rep";
  const gmBekliyor = t.durum === "BEKLIYOR_GM";
  const onayYetkisi = S.role === "admin" || (S.role === "manager" && !gmBekliyor);
  return `
  <div class="kart" id="kayit-${t.id}">
    <div class="kart-ust">
      <b>${esc(t.firma)} — %${Number(t.istenen_oran)}</b>
      <span class="rozet" style="background:${dc}">${dl}</span>
    </div>
    <div class="kart-alt">
      ${[t.marka, t.ebat, t.urun_grubu,
         KURAL_ETIKET.kategori[t.kategori], KURAL_ETIKET.sezon[t.sezon], t.jant_grubu,
         KURAL_ETIKET.alt_grup[t.alt_grup]].filter(Boolean).map(x => `<span>${esc(x)}</span>`).join("")}
      ${t.liste_fiyat ? `<span>Liste: ${Number(t.liste_fiyat).toLocaleString("tr-TR")}₺</span>` : ""}
      ${yonetici ? `<span>👤 ${esc(t.rep_full_name || "")}</span>` : ""}
      <span>${new Date(t.created_at).toLocaleDateString("tr-TR")}</span>
      ${t.kaynak ? `<span>${KAYNAK_ETK[t.kaynak] || t.kaynak}</span>` : ""}
    </div>
    ${yonetici && (t.bakiye != null || t.toplam_ciro != null) ? `
      <div class="bakiye-satir">
        ${t.bakiye != null ? `Bakiye: <b>${Number(t.bakiye).toLocaleString("tr-TR")}₺</b>` : ""}
        ${Number(t.vadesi_gecmis_tutar) > 0 ? ` · <span class="kirmizi">Vadesi geçmiş: ${Number(t.vadesi_gecmis_tutar).toLocaleString("tr-TR")}₺</span>` : ""}
        ${t.toplam_ciro != null ? ` · Ciro: <b>${Math.round(Number(t.toplam_ciro) / 1000).toLocaleString("tr-TR")}K₺</b> (${t.fatura_sayisi} fatura)` : ""}
        ${t.ort_gecikme_gun != null ? ` · Ort. gecikme: <b>${Number(t.ort_gecikme_gun) > 15 ? `<span class="kirmizi">${t.ort_gecikme_gun} gün</span>` : t.ort_gecikme_gun + " gün"}</b>` : ""}
        ${t.son_fatura ? ` · Son alım: ${new Date(t.son_fatura).toLocaleDateString("tr-TR")}` : ""}
      </div>
      ${Array.isArray(t.marka_kirilimi) && t.marka_kirilimi.length ? `
      <div class="bakiye-satir" style="opacity:.85">Aldığı markalar: ${t.marka_kirilimi.slice(0, 4).map(m => `${esc(m.marka)} ${Math.round(m.ciro / 1000)}K`).join(" · ")}</div>` : ""}` : ""}
    ${t.gerekce ? `<div class="kart-not">${esc(t.gerekce)}</div>` : ""}
    ${t.karar_notu ? `<div class="kart-not">Karar: ${esc(t.karar_notu)} — ${esc(t.karar_veren_adi || "")}</div>` : ""}
    ${onayModu && onayYetkisi ? `
      <div class="kart-btnlar">
        <button class="btn kucuk" data-karar="${t.id}|ONAY">✓ Onayla</button>
        <button class="btn kucuk kirmizi-btn" data-karar="${t.id}|RED">✕ Reddet</button>
      </div>` : ""}
  </div>`;
}

async function getSecenekler() {
  if (!S.secenekler) {
    try { S.secenekler = await api("/api/saha/iskonto-secenekler"); }
    catch {
      S.secenekler = { markalar: MARKALAR, kategoriler: [["BINEK","Binek"],["TICARI","Ticari"]],
        sezonlar: [["YAZ","Yaz"],["KIS","Kış"],["4MEV","4 Mevsim"]],
        jant_gruplari: [["13-16",'13"–16"'],["17+",'17" ve üzeri']],
        alt_gruplar: [["UZUN_YOL","Uzun Yol"],["HAFRIYAT","Hafriyat"],["YOL_DISI","Yol Dışı"]] };
    }
  }
  return S.secenekler;
}
function secOpts(liste, secili = null, bosEtiket = "Seçin…") {
  return `<option value="">${bosEtiket}</option>` +
    liste.map(([v, l]) => `<option value="${v}"${v === secili ? " selected" : ""}>${l}</option>`).join("");
}

async function iskontoFormModal(mus, ziyaretId) {
  const sec = await getSecenekler();
  modal(`
    <h3>İskonto Talebi — ${esc(mus.firma)}</h3>
    <div class="yanyana">
      <label>Marka<input class="giris" id="if-marka" list="if-markalar"><datalist id="if-markalar">${sec.markalar.map(m => `<option>${esc(m)}</option>`).join("")}</datalist></label>
      <label>Kategori<select class="giris" id="if-kategori">${secOpts(sec.kategoriler)}</select></label>
    </div>
    <div class="yanyana">
      <label>Sezon<select class="giris" id="if-sezon">${secOpts(sec.sezonlar)}</select></label>
      <label>Ebat<input class="giris" id="if-ebat" placeholder="205/55R16"></label>
    </div>
    <div class="yanyana">
      <label>Jant grubu<select class="giris" id="if-jant">${secOpts(sec.jant_gruplari, "Ebattan otomatik")}</select></label>
      <label id="if-altgrup-kutu" style="display:none">Ticari grup<select class="giris" id="if-altgrup">${secOpts(sec.alt_gruplar)}</select></label>
    </div>
    <div class="yanyana">
      <label>Liste fiyat (₺)<input type="number" class="giris" id="if-liste" min="0" step="0.01"></label>
      <label>İstenen iskonto (%)<input type="number" class="giris" id="if-oran" min="0.1" max="100" step="0.1"></label>
    </div>
    <label>Gerekçe<textarea class="giris" id="if-gerekce" rows="2" placeholder="Rakip teklifi, hacim taahhüdü…"></textarea></label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="if-gonder">Gönder</button>
    </div>`);
  // Ticari seçilince alt grup göster; ebat yazılınca jant grubunu otomatik doldur
  document.getElementById("if-kategori").addEventListener("change", ev => {
    document.getElementById("if-altgrup-kutu").style.display = ev.target.value === "TICARI" ? "" : "none";
  });
  document.getElementById("if-ebat").addEventListener("input", ev => {
    const jm = ev.target.value.match(/R\s*(\d{2}(?:\.\d)?)/i);
    if (jm) document.getElementById("if-jant").value = Number(jm[1]) >= 17 ? "17+" : "13-16";
  });
  document.getElementById("if-gonder").addEventListener("click", async () => {
    const g = id => document.getElementById(id).value.trim();
    if (!g("if-oran")) { uyari("İskonto oranı zorunlu."); return; }
    try {
      const { talep, uygulanan_esik } = await api("/api/saha/iskonto", {
        method: "POST",
        body: JSON.stringify({
          musteri_id: mus.id, ziyaret_id: ziyaretId,
          marka: g("if-marka") || null, ebat: g("if-ebat") || null,
          kategori: g("if-kategori") || null, sezon: g("if-sezon") || null,
          jant_grubu: g("if-jant") || null,
          alt_grup: g("if-kategori") === "TICARI" ? (g("if-altgrup") || null) : null,
          liste_fiyat: g("if-liste") ? Number(g("if-liste")) : null,
          istenen_oran: Number(g("if-oran")), gerekce: g("if-gerekce") || null
        })
      });
      kapatModal();
      const kaynakNot = uygulanan_esik?.kural_id ? " (kategori kuralı)" : " (genel eşik)";
      uyari(talep.durum === "ONAYLANDI" ? `✓ Otomatik onaylandı${kaynakNot}.` :
        talep.durum === "BEKLIYOR_MUDUR" ? `Talep müdür onayına gönderildi${kaynakNot}.` : `Talep GM onayına gönderildi${kaynakNot}.`, true);
      if (S.view === "iskonto") loadView("iskonto");
    } catch (e) { uyari(e.message); }
  });
}

const KURAL_ETIKET = {
  kategori: { BINEK: "Binek", TICARI: "Ticari" },
  sezon: { YAZ: "Yaz", KIS: "Kış", "4MEV": "4 Mevsim" },
  alt_grup: { UZUN_YOL: "Uzun Yol", HAFRIYAT: "Hafriyat", YOL_DISI: "Yol Dışı" }
};
function kuralOzet(k) {
  const parca = [
    k.marka, KURAL_ETIKET.kategori[k.kategori], KURAL_ETIKET.sezon[k.sezon],
    k.jant_grubu, KURAL_ETIKET.alt_grup[k.alt_grup]
  ].filter(Boolean);
  return parca.length ? parca.join(" · ") : "Genel (tüm ürünler)";
}

async function esikModal() {
  const sec = await getSecenekler();
  modal(`
    <h3>İskonto Eşikleri & Kuralları</h3>
    <h4 class="bolum-baslik">Genel eşikler (kural eşleşmezse)</h4>
    <div class="yanyana">
      <label>Oto-onay ≤ (%)<input type="number" class="giris" id="es-oto" value="${S.ayarlar.oto_onay_max}" step="0.5" min="0"></label>
      <label>Müdür ≤ (%)<input type="number" class="giris" id="es-mudur" value="${S.ayarlar.mudur_max}" step="0.5" min="0"></label>
    </div>
    <button class="btn kucuk" id="es-kaydet">Genel Eşikleri Kaydet</button>
    <h4 class="bolum-baslik">Kategori kuralları (en spesifik kazanır)</h4>
    <div id="kural-liste"><div class="saha-load">Yükleniyor…</div></div>
    <h4 class="bolum-baslik">Yeni kural</h4>
    <div class="yanyana">
      <label>Marka<input class="giris" id="kr-marka" list="kr-markalar" placeholder="Hepsi"><datalist id="kr-markalar">${sec.markalar.map(m => `<option>${esc(m)}</option>`).join("")}</datalist></label>
      <label>Kategori<select class="giris" id="kr-kategori">${secOpts(sec.kategoriler, "Hepsi")}</select></label>
    </div>
    <div class="yanyana">
      <label>Sezon<select class="giris" id="kr-sezon">${secOpts(sec.sezonlar, "Hepsi")}</select></label>
      <label>Jant<select class="giris" id="kr-jant">${secOpts(sec.jant_gruplari, "Hepsi")}</select></label>
    </div>
    <label>Ticari grup<select class="giris" id="kr-altgrup">${secOpts(sec.alt_gruplar, "Hepsi")}</select></label>
    <div class="yanyana">
      <label>Oto-onay ≤ (%)<input type="number" class="giris" id="kr-oto" step="0.5" min="0"></label>
      <label>Müdür ≤ (%)<input type="number" class="giris" id="kr-mudur" step="0.5" min="0"></label>
    </div>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn" id="kr-ekle">Kural Ekle</button>
    </div>`);
  const kurallarYukle = async () => {
    try {
      const { kurallar } = await api("/api/saha/iskonto-kurallar");
      document.getElementById("kural-liste").innerHTML = kurallar.length ? kurallar.map(k => `
        <div class="ara-satir">
          <b>${esc(kuralOzet(k))}</b>
          <span class="rozet" style="background:#0284c7">≤%${Number(k.oto_onay_max)} oto · ≤%${Number(k.mudur_max)} müdür</span>
          <button class="btn kucuk kirmizi-btn" data-kural-sil="${k.id}">Sil</button>
        </div>`).join("") : `<div class="mini-durum">Henüz kural yok — genel eşikler geçerli.</div>`;
      document.querySelectorAll("[data-kural-sil]").forEach(b => b.addEventListener("click", async () => {
        if (!confirm("Kural silinsin mi?")) return;
        try { await api(`/api/saha/iskonto-kurallar/${b.dataset.kuralSil}`, { method: "DELETE" }); await kurallarYukle(); }
        catch (e) { uyari(e.message); }
      }));
    } catch (e) { document.getElementById("kural-liste").innerHTML = hata(e); }
  };
  await kurallarYukle();
  document.getElementById("es-kaydet").addEventListener("click", async () => {
    try {
      const { ayarlar } = await api("/api/saha/ayarlar", {
        method: "PUT",
        body: JSON.stringify({
          oto_onay_max: Number(document.getElementById("es-oto").value),
          mudur_max: Number(document.getElementById("es-mudur").value)
        })
      });
      S.ayarlar = ayarlar;
      uyari("✓ Genel eşikler kaydedildi.", true);
    } catch (e) { uyari(e.message); }
  });
  document.getElementById("kr-ekle").addEventListener("click", async () => {
    const g = id => document.getElementById(id).value.trim();
    if (!g("kr-oto") || !g("kr-mudur")) { uyari("Kural eşikleri zorunlu."); return; }
    try {
      await api("/api/saha/iskonto-kurallar", {
        method: "POST",
        body: JSON.stringify({
          marka: g("kr-marka") || null, kategori: g("kr-kategori") || null,
          sezon: g("kr-sezon") || null, jant_grubu: g("kr-jant") || null,
          alt_grup: g("kr-altgrup") || null,
          oto_onay_max: Number(g("kr-oto")), mudur_max: Number(g("kr-mudur"))
        })
      });
      ["kr-marka", "kr-oto", "kr-mudur"].forEach(id => document.getElementById(id).value = "");
      uyari("✓ Kural eklendi.", true);
      await kurallarYukle();
    } catch (e) { uyari(e.message); }
  });
}

async function kullaniciModal() {
  modal(`
    <h3>Saha Kullanıcıları</h3>
    <div id="ku-liste" class="ara-sonuc"><div class="saha-load">Yükleniyor…</div></div>
    <h4 class="bolum-baslik">Yeni Kullanıcı</h4>
    <label>Ad Soyad<input class="giris" id="ku-ad"></label>
    <label>E-posta<input class="giris" id="ku-email" type="email"></label>
    <label>Telefon (WhatsApp — 90xxxxxxxxxx)<input class="giris" id="ku-tel" type="tel" placeholder="905321234567"></label>
    <label>Rol
      <select class="giris" id="ku-rol">
        <option value="rep">Saha Temsilcisi</option>
        <option value="manager">Satış Müdürü</option>
        <option value="admin">Admin (GM)</option>
      </select></label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn" id="ku-ekle">Kullanıcı Aç</button>
    </div>
    <div id="ku-sonuc"></div>`);
  const listeYukle = async () => {
    try {
      const { kullanicilar } = await api("/api/saha/admin/users");
      document.getElementById("ku-liste").innerHTML = kullanicilar.map(u => `
        <div class="ara-satir"><b>${esc(u.full_name)}</b>
          <span class="rozet" style="background:${u.module_role === "admin" ? "#0f172a" : u.module_role === "manager" ? "#f59e0b" : "#10b981"}">${u.module_role}</span>
          <small>${esc(u.email)}${u.telefon ? ` · <a href="https://wa.me/${esc(String(u.telefon).replace(/\D/g, ""))}" target="_blank">📱 ${esc(u.telefon)}</a>` : ""}${u.last_login_at ? " · son giriş " + new Date(u.last_login_at).toLocaleDateString("tr-TR") : " · hiç girmedi"}</small>
        </div>`).join("") || "<div class='saha-bos'>Kayıt yok.</div>";
    } catch (e) { document.getElementById("ku-liste").innerHTML = hata(e); }
  };
  await listeYukle();
  document.getElementById("ku-ekle").addEventListener("click", async () => {
    const g = id => document.getElementById(id).value.trim();
    if (!g("ku-ad") || !g("ku-email")) { uyari("Ad ve e-posta zorunlu."); return; }
    try {
      const r = await api("/api/saha/admin/users", {
        method: "POST",
        body: JSON.stringify({ full_name: g("ku-ad"), email: g("ku-email"), module_role: g("ku-rol"), telefon: g("ku-tel") || null })
      });
      document.getElementById("ku-sonuc").innerHTML = r.gecici_sifre
        ? `<div class="bilgi-kutu">✓ Hesap açıldı. Geçici şifre: <b>${esc(r.gecici_sifre)}</b><br><small>Bu şifreyi şimdi iletin — tekrar gösterilmez. İlk girişte değiştirme zorunlu.</small></div>`
        : `<div class="bilgi-kutu">✓ ${esc(r.not)}</div>`;
      await listeYukle();
    } catch (e) { uyari(e.message); }
  });
}

// ── RAPOR ────────────────────────────────────────────────────────────────────
async function vRapor() {
  const simdi = new Date();
  const ayBasi = new Date(simdi.getFullYear(), simdi.getMonth(), 1).toISOString().slice(0, 10);
  const bugun  = simdi.toISOString().slice(0, 10);
  const isMgr  = ["manager","admin"].includes(S.role);

  const rpTabs = [
    ["ozet",        "📊 Özet"],
    ...(isMgr ? [["temsilciler", "👥 Temsilciler"]] : []),
    ["pipeline",    "💼 Pipeline"],
    ["pazar",       "🎯 Pazar"],
    ...(isMgr ? [["harita",      "🗺️ Harita"]] : []),
  ];

  let activeTab = "ozet";

  main().innerHTML = `
    <div style="padding:10px 12px 0">
      <div style="display:flex;gap:5px;margin-bottom:6px">
        ${[["7G",7],["30G",30],["3A",90],["1Y",365]].map(([l,d]) =>
          `<button class="rp-preset" data-days="${d}" style="flex:1;padding:5px 0;border:1px solid #e5e7eb;border-radius:6px;background:#fff;font-size:12px;font-weight:500;color:#374151;cursor:pointer">${l}</button>`
        ).join("")}
      </div>
      <div style="display:flex;align-items:center;gap:6px;margin-bottom:8px">
        <button id="rp-prev" style="padding:4px 10px;border:1px solid #e5e7eb;border-radius:6px;background:#fff;cursor:pointer;font-size:15px;color:#374151">‹</button>
        <input type="date" class="giris" id="rp-from" value="${ayBasi}" style="flex:1;font-size:16px;padding:5px 8px">
        <span style="color:#9ca3af;font-size:12px">→</span>
        <input type="date" class="giris" id="rp-to" value="${bugun}" style="flex:1;font-size:16px;padding:5px 8px">
        <button id="rp-next" style="padding:4px 10px;border:1px solid #e5e7eb;border-radius:6px;background:#fff;cursor:pointer;font-size:15px;color:#374151">›</button>
      </div>
      <div style="display:flex;gap:4px;overflow-x:auto;padding-bottom:0;margin-bottom:-1px" id="rp-tab-bar">
        ${rpTabs.map(([id, l], i) =>
          `<button class="rp-tab${i===0?" on":""}" data-t="${id}" style="white-space:nowrap;padding:7px 12px;border:1px solid ${i===0?"#3b82f6":"#e5e7eb"};border-bottom:${i===0?"1px solid #fff":"1px solid #e5e7eb"};border-radius:8px 8px 0 0;background:${i===0?"#fff":"#f9fafb"};color:${i===0?"#1d4ed8":"#6b7280"};font-size:12px;font-weight:${i===0?"700":"500"};cursor:pointer">${l}</button>`
        ).join("")}
      </div>
      <div style="height:1px;background:#e5e7eb;margin:0 0 0 0"></div>
    </div>
    <div id="rp-tab-icerik" style="padding-bottom:80px"></div>`;

  // ── Shared helpers ────────────────────────────────────────────────────────
  const rpFrom  = () => document.getElementById("rp-from")?.value  || ayBasi;
  const rpTo    = () => document.getElementById("rp-to")?.value    || bugun;
  const icerik  = () => document.getElementById("rp-tab-icerik");
  const bBaslik = (txt, clr = "#3b82f6", tip = "") =>
    `<div style="font-size:11px;font-weight:700;color:#374151;margin:16px 0 8px;padding-left:10px;border-left:3px solid ${clr};text-transform:uppercase;letter-spacing:0.5px;display:flex;align-items:center;gap:6px">${txt}${tip ? `<span title="${esc(tip)}" style="display:inline-flex;align-items:center;justify-content:center;width:14px;height:14px;border-radius:50%;background:#e5e7eb;color:#6b7280;font-size:10px;font-weight:700;cursor:default;text-transform:none;letter-spacing:0;flex-shrink:0">i</span>` : ""}</div>`;

  // ── Tab: Özet ─────────────────────────────────────────────────────────────
  async function rpOzet() {
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const reqs = [
        api(`/api/saha/rapor/ozet?from=${rpFrom()}&to=${rpTo()}${tipQS()}`),
        api(`/api/saha/rapor/teklif?from=${rpFrom()}&to=${rpTo()}${tipQS()}`)
      ];
      if (isMgr) reqs.push(api(`/api/saha/admin/yeni-musteriler?from=${rpFrom()}&to=${rpTo()}${tipQS()}`));
      const [ozet, teklif, yeniMus] = await Promise.all(reqs);
      const el2 = icerik(); if (!el2) return;

      const o  = ozet.ozet;
      const to_ = teklif.ozet;
      const sonuclanan = Number(to_.kazanilan) + Number(to_.kaybedilen);
      const winRate    = sonuclanan ? Math.round(1000 * to_.kazanilan / sonuclanan) / 10 : null;
      const kazTutar   = Number(to_.kazanilan_tutar || 0);

      const kut = (id, val, color, label) =>
        `<div class="ozet-kut" id="${id}" style="cursor:pointer" title="${label} listesini gör"><b style="color:${color}">${val||0}</b><span>${label}</span></div>`;

      el2.innerHTML = `
        <div style="padding:10px 12px">
          <div id="rp-buhafta"></div>

          ${bBaslik("Genel Bakış","#3b82f6","Seçili dönemin temel saha KPI'ları: ziyaret, müşteri, tamamlanan plan ve toplam teklif özeti.")}
          <div class="ozet-izgara">
            ${kut("rp-oz-ziyaret",   o.toplam_ziyaret, "#3b82f6", "Ziyaret")}
            ${kut("rp-oz-benzersiz", o.benzersiz_nokta, "#8b5cf6", "Benzersiz Nokta")}
            ${kut("rp-oz-yeni",      o.yeni_nokta,     "#10b981", "Yeni Nokta")}
            ${kut("rp-oz-pasif",     o.pasif_riskli,   "#ef4444", "Pasif/Riskli")}
          </div>

          ${bBaslik("Teklif Özeti","#8b5cf6","Dönem içinde oluşturulan tekliflerin durumu — açık, kazanılan ve kaybedilen adet ile toplam ciro.")}
          <div class="ozet-izgara">
            ${kut("rp-oz-tk-toplam", to_.toplam,    "#374151", "Toplam")}
            ${kut("rp-oz-tk-kaz",    to_.kazanilan, "#10b981", "Kazanılan")}
            ${kut("rp-oz-tk-kayb",   to_.kaybedilen,"#ef4444", "Kaybedilen")}
            ${kut("rp-oz-tk-acik",   to_.bekleyen,  "#374151", "Açık")}
            <div class="ozet-kut"><b style="color:${winRate!=null&&winRate>=50?"#10b981":"#f59e0b"}">${winRate!=null?"%"+winRate:"—"}</b><span>Win Rate</span></div>
          </div>
          ${kazTutar ? `<div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;padding:8px;text-align:center;margin-top:6px"><div style="font-size:11px;color:#16a34a;font-weight:600">Kazanılan Ciro</div><div style="font-size:16px;font-weight:700;color:#15803d">${kazTutar.toLocaleString("tr-TR")}₺</div></div>` : ""}

          ${isMgr && yeniMus ? (() => {
            const oz = yeniMus.ozet;
            return `
          ${bBaslik("Yeni Müşteri","#10b981","Bu dönemde sisteme ilk kez eklenen veya ilk ziyareti gerçekleştirilen yeni müşteri sayısı.")}
          <div class="ozet-izgara">
            <div class="ozet-kut" id="rp-yeni-mus-kut" style="cursor:pointer;background:#f0fdf4;border:1px solid #bbf7d0">
              <b style="color:#16a34a">${oz.toplam}</b><span>Yeni Kayıt 📋</span>
            </div>
            <div class="ozet-kut"><b style="color:#1d4ed8">${oz.konumlu}</b><span>GPS Pinli</span></div>
            <div class="ozet-kut" style="background:${oz.vkn_var<oz.toplam?"#fff7ed":"#f0fdf4"};border:1px solid ${oz.vkn_var<oz.toplam?"#fed7aa":"#bbf7d0"}">
              <b style="color:${oz.vkn_var<oz.toplam?"#c2410c":"#16a34a"}">${oz.vkn_var}</b><span>VKN Girilen</span>
            </div>
          </div>`;
          })() : ""}
        </div>`;

      // ── Genel Bakış chip clicks ────────────────────────────────────────────
      const fetchZiyaretler = () => api(`/api/saha/ziyaretler?durum=TAMAMLANDI&from=${rpFrom()}&to=${rpTo()}${tipQS()}`);

      el2.querySelector("#rp-oz-ziyaret")?.addEventListener("click", async () => {
        modal(`<div class="saha-load">Yükleniyor…</div>`);
        const { ziyaretler } = await fetchZiyaretler();
        rpZiyaretListesiModal("Ziyaretler", ziyaretler);
      });
      el2.querySelector("#rp-oz-benzersiz")?.addEventListener("click", async () => {
        modal(`<div class="saha-load">Yükleniyor…</div>`);
        const { ziyaretler } = await fetchZiyaretler();
        const seen = new Set();
        const uniq = ziyaretler.filter(z => { if (seen.has(z.musteri_id)) return false; seen.add(z.musteri_id); return true; });
        rpZiyaretListesiModal("Benzersiz Nokta", uniq);
      });
      el2.querySelector("#rp-oz-yeni")?.addEventListener("click", async () => {
        modal(`<div class="saha-load">Yükleniyor…</div>`);
        const { ziyaretler } = await fetchZiyaretler();
        rpZiyaretListesiModal("Yeni Nokta", ziyaretler.filter(z => z.musteri_durum === "YENI_NOKTA"));
      });
      el2.querySelector("#rp-oz-pasif")?.addEventListener("click", async () => {
        modal(`<div class="saha-load">Yükleniyor…</div>`);
        const { ziyaretler } = await fetchZiyaretler();
        rpZiyaretListesiModal("Pasif/Riskli", ziyaretler.filter(z => ["PASIF_NOKTA","RISKLI_NOKTA"].includes(z.musteri_durum)));
      });

      // ── Teklif Özeti chip clicks ──────────────────────────────────────────
      const fetchTeklifler = async (durumParam) => {
        const qs = `/api/saha/teklifler?from=${rpFrom()}&to=${rpTo()}${tipQS()}${durumParam ? `&durum=${durumParam}` : ""}`;
        const { teklifler } = await api(qs);
        return teklifler;
      };
      el2.querySelector("#rp-oz-tk-toplam")?.addEventListener("click", async () => {
        modal(`<div class="saha-load">Yükleniyor…</div>`);
        rpTeklifListesiModal("Tüm Teklifler", await fetchTeklifler(null));
      });
      el2.querySelector("#rp-oz-tk-kaz")?.addEventListener("click", async () => {
        modal(`<div class="saha-load">Yükleniyor…</div>`);
        rpTeklifListesiModal("Kazanılan Teklifler", await fetchTeklifler("KAZANILDI"));
      });
      el2.querySelector("#rp-oz-tk-kayb")?.addEventListener("click", async () => {
        modal(`<div class="saha-load">Yükleniyor…</div>`);
        rpTeklifListesiModal("Kaybedilen Teklifler", await fetchTeklifler("KAYBEDILDI"));
      });
      el2.querySelector("#rp-oz-tk-acik")?.addEventListener("click", async () => {
        modal(`<div class="saha-load">Yükleniyor…</div>`);
        const all = await fetchTeklifler(null);
        rpTeklifListesiModal("Açık Teklifler", all.filter(t => !["KAZANILDI","KAYBEDILDI","IPTAL"].includes(t.durum)));
      });

      if (isMgr && yeniMus) {
        el2.querySelector("#rp-yeni-mus-kut")?.addEventListener("click", () =>
          rpYeniMusteriModal(yeniMus.musteriler)
        );
      }
      rpBuHafta(); // async, populates #rp-buhafta when ready
    } catch(e) {
      const el2 = icerik(); if (el2) el2.innerHTML = hata(e);
    }
  }

  // Bu Hafta forward-looking section — fires in background, updates #rp-buhafta
  async function rpBuHafta() {
    try {
      const hafta7    = new Date(simdi); hafta7.setDate(hafta7.getDate() + 7);
      const hafta7Iso = hafta7.toISOString().slice(0, 10);
      const [{ ziyaretler: planlar }, { teklifler }] = await Promise.all([
        api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`),
        api("/api/saha/teklifler")
      ]);
      const gecmis    = planlar.filter(z => z.planlanan_tarih && z.planlanan_tarih.slice(0, 10) < bugun);
      const buhafta   = planlar.filter(z => { const d = z.planlanan_tarih?.slice(0, 10); return d && d >= bugun && d <= hafta7Iso; });
      const onaylandi = teklifler.filter(t => t.durum === "ONAYLANDI");
      const kutu = document.getElementById("rp-buhafta");
      if (!kutu) return;
      if (!gecmis.length && !buhafta.length && !onaylandi.length) return;
      kutu.innerHTML = `
        <div style="background:#f8fafc;border:1px solid #e5e7eb;border-radius:10px;padding:10px 12px;margin-bottom:10px">
          <div style="font-size:11px;font-weight:700;color:#64748b;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.5px">Bu Hafta</div>
          <div class="ozet-izgara" style="margin-bottom:${gecmis.length||onaylandi.length?"6px":"0"}">
            ${gecmis.length    ? `<div class="ozet-kut" style="background:#fef2f2;cursor:pointer" id="rp-gecmis-kut"><b style="color:#ef4444">${gecmis.length}</b><span>Gecikmiş Plan ⚠</span></div>` : ""}
            ${buhafta.length   ? `<div class="ozet-kut"><b>${buhafta.length}</b><span>Bu Hafta Planlı</span></div>` : ""}
            ${onaylandi.length ? `<div class="ozet-kut" style="background:#f0f9ff;cursor:pointer" id="rp-onaylandi-kut"><b style="color:#0ea5e9">${onaylandi.length}</b><span>Sunulmayı Bekliyor</span></div>` : ""}
          </div>
          ${gecmis.length    ? `<div style="font-size:11px;color:#94a3b8">⚠ ${gecmis.slice(0,3).map(z=>`<b>${esc(z.firma)}</b> (${new Date(z.planlanan_tarih).toLocaleDateString("tr-TR")})`).join(" · ")}${gecmis.length>3?` +${gecmis.length-3} daha`:""}</div>` : ""}
          ${onaylandi.length ? `<div style="font-size:11px;color:#0369a1;margin-top:2px">📋 ${onaylandi.slice(0,3).map(t=>`<b>${esc(t.firma)}</b>`).join(", ")}${onaylandi.length>3?` +${onaylandi.length-3} daha`:""}</div>` : ""}
        </div>`;
      kutu.querySelector("#rp-gecmis-kut")?.addEventListener("click", () => {
        S.container.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x.dataset.v === "plan"));
        loadView("plan");
      });
      kutu.querySelector("#rp-onaylandi-kut")?.addEventListener("click", () => {
        S.container.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x.dataset.v === "iskonto"));
        loadView("iskonto");
      });
    } catch {}
  }

  // ── Ziyaret listesi modal (Genel Bakış chip click) ───────────────────────
  function rpZiyaretListesiModal(baslik, rows) {
    const TUR = { TUKETICI: "Tüketici", TICARI: "Ticari" };
    const PG = 25; let pg = 0;
    const total = Math.ceil(rows.length / PG);
    const render = () => {
      const el = document.getElementById("rp-zl-icerik"); if (!el) return;
      const slice = rows.slice(pg * PG, (pg + 1) * PG);
      el.innerHTML = rows.length === 0
        ? `<div style="color:#94a3b8;font-size:13px;text-align:center;padding:24px">Kayıt yok</div>`
        : `<div style="overflow-x:auto;max-height:380px;overflow-y:auto">
            <table class="tablo" style="width:100%;margin:0;font-size:12px">
              <tr><th style="padding-left:8px">Firma</th><th>İl</th><th>Tip</th>${isMgr?"<th>Temsilci</th>":""}<th>Tarih</th></tr>
              ${slice.map(z => `<tr>
                <td style="padding-left:8px;font-weight:500;max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(z.firma||"—")}</td>
                <td style="color:#6b7280">${esc(z.il||"—")}</td>
                <td style="font-size:11px">${TUR[z.tip]||z.tip||"—"}</td>
                ${isMgr?`<td style="color:#6b7280;font-size:11px">${esc(z.rep_full_name||z.rep_adi||"—")}</td>`:""}
                <td style="color:#6b7280;font-size:11px;white-space:nowrap">${z.ziyaret_tarihi ? new Date(z.ziyaret_tarihi).toLocaleDateString("tr-TR",{day:"numeric",month:"short"}) : "—"}</td>
              </tr>`).join("")}
            </table>
          </div>
          ${total > 1 ? `<div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0 0">
            <button class="btn kucuk gri" id="rp-zl-prev" ${pg===0?"disabled":""}>‹ Önceki</button>
            <span style="font-size:12px;color:#6b7280">${pg+1} / ${total}</span>
            <button class="btn kucuk gri" id="rp-zl-next" ${pg===total-1?"disabled":""}>Sonraki ›</button>
          </div>` : ""}`;
      document.getElementById("rp-zl-prev")?.addEventListener("click", () => { pg--; render(); });
      document.getElementById("rp-zl-next")?.addEventListener("click", () => { pg++; render(); });
    };
    modal(`
      <div style="font-size:13px;font-weight:700;color:#374151;margin-bottom:12px">📍 ${esc(baslik)} (${rows.length})</div>
      <div id="rp-zl-icerik"></div>
      <button class="btn kucuk gri" onclick="kapatModal()" style="width:100%;margin-top:12px">Kapat</button>`);
    render();
  }

  // ── Teklif listesi modal (Teklif Özeti chip click) ────────────────────────
  function rpTeklifListesiModal(baslik, rows) {
    const DUR = { KAZANILDI:"✅ Kazanıldı", KAYBEDILDI:"❌ Kaybedildi", TASLAK:"📝 Taslak",
                  ONAY_BEKLIYOR:"⏳ Onay Bekliyor", ONAYLANDI:"✓ Onaylandı",
                  SUNULDU:"📤 Sunuldu", IPTAL:"🚫 İptal" };
    const PG = 20; let pg = 0;
    const total = Math.ceil(rows.length / PG);
    const render = () => {
      const el = document.getElementById("rp-tl-icerik"); if (!el) return;
      const slice = rows.slice(pg * PG, (pg + 1) * PG);
      el.innerHTML = rows.length === 0
        ? `<div style="color:#94a3b8;font-size:13px;text-align:center;padding:24px">Kayıt yok</div>`
        : `<div style="overflow-x:auto;max-height:380px;overflow-y:auto">
            <table class="tablo" style="width:100%;margin:0;font-size:12px">
              <tr><th style="padding-left:8px">Firma</th><th>Marka</th><th>Tutar</th><th>Durum</th>${isMgr?"<th>Temsilci</th>":""}<th>Tarih</th></tr>
              ${slice.map(t => `<tr>
                <td style="padding-left:8px;font-weight:500;max-width:130px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(t.firma||"—")}</td>
                <td style="font-size:11px">${esc(t.marka||"—")}</td>
                <td style="white-space:nowrap">${t.toplam_tutar ? Number(t.toplam_tutar).toLocaleString("tr-TR")+"₺" : "—"}</td>
                <td style="font-size:11px">${DUR[t.durum]||t.durum||"—"}</td>
                ${isMgr?`<td style="color:#6b7280;font-size:11px">${esc(t.rep_full_name||"—")}</td>`:""}
                <td style="color:#6b7280;font-size:11px;white-space:nowrap">${t.created_at ? new Date(t.created_at).toLocaleDateString("tr-TR",{day:"numeric",month:"short"}) : "—"}</td>
              </tr>`).join("")}
            </table>
          </div>
          ${total > 1 ? `<div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0 0">
            <button class="btn kucuk gri" id="rp-tl-prev" ${pg===0?"disabled":""}>‹ Önceki</button>
            <span style="font-size:12px;color:#6b7280">${pg+1} / ${total}</span>
            <button class="btn kucuk gri" id="rp-tl-next" ${pg===total-1?"disabled":""}>Sonraki ›</button>
          </div>` : ""}`;
      document.getElementById("rp-tl-prev")?.addEventListener("click", () => { pg--; render(); });
      document.getElementById("rp-tl-next")?.addEventListener("click", () => { pg++; render(); });
    };
    modal(`
      <div style="font-size:13px;font-weight:700;color:#374151;margin-bottom:12px">💼 ${esc(baslik)} (${rows.length})</div>
      <div id="rp-tl-icerik"></div>
      <button class="btn kucuk gri" onclick="kapatModal()" style="width:100%;margin-top:12px">Kapat</button>`);
    render();
  }

  // Yeni Müşteri paginated modal
  function rpYeniMusteriModal(musteriler) {
    const KAYNAK = { SAHA_ZIYARETI: "📍 Saha", TELEFON: "📞 Telefon", REFERANS: "🤝 Referans", DIGER: "Diğer" };
    const PG = 20;
    let pg = 0;
    const total = Math.ceil(musteriler.length / PG);
    const render = () => {
      const el = document.getElementById("rp-ym-icerik"); if (!el) return;
      const slice = musteriler.slice(pg * PG, (pg + 1) * PG);
      el.innerHTML = `
        <div style="overflow-x:auto;max-height:360px;overflow-y:auto">
          <table class="tablo" style="width:100%;margin:0;font-size:12px">
            <tr><th style="padding-left:8px">Firma</th><th>İl</th><th>Kaynak</th><th>VKN</th><th>GPS</th><th>Rep</th><th>Tarih</th></tr>
            ${slice.map(c => `<tr>
              <td style="padding-left:8px;font-weight:500;max-width:120px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(c.firma)}</td>
              <td>${esc(c.il||"—")}</td>
              <td style="font-size:11px">${KAYNAK[c.kayit_kaynagi]||c.kayit_kaynagi||"—"}</td>
              <td>${c.vergi_no?`<span style="color:#16a34a">✓</span>`:`<span style="color:#d97706">—</span>`}</td>
              <td>${c.lat!=null?`<span style="color:#16a34a">✓</span>`:`<span style="color:#94a3b8">—</span>`}</td>
              <td style="color:#6b7280;font-size:11px">${esc(c.rep_adi||"—")}</td>
              <td style="color:#6b7280;font-size:11px">${new Date(c.created_at).toLocaleDateString("tr-TR",{day:"numeric",month:"short"})}</td>
            </tr>`).join("")}
          </table>
        </div>
        ${total > 1 ? `
        <div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0 0">
          <button class="btn kucuk gri" id="rp-ym-prev" ${pg===0?"disabled":""}>‹ Önceki</button>
          <span style="font-size:12px;color:#6b7280">${pg+1} / ${total}</span>
          <button class="btn kucuk gri" id="rp-ym-next" ${pg===total-1?"disabled":""}>Sonraki ›</button>
        </div>` : ""}`;
      document.getElementById("rp-ym-prev")?.addEventListener("click", () => { pg--; render(); });
      document.getElementById("rp-ym-next")?.addEventListener("click", () => { pg++; render(); });
    };
    modal(`
      <div style="font-size:13px;font-weight:700;color:#374151;margin-bottom:12px">📋 Yeni Müşteri Kayıtları (${musteriler.length})</div>
      <div id="rp-ym-icerik"></div>
      <button class="btn kucuk gri" onclick="kapatModal()" style="width:100%;margin-top:12px">Kapat</button>`
    );
    render();
  }

  // ── Tab: Temsilciler ──────────────────────────────────────────────────────
  async function rpTemsilciler() {
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const { repler } = await api(`/api/saha/rapor/rep-performans?from=${rpFrom()}&to=${rpTo()}`);
      const el2 = icerik(); if (!el2) return;
      if (!repler.length) { el2.innerHTML = `<div class="saha-bos">Bu dönemde ziyaret kaydı yok.</div>`; return; }
      const maxZ = Math.max(...repler.map(r => Number(r.ziyaret)), 1);
      el2.innerHTML = `
        <div style="padding:10px 12px">
          ${bBaslik("Temsilci Performansı","#3b82f6","Her temsilcinin dönem içindeki ziyaret adedi, benzersiz müşteri sayısı, oluşturduğu teklif adedi ve kazanma oranı karşılaştırması.")}
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden">
            <table class="tablo" style="margin:0">
              <tr><th style="padding-left:12px">Temsilci</th><th>Ziyaret</th><th>Müşteri</th><th>Teklif</th><th>Win %</th></tr>
              ${repler.map(r => {
                const pct = Math.round(100 * Number(r.ziyaret) / maxZ);
                const tek = Number(r.teklif || 0);
                const kaz = Number(r.kazanilan || 0);
                const wr  = tek > 0 ? Math.round(100 * kaz / tek) : null;
                return `<tr>
                  <td style="padding-left:12px;font-weight:500">${esc(r.rep)}</td>
                  <td>
                    <div style="display:flex;align-items:center;gap:6px">
                      <div style="width:48px;background:#f3f4f6;border-radius:4px;height:6px;flex-shrink:0">
                        <div style="width:${pct}%;background:#3b82f6;border-radius:4px;height:6px;min-width:${pct>0?2:0}px"></div>
                      </div>
                      <span style="font-size:13px;font-weight:600;color:#1e40af">${r.ziyaret}</span>
                    </div>
                  </td>
                  <td>${r.benzersiz_musteri||0}</td>
                  <td>${tek>0?tek:"—"}</td>
                  <td>${wr!=null?`<span style="color:${wr>=50?"#10b981":"#f59e0b"};font-weight:600">%${wr}</span>`:"—"}</td>
                </tr>`;
              }).join("")}
            </table>
          </div>
        </div>`;
    } catch(e) {
      const el2 = icerik(); if (el2) el2.innerHTML = hata(e);
    }
  }

  // ── Tab: Pipeline ─────────────────────────────────────────────────────────
  async function rpPipeline() {
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const teklif = await api(`/api/saha/rapor/teklif?from=${rpFrom()}&to=${rpTo()}`);
      const el2 = icerik(); if (!el2) return;
      const to_ = teklif.ozet;
      const sonuclanan = Number(to_.kazanilan) + Number(to_.kaybedilen);
      const winRate    = sonuclanan ? Math.round(1000 * to_.kazanilan / sonuclanan) / 10 : null;
      const kazTutar   = Number(to_.kazanilan_tutar || 0);
      const kayTutar   = Number(to_.kaybedilen_tutar || 0);
      // store date range for click handlers
      const _ppFrom = rpFrom(), _ppTo = rpTo();
      window._pipelineFrom = _ppFrom;
      window._pipelineTo   = _ppTo;

      el2.innerHTML = `
        <div style="padding:10px 12px">
          ${bBaslik("Teklif Performansı","#3b82f6","Dönem içinde oluşturulan tekliflerin huni görünümü; toplam, kazanılan ve kaybedilen adet ile ciro dağılımı.")}
          <div class="ozet-izgara">
            <div class="ozet-kut"><b>${to_.toplam||0}</b><span>Toplam</span></div>
            <div class="ozet-kut" style="cursor:pointer;transition:transform .1s" onclick="pipelineTeklifListesi('KAZANILDI','✅ Kazanılan Teklifler')">
              <b style="color:#10b981">${to_.kazanilan||0}</b><span>Kazanılan</span>
              <span style="font-size:10px;color:#10b981;margin-top:2px">↗ listele</span>
            </div>
            <div class="ozet-kut" style="cursor:pointer;transition:transform .1s" onclick="pipelineTeklifListesi('KAYBEDILDI','❌ Kaybedilen Teklifler')">
              <b style="color:#ef4444">${to_.kaybedilen||0}</b><span>Kaybedilen</span>
              <span style="font-size:10px;color:#ef4444;margin-top:2px">↗ listele</span>
            </div>
            <div class="ozet-kut"><b>${to_.bekleyen||0}</b><span>Açık</span></div>
            <div class="ozet-kut"><b style="color:${winRate!=null&&winRate>=50?"#10b981":"#f59e0b"}">${winRate!=null?"%"+winRate:"—"}</b><span>Win Rate</span></div>
          </div>
          ${(kazTutar || kayTutar) ? `
          <div style="display:flex;gap:8px;margin-top:8px">
            ${kazTutar?`<div style="flex:1;background:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;padding:8px;text-align:center;cursor:pointer" onclick="pipelineTeklifListesi('KAZANILDI','✅ Kazanılan Teklifler')"><div style="font-size:11px;color:#16a34a;font-weight:600">Kazanılan Ciro</div><div style="font-size:14px;font-weight:700;color:#15803d">${kazTutar.toLocaleString("tr-TR")}₺</div></div>`:""}
            ${kayTutar?`<div style="flex:1;background:#fef2f2;border:1px solid #fecaca;border-radius:8px;padding:8px;text-align:center;cursor:pointer" onclick="pipelineTeklifListesi('KAYBEDILDI','❌ Kaybedilen Teklifler')"><div style="font-size:11px;color:#ef4444;font-weight:600">Kaybedilen</div><div style="font-size:14px;font-weight:700;color:#dc2626">${kayTutar.toLocaleString("tr-TR")}₺</div></div>`:""}
          </div>` : ""}

          ${teklif.marka_bazli?.length ? `
          ${bBaslik("Marka Bazlı Win Rate","#8b5cf6","Marka bazında kazanılan teklif oranı. Hangi markalarda daha başarılı olunduğunu gösterir; düşük oran o markada rekabet zorluğuna işaret eder.")}
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden">
            <table class="tablo" style="margin:0">
              <tr><th>Marka</th><th>Teklif</th><th>Kazanç</th><th>Kayıp</th><th>Win %</th></tr>
              ${teklif.marka_bazli.map(r=>`<tr><td>${esc(r.marka)}</td><td>${r.teklif}</td><td>${r.kazanilan}</td><td>${r.kaybedilen}</td><td>${r.win_rate!=null?"%"+r.win_rate:"—"}</td></tr>`).join("")}
            </table>
          </div>` : ""}

          ${teklif.rakip_kayiplari?.length ? `
          ${bBaslik("Kime Kaybediyoruz?","#ef4444","Kaybedilen tekliflerde müşterilerin tercih ettiği rakip markalar ve bu kayıpların toplam ciro etkisi.")}
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden">
            <table class="tablo" style="margin:0">
              <tr><th>Rakip</th><th>Model</th><th>Kayıp</th><th>Tutar</th><th>Ort. Fiyat</th></tr>
              ${teklif.rakip_kayiplari.map(r=>`<tr><td>${esc(r.rakip_marka)}</td><td>${esc(r.rakip_model)||"—"}</td><td>${r.kayip}</td><td>${Number(r.kayip_tutar).toLocaleString("tr-TR")}₺</td><td>${r.ort_rakip_fiyat?Number(r.ort_rakip_fiyat).toLocaleString("tr-TR")+"₺":"—"}</td></tr>`).join("")}
            </table>
          </div>` : ""}

          ${teklif.kayip_nedenleri?.length ? `
          ${bBaslik("Kayıp Nedenleri","#f59e0b","Kaybedilen tekliflerde temsilcilerin kayıt ettiği başlıca nedenler (fiyat, stok, rakip teklif vb.). Tekrarlayan nedenler yapısal soruna işaret eder.")}
          <div style="display:flex;gap:6px;flex-wrap:wrap">
            ${teklif.kayip_nedenleri.map(n=>`<div style="background:#fef3c7;border:1px solid #fde68a;border-radius:8px;padding:6px 10px;font-size:12px"><b>${KAYIP_NEDEN[n.neden]||n.neden}</b>: ${n.adet}</div>`).join("")}
          </div>` : ""}
        </div>`;
    } catch(e) {
      const el2 = icerik(); if (el2) el2.innerHTML = hata(e);
    }
  }

  // ── Tab: Pazar ────────────────────────────────────────────────────────────
  async function rpPazar() {
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const [rakip, bolge] = await Promise.all([
        api(`/api/saha/rapor/rakip?from=${rpFrom()}&to=${rpTo()}`),
        api(`/api/saha/rapor/bolge-marka?from=${rpFrom()}&to=${rpTo()}`)
      ]);
      const el2 = icerik(); if (!el2) return;
      const bolgeler = {};
      for (const s of bolge.satirlar) (bolgeler[s.bolge] = bolgeler[s.bolge] || []).push(s);
      el2.innerHTML = `
        <div style="padding:10px 12px">
          ${rakip.rakipler.length ? `
          ${bBaslik("Rakip Görülme Analizi","#3b82f6","Ziyaret sırasında müşteri rafında veya kullanımda görülen rakip markaların kaç ziyarette kayıt altına alındığını gösterir. Oran, toplam tamamlanan ziyaret sayısına göre hesaplanır.")}
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden">
            <table class="tablo" style="margin:0">
              <tr><th style="padding-left:12px">Rakip</th><th>Görülme</th><th>Oran</th></tr>
              ${rakip.rakipler.map(r=>`<tr><td style="padding-left:12px">${esc(r.rakip)}</td><td>${r.gorulme}</td><td>%${r.oran}${Number(r.oran)>=20?" 🔴":Number(r.oran)>=10?" 🟡":""}</td></tr>`).join("")}
            </table>
          </div>` : `<div class="saha-bos">Bu dönemde rakip kaydı yok.</div>`}

          ${Object.keys(bolgeler).length ? `
          ${bBaslik("Bölge × Marka","#3b82f6","Ziyaret sırasında müşteri rafında görülen markaların ile göre dağılımı. Her kutucuk, o ildeki müşteri raflarında kaç kez görüldüğünü gösterir. Temsilcilerin ziyaret notlarından derlenir.")}
          <div style="display:flex;flex-direction:column;gap:8px">
            ${Object.entries(bolgeler).map(([b, satirlar]) => `
            <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:10px 12px">
              <div style="font-size:12px;font-weight:700;color:#374151;margin-bottom:6px">${esc(b)}</div>
              <div style="display:flex;gap:5px;flex-wrap:wrap">
                ${satirlar.slice(0,10).map(s=>`<span style="background:#f3f4f6;border-radius:6px;padding:2px 8px;font-size:12px">${esc(s.marka)}: <b>${s.gorulme}</b></span>`).join("")}
              </div>
            </div>`).join("")}
          </div>` : ""}
        </div>`;
    } catch(e) {
      const el2 = icerik(); if (el2) el2.innerHTML = hata(e);
    }
  }

  // ── Tab: Harita (Saha Sesi) ───────────────────────────────────────────────
  function rpHarita() {
    const el = icerik(); if (!el) return;
    el.innerHTML = `
      <div style="padding:10px 12px 80px">

        <!-- ── SECTION 1: MAP ─────────────────────────── -->
        <div style="font-size:11px;font-weight:700;color:#374151;margin-bottom:10px;padding-left:10px;border-left:3px solid #3b82f6;text-transform:uppercase;letter-spacing:0.5px">🗺️ Saha Haritası</div>
        <div style="background:#fff;border:1px solid #e5e7eb;border-radius:12px;padding:14px;margin-bottom:16px">
          <!-- Layer toggle -->
          <div style="display:flex;gap:5px;margin-bottom:7px" id="ss-layer-bar">
            ${[["ziyaret","📍 Ziyaret"],["teklif","💼 Teklif"],["satis","💰 Satış"]].map(([v,l],i) =>
              `<button class="ss-layer-btn" data-l="${v}" style="flex:1;padding:4px 0;border:1.5px solid ${i===0?"#8b5cf6":"#e5e7eb"};background:${i===0?"#8b5cf6":"#fff"};color:${i===0?"#fff":"#374151"};border-radius:8px;font-size:11px;font-weight:${i===0?"700":"500"};cursor:pointer">${l}</button>`
            ).join("")}
          </div>
          <!-- Sub-controls -->
          <div id="ss-layer-sub" style="margin-bottom:6px"></div>
          <!-- Map period -->
          <div style="font-size:11px;color:#6b7280;margin-bottom:5px">Dönem</div>
          <div style="display:flex;gap:5px;margin-bottom:8px" id="map-donem-bar">
            ${[["30G",30],["90G",90],["1Y",365],["Tümü",0]].map(([l,d],i) =>
              `<button class="map-donem-btn" data-d="${d}" style="flex:1;padding:4px 0;border:1.5px solid ${i===0?"#3b82f6":"#e5e7eb"};background:${i===0?"#eff6ff":"#fff"};color:${i===0?"#1d4ed8":"#374151"};border-radius:8px;font-size:12px;font-weight:${i===0?"700":"400"};cursor:pointer">${l}</button>`
            ).join("")}
          </div>
          <!-- Ebat typeahead filter -->
          <div style="margin-bottom:8px;position:relative" id="ss-ebat-wrap">
            <div style="display:flex;align-items:center;gap:6px">
              <span style="font-size:11px;color:#6b7280;white-space:nowrap">🔍 Ebat</span>
              <div style="flex:1;position:relative">
                <input id="ss-ebat" type="text" placeholder="örn: 205/55R16…" autocomplete="off" class="giris" style="font-size:12px;padding:4px 8px;width:100%;box-sizing:border-box">
                <div id="ss-ebat-dd" style="display:none;position:absolute;left:0;right:0;top:calc(100% + 2px);background:#fff;border:1px solid #e5e7eb;border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,.1);z-index:200;max-height:160px;overflow-y:auto"></div>
              </div>
              <button id="ss-ebat-clear" style="display:none;padding:3px 8px;border:1px solid #e5e7eb;border-radius:6px;background:#fff;font-size:11px;color:#6b7280;cursor:pointer">✕</button>
            </div>
          </div>
          <!-- Map -->
          <div id="ss-harita" style="position:relative;background:#f8fafc;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden;min-height:60px">
            <div style="padding:16px;text-align:center;font-size:12px;color:#94a3b8">Harita yükleniyor…</div>
          </div>
          <!-- City info card (shown on click) -->
          <div id="ss-sehir-kart" style="display:none;margin-top:10px;background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:12px">
            <div id="ss-sehir-baslik" style="font-size:13px;font-weight:700;color:#1d4ed8;margin-bottom:8px"></div>
            <div id="ss-sehir-stats" style="font-size:12px;color:#374151;line-height:1.9"></div>
            <button id="ss-sehir-analiz-btn" class="btn" style="width:100%;background:#8b5cf6;margin-top:10px;font-size:12px;padding:8px">🤖 Bu şehri analiz et</button>
            <div id="ss-sehir-sonuc" style="display:none;margin-top:10px"></div>
          </div>
        </div>

        <!-- ── SECTION 2: SAHA SESİ ───────────────────── -->
        <div style="font-size:11px;font-weight:700;color:#374151;margin-bottom:10px;padding-left:10px;border-left:3px solid #8b5cf6;text-transform:uppercase;letter-spacing:0.5px">🤖 Saha Sesi — AI Analiz</div>
        <div style="background:#fff;border:1px solid #e5e7eb;border-radius:12px;padding:14px">
          <div style="font-size:11px;color:#6b7280;margin-bottom:6px">Kapsam seçin:</div>
          <div style="display:flex;gap:6px;margin-bottom:12px;flex-wrap:wrap" id="ss-kapsam-bar">
            ${[["tum","🏢 Tüm KRB"],["temsilci","👤 Temsilci"],["durum","⚠ Pasif/Riskli"],["musteri","🏬 Müşteri"]].map(([v,l]) =>
              `<button class="ss-kapsam-btn" data-k="${v}" style="padding:6px 14px;border-radius:20px;border:1.5px solid #e5e7eb;background:#fff;color:#374151;font-size:12px;font-weight:600;cursor:pointer">${l}</button>`
            ).join("")}
          </div>
          <div id="ss-filtre" style="margin-bottom:10px"></div>
          <div style="font-size:11px;color:#6b7280;margin-bottom:6px">Dönem <span style="color:#8b5cf6;font-size:10px">(önceki dönemle karşılaştırır)</span></div>
          <div style="display:flex;gap:5px;margin-bottom:12px" id="ss-donem-bar">
            ${[["30G",30],["90G",90],["1Y",365],["Tümü",0]].map(([l,d],i) =>
              `<button class="ss-donem-btn" data-d="${d}" style="flex:1;padding:5px 0;border:1.5px solid ${i===0?"#8b5cf6":"#e5e7eb"};background:${i===0?"#f5f3ff":"#fff"};color:${i===0?"#7c3aed":"#374151"};border-radius:8px;font-size:12px;font-weight:${i===0?"700":"400"};cursor:pointer">${l}</button>`
            ).join("")}
          </div>
          <button id="ss-analiz-btn" class="btn" style="width:100%;background:#8b5cf6;margin-bottom:0">🤖 Saha Sesini Analiz Et</button>
          <div id="ss-sonuc" style="display:none;margin-top:12px"></div>
        </div>
      </div>

      <!-- Floating hover tooltip -->
      <div id="ss-tt" style="position:fixed;display:none;background:rgba(17,24,39,0.88);color:#fff;font-size:11px;font-weight:600;padding:5px 10px;border-radius:7px;pointer-events:none;z-index:9999;white-space:nowrap;box-shadow:0 2px 8px rgba(0,0,0,.35)"></div>`;

    // ── State ──────────────────────────────────────────────────────────────
    let mapDays  = 30;   // map period
    let mapSehir = null; // selected city
    let ssDays   = 30;   // saha sesi period
    let ssKapsam = "";
    let _trGeo   = null;
    let ssLayers        = new Set(["ziyaret"]);
    let ssMapColor      = "ziyaret";
    let ssSatisMetrik   = "tumu";
    let ssTeklifMetrik  = "toplam";
    let ssEbat          = "";
    let _ebatTimer      = null;
    let _haritaData     = new Map();
    let _subInitialized = false;

    const IL_NORM = {
      "Mersin": "İçel (Mersin)", "İçel": "İçel (Mersin)",
      "Afyon": "Afyonkarahisar", "K.Maraş": "Kahramanmaraş",
      "Kahraman Maraş": "Kahramanmaraş", "Urfa": "Şanlıurfa"
    };
    const normIl = n => IL_NORM[n] || n;

    function bucketIdx(val, q) {
      if (val >= q[3]) return 3; if (val >= q[2]) return 2; if (val >= q[1]) return 1; return 0;
    }
    function computeQ(rows, key) {
      const vals = rows.map(r => +(r[key]||0)).filter(v => v > 0).sort((a,b) => a-b);
      if (!vals.length) return [1,1,1,1];
      const p = f => vals[Math.min(Math.floor(f * vals.length), vals.length-1)];
      return [p(0.25), p(0.5), p(0.75), p(0.9)];
    }
    const NO_DATA_COLOR = "#c8d9eb";

    function ilColorSingle(s, layer, satisM, teklifM, qs) {
      if (!s) return NO_DATA_COLOR;
      if (layer === "ziyaret") {
        if (!+s.ziyaret) return NO_DATA_COLOR;
        const z = +s.ziyaret, sy = +(s.son_yarim||0), bad = +(s.sorunlu||0), mst = +(s.musteri||1);
        if (bad > 0 && bad / mst > 0.25) return "#fca5a5";
        if (sy / z > 0.35) return "#6ee7b7";
        if (sy / z > 0.08) return "#fcd34d";
        return "#b8ccd8";
      }
      if (layer === "teklif") {
        const tot = +(s.teklif_toplam||0);
        if (!tot) return NO_DATA_COLOR;
        if (teklifM === "kazanma") {
          const pct = +(s.kazanildi||0) / tot * 100;
          if (pct >= 70) return "#16a34a"; if (pct >= 45) return "#4ade80";
          if (pct >= 20) return "#fde68a"; return "#fca5a5";
        }
        if (teklifM === "kaybetme") {
          const pct = +(s.kaybedildi||0) / tot * 100;
          if (pct >= 60) return "#dc2626"; if (pct >= 35) return "#f87171";
          if (pct >= 15) return "#fde68a"; return "#bbf7d0";
        }
        const i = bucketIdx(tot, qs.teklif_toplam);
        return ["#dbeafe","#93c5fd","#3b82f6","#1d4ed8"][i];
      }
      if (layer === "satis") {
        const key = satisM === "tuketici" ? "ciro_tuketici" : satisM === "ticari" ? "ciro_ticari" : "ciro";
        const val = +(s[key]||0);
        if (!val) return NO_DATA_COLOR;
        const i = bucketIdx(val, qs[key] || [1,1,1,1]);
        return ["#ede9fe","#c4b5fd","#7c3aed","#3b0764"][i];
      }
      return NO_DATA_COLOR;
    }

    function ilColor(s, mapColorLayer, satisM, teklifM, qs) {
      const primary = ilColorSingle(s, mapColorLayer, satisM, teklifM, qs);
      if (primary !== NO_DATA_COLOR) return primary;
      if (mapColorLayer !== "ziyaret") {
        const fallback = ilColorSingle(s, "ziyaret", satisM, teklifM, qs);
        if (fallback !== NO_DATA_COLOR) return fallback;
      }
      return NO_DATA_COLOR;
    }

    function fmt(v) {
      if (v == null) return "—";
      const n = Number(v);
      if (n >= 1000000) return (n/1000000).toFixed(1).replace(/\.0$/,"") + "M";
      if (n >= 1000) return (n/1000).toFixed(0) + "K";
      return n.toLocaleString("tr-TR");
    }

    function renderLayerButtons() {
      document.getElementById("ss-layer-bar")?.querySelectorAll(".ss-layer-btn").forEach(btn => {
        const l = btn.dataset.l, active = ssLayers.has(l), driver = ssMapColor === l;
        btn.style.border     = active ? (driver ? "2.5px solid #8b5cf6" : "1.5px solid #a78bfa") : "1.5px solid #e5e7eb";
        btn.style.background = active ? (driver ? "#8b5cf6" : "#ede9fe") : "#fff";
        btn.style.color      = active ? (driver ? "#fff" : "#5b21b6") : "#374151";
        btn.style.fontWeight = active ? "700" : "500";
      });
    }

    function renderLayerSub() {
      const el = document.getElementById("ss-layer-sub"); if (!el) return;
      if (ssMapColor === "satis") {
        const opts = [["tumu","Tümü"],["tuketici","Tüketici"],["ticari","Ticari"]];
        if (!_subInitialized || el.dataset.layer !== "satis") {
          el.dataset.layer = "satis"; _subInitialized = true;
          el.innerHTML = `<div style="display:flex;gap:5px">${opts.map(([v,l]) =>
            `<button class="ss-sub-btn" data-v="${v}" style="flex:1;padding:3px 0;border:1px solid ${v===ssSatisMetrik?"#7c3aed":"#e5e7eb"};background:${v===ssSatisMetrik?"#ede9fe":"#fff"};color:${v===ssSatisMetrik?"#6d28d9":"#374151"};border-radius:6px;font-size:11px;cursor:pointer">${l}</button>`
          ).join("")}</div>`;
          el.querySelectorAll(".ss-sub-btn").forEach(b => b.addEventListener("click", () => {
            ssSatisMetrik = b.dataset.v;
            el.querySelectorAll(".ss-sub-btn").forEach(x => {
              const on = x.dataset.v === ssSatisMetrik;
              x.style.borderColor = on ? "#7c3aed" : "#e5e7eb"; x.style.background = on ? "#ede9fe" : "#fff"; x.style.color = on ? "#6d28d9" : "#374151";
            }); refreshHaritaColors();
          }));
        }
      } else if (ssMapColor === "teklif") {
        const opts = [["toplam","Toplam"],["kazanma","Kazanma"],["kaybetme","Kaybetme"]];
        if (!_subInitialized || el.dataset.layer !== "teklif") {
          el.dataset.layer = "teklif"; _subInitialized = true;
          el.innerHTML = `<div style="display:flex;gap:5px">${opts.map(([v,l]) =>
            `<button class="ss-sub-btn" data-v="${v}" style="flex:1;padding:3px 0;border:1px solid ${v===ssTeklifMetrik?"#1d4ed8":"#e5e7eb"};background:${v===ssTeklifMetrik?"#dbeafe":"#fff"};color:${v===ssTeklifMetrik?"#1e40af":"#374151"};border-radius:6px;font-size:11px;cursor:pointer">${l}</button>`
          ).join("")}</div>`;
          el.querySelectorAll(".ss-sub-btn").forEach(b => b.addEventListener("click", () => {
            ssTeklifMetrik = b.dataset.v;
            el.querySelectorAll(".ss-sub-btn").forEach(x => {
              const on = x.dataset.v === ssTeklifMetrik;
              x.style.borderColor = on ? "#1d4ed8" : "#e5e7eb"; x.style.background = on ? "#dbeafe" : "#fff"; x.style.color = on ? "#1e40af" : "#374151";
            }); refreshHaritaColors();
          }));
        }
      } else if (ssMapColor === "ziyaret") {
        if (!_subInitialized || el.dataset.layer !== "ziyaret") {
          el.dataset.layer = "ziyaret"; _subInitialized = true;
          el.innerHTML = `
            <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;font-size:11px;color:#6b7280">
              <span style="display:inline-flex;align-items:center;gap:3px"><span style="display:inline-block;width:10px;height:10px;background:#fca5a5;border-radius:2px"></span>%25+ sorunlu</span>
              <span style="display:inline-flex;align-items:center;gap:3px"><span style="display:inline-block;width:10px;height:10px;background:#6ee7b7;border-radius:2px"></span>Son 6ay aktif</span>
              <span style="display:inline-flex;align-items:center;gap:3px"><span style="display:inline-block;width:10px;height:10px;background:#fcd34d;border-radius:2px"></span>Orta</span>
              <span style="display:inline-flex;align-items:center;gap:3px"><span style="display:inline-block;width:10px;height:10px;background:#b8ccd8;border-radius:2px"></span>Düşük</span>
              <span style="display:inline-flex;align-items:center;gap:3px"><span style="display:inline-block;width:10px;height:10px;background:#c8d9eb;border-radius:2px"></span>Veri yok</span>
            </div>`;
        }
      } else {
        el.innerHTML = ""; _subInitialized = false;
      }
    }

    function refreshHaritaColors() {
      const rows = [..._haritaData.values()];
      const qs = {
        teklif_toplam: computeQ(rows, "teklif_toplam"),
        ciro:          computeQ(rows, "ciro"),
        ciro_tuketici: computeQ(rows, "ciro_tuketici"),
        ciro_ticari:   computeQ(rows, "ciro_ticari"),
      };
      document.querySelectorAll(".harita-sehir").forEach(path => {
        const ilAdi = normIl(path.dataset.name || "");
        const s     = _haritaData.get(ilAdi);
        path.setAttribute("fill", ilColor(s, ssMapColor, ssSatisMetrik, ssTeklifMetrik, qs));
      });
    }

    // Show city info card
    function showSehirKart(ilAdi) {
      const kart    = document.getElementById("ss-sehir-kart"); if (!kart) return;
      const baslik  = document.getElementById("ss-sehir-baslik");
      const stats   = document.getElementById("ss-sehir-stats");
      const sonuc   = document.getElementById("ss-sehir-sonuc");
      const s = _haritaData.get(ilAdi);
      if (!s) { kart.style.display = "none"; return; }

      if (baslik) baslik.textContent = "📍 " + ilAdi;
      if (sonuc) { sonuc.style.display = "none"; sonuc.innerHTML = ""; }

      const rows = [];
      if (+s.ziyaret > 0) {
        rows.push(`<div><b>${s.ziyaret}</b> ziyaret &nbsp;·&nbsp; <b>${s.musteri}</b> müşteri</div>`);
        if (+s.son_yarim > 0) rows.push(`<div style="color:#10b981">🟢 Son 6 ayda aktif: <b>${s.son_yarim}</b></div>`);
        if (+s.sorunlu > 0)   rows.push(`<div style="color:#ef4444">⚠ Pasif/Riskli: <b>${s.sorunlu}</b></div>`);
      } else {
        rows.push(`<div style="color:#94a3b8">Bu dönemde ziyaret yok</div>`);
      }
      if (+(s.teklif_toplam||0) > 0) {
        const tot = +(s.teklif_toplam||0), kaz = +(s.kazanildi||0), kay = +(s.kaybedildi||0);
        const wr  = tot > 0 ? Math.round(100*kaz/tot) : null;
        rows.push(`<div>💼 <b>${tot}</b> teklif &nbsp;·&nbsp; kazanılan: <b style="color:#10b981">${kaz}</b> &nbsp;·&nbsp; kaybedilen: <b style="color:#ef4444">${kay}</b>${wr!=null?` &nbsp;·&nbsp; win: <b>%${wr}</b>`:""}</div>`);
      }
      const ciro = +(s.ciro||0);
      if (ciro > 0) {
        rows.push(`<div>💰 Satış: <b>${fmt(ciro)}₺</b>${+(s.ciro_tuketici||0)>0?` &nbsp;·&nbsp; tük: ${fmt(+(s.ciro_tuketici||0))}₺`:""}${+(s.ciro_ticari||0)>0?` &nbsp;·&nbsp; tic: ${fmt(+(s.ciro_ticari||0))}₺`:""}</div>`);
      }
      if (stats) stats.innerHTML = rows.join("");
      kart.style.display = "block";
    }

    async function renderTurkeyMap(container, sehirler) {
      if (!_trGeo) {
        const r = await fetch("/tr-geo.json");
        if (!r.ok) throw new Error("İl haritası yüklenemedi");
        _trGeo = await r.json();
      }
      const features = _trGeo.features || [];
      _haritaData = new Map();
      for (const s of sehirler) _haritaData.set(normIl(s.il || ""), s);
      const rows = [..._haritaData.values()];
      const qs = {
        teklif_toplam: computeQ(rows, "teklif_toplam"),
        ciro:          computeQ(rows, "ciro"),
        ciro_tuketici: computeQ(rows, "ciro_tuketici"),
        ciro_ticari:   computeQ(rows, "ciro_ticari"),
      };
      let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
      function walk(geom) {
        if (!geom) return;
        if (geom.type === "Polygon") geom.coordinates.forEach(ring => ring.forEach(([x,y]) => { minX=Math.min(minX,x); maxX=Math.max(maxX,x); minY=Math.min(minY,y); maxY=Math.max(maxY,y); }));
        else if (geom.type === "MultiPolygon") geom.coordinates.forEach(poly => poly.forEach(ring => ring.forEach(([x,y]) => { minX=Math.min(minX,x); maxX=Math.max(maxX,x); minY=Math.min(minY,y); maxY=Math.max(maxY,y); })));
      }
      features.forEach(f => walk(f.geometry));
      // Tight viewBox: Turkey is much wider than tall, so scale by width and compute real height
      const W    = 400;
      const scale = (W / (maxX - minX)) * 0.95;
      const offX  = (W - (maxX - minX) * scale) / 2;
      const PAD   = 12;
      const pH    = Math.ceil((maxY - minY) * scale); // actual projected height
      const vbH   = pH + PAD * 2;
      const offY  = PAD;
      const proj  = ([x,y]) => [offX + (x - minX) * scale, vbH - offY - (y - minY) * scale];
      const coordsToD = coords => coords.map((pt,i) => `${i===0?"M":"L"}${proj(pt).map(v=>v.toFixed(1)).join(",")}`).join(" ") + " Z";
      function featureToPath(geom) {
        if (!geom) return "";
        if (geom.type === "Polygon") return geom.coordinates.map(coordsToD).join(" ");
        if (geom.type === "MultiPolygon") return geom.coordinates.map(poly => poly.map(coordsToD).join(" ")).join(" ");
        return "";
      }
      const paths = features.map(f => {
        const rawName = f.properties?.name || f.properties?.NAME || "";
        const ilAdi   = normIl(rawName);
        const s       = _haritaData.get(ilAdi);
        const fill    = ilColor(s, ssMapColor, ssSatisMetrik, ssTeklifMetrik, qs);
        const d       = featureToPath(f.geometry);
        return d ? `<path class="harita-sehir" data-name="${esc(rawName)}" d="${d}" fill="${fill}" stroke="#fff" stroke-width="0.8" style="cursor:pointer;transition:opacity .1s"/>` : "";
      }).join("");
      container.innerHTML = `<svg viewBox="0 0 ${W} ${vbH}" style="width:100%;display:block">${paths}</svg>`;

      // Re-highlight previously selected city
      if (mapSehir) {
        container.querySelectorAll(".harita-sehir").forEach(p => {
          if (normIl(p.dataset.name||"") === mapSehir) { p.setAttribute("stroke","#1e3a8a"); p.setAttribute("stroke-width","2"); }
        });
      }

      // Hover tooltip
      const tt = document.getElementById("ss-tt");
      container.querySelectorAll(".harita-sehir").forEach(path => {
        path.addEventListener("mousemove", e => {
          if (!tt) return;
          const ilAdi = normIl(path.dataset.name || "");
          const s = _haritaData.get(ilAdi);
          let tip = ilAdi;
          if (s) {
            if (+s.ziyaret > 0) tip += ` · ${s.ziyaret} ziyaret`;
            if (ssLayers.has("teklif") && +(s.teklif_toplam||0) > 0) {
              const wr = +(s.teklif_toplam||0) > 0 ? Math.round(100*(+(s.kazanildi||0))/(+(s.teklif_toplam||0))) : null;
              tip += ` · ${s.teklif_toplam} teklif${wr!=null?" %"+wr+" win":""}`;
            }
            if (ssLayers.has("satis")) {
              const mKey = ssSatisMetrik==="tuketici"?"ciro_tuketici":ssSatisMetrik==="ticari"?"ciro_ticari":"ciro";
              if (+(s[mKey]||0) > 0) tip += ` · ${fmt(+(s[mKey]||0))}₺`;
            }
          }
          tt.textContent = tip;
          tt.style.display = "block";
          tt.style.left = (e.clientX + 14) + "px";
          tt.style.top  = (e.clientY - 34) + "px";
        });
        path.addEventListener("mouseleave", () => { if (tt) tt.style.display = "none"; });

        path.addEventListener("click", () => {
          if (tt) tt.style.display = "none";
          const rawName = path.dataset.name || "";
          const ilAdi   = normIl(rawName);
          mapSehir = ilAdi;
          container.querySelectorAll(".harita-sehir").forEach(c => { c.setAttribute("stroke","#fff"); c.setAttribute("stroke-width","0.8"); });
          path.setAttribute("stroke","#1e3a8a"); path.setAttribute("stroke-width","2");
          showSehirKart(ilAdi);
        });
      });
    }

    async function loadHarita() {
      const el = document.getElementById("ss-harita"); if (!el) return;
      el.innerHTML = `<div style="padding:24px;text-align:center;font-size:12px;color:#94a3b8">Harita yükleniyor…</div>`;
      const kart = document.getElementById("ss-sehir-kart"); if (kart) kart.style.display = "none";
      try {
        const p = new URLSearchParams();
        if (mapDays > 0) {
          const t = new Date(), f = new Date(); f.setDate(f.getDate() - mapDays + 1);
          p.set("from", f.toISOString().slice(0, 10)); p.set("to", t.toISOString().slice(0, 10));
        }
        if (ssEbat) p.set("ebat", ssEbat);
        const { sehirler } = await api("/api/saha/harita?" + p.toString());
        await renderTurkeyMap(el, sehirler || []);
        renderLayerSub(); renderLayerButtons();
        // If a city was selected before reload, re-show its card
        if (mapSehir) showSehirKart(mapSehir);
      } catch(err) {
        el.innerHTML = `<div style="padding:12px;text-align:center;font-size:12px;color:#ef4444">Harita yüklenemedi: ${esc(err?.message||"")}</div>`;
      }
    }
    loadHarita();
    renderLayerButtons();

    // ── Ebat typeahead ──────────────────────────────────────────────────────
    (function() {
      const inp = document.getElementById("ss-ebat");
      const dd  = document.getElementById("ss-ebat-dd");
      const clr = document.getElementById("ss-ebat-clear");
      if (!inp || !dd) return;
      if (ssEbat) { inp.value = ssEbat; if (clr) clr.style.display = ""; }
      let _ebatTimer2 = null;
      inp.addEventListener("input", () => {
        clearTimeout(_ebatTimer2);
        const q = inp.value.trim();
        if (clr) clr.style.display = q ? "" : "none";
        if (q.length < 2) { dd.style.display = "none"; return; }
        _ebatTimer2 = setTimeout(async () => {
          try {
            const { urunler } = await api(`/api/saha/urun-ara?q=${encodeURIComponent(q)}`);
            const ebatlar = [...new Set((urunler || []).map(u => u.ebat_norm).filter(Boolean))]
              .filter(e => e.toLowerCase().includes(q.toLowerCase()))
              .slice(0, 12);
            if (!ebatlar.length) { dd.style.display = "none"; return; }
            dd.innerHTML = ebatlar.map(e =>
              `<div data-ebat="${esc(e)}" style="padding:7px 12px;cursor:pointer;font-size:12px;font-weight:600;color:#374151;border-bottom:1px solid #f1f5f9" onmouseover="this.style.background='#f8fafc'" onmouseout="this.style.background=''">${esc(e)}</div>`
            ).join("");
            dd.querySelectorAll("[data-ebat]").forEach(item => {
              item.addEventListener("mousedown", () => {
                ssEbat = item.dataset.ebat;
                inp.value = ssEbat;
                dd.style.display = "none";
                if (clr) clr.style.display = "";
                loadHarita();
              });
            });
            dd.style.display = "block";
          } catch(_) { dd.style.display = "none"; }
        }, 300);
      });
      inp.addEventListener("blur", () => setTimeout(() => { dd.style.display = "none"; }, 160));
      inp.addEventListener("keydown", e => {
        if (e.key === "Enter") {
          ssEbat = inp.value.trim();
          dd.style.display = "none";
          if (clr) clr.style.display = ssEbat ? "" : "none";
          loadHarita();
        } else if (e.key === "Escape") {
          dd.style.display = "none";
        }
      });
      if (clr) clr.addEventListener("click", () => {
        ssEbat = ""; inp.value = ""; clr.style.display = "none"; dd.style.display = "none";
        loadHarita();
      });
    })();

    // ── Map layer buttons ──
    document.getElementById("ss-layer-bar")?.querySelectorAll(".ss-layer-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        const l = btn.dataset.l;
        if (!ssLayers.has(l)) { ssLayers.add(l); }
        else if (ssMapColor !== l) { ssMapColor = l; }
        else { if (ssLayers.size === 1) return; ssLayers.delete(l); ssMapColor = [...ssLayers][ssLayers.size-1]; }
        _subInitialized = false;
        renderLayerButtons(); renderLayerSub(); refreshHaritaColors();
      });
    });

    // ── Map period buttons ──
    document.getElementById("map-donem-bar")?.querySelectorAll(".map-donem-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        mapDays = Number(btn.dataset.d); mapSehir = null;
        document.querySelectorAll(".map-donem-btn").forEach(b => {
          const on = Number(b.dataset.d) === mapDays;
          b.style.borderColor = on ? "#3b82f6" : "#e5e7eb";
          b.style.background  = on ? "#eff6ff" : "#fff";
          b.style.color       = on ? "#1d4ed8" : "#374151";
          b.style.fontWeight  = on ? "700"     : "400";
        });
        loadHarita();
      });
    });

    // ── AI result cache (localStorage, keyed by scope+period, valid for today) ──
    const _today = () => new Date().toISOString().slice(0, 10);
    function aiCacheGet(key) {
      try {
        const c = JSON.parse(localStorage.getItem("saha-ai-cache") || "{}");
        return c[key]?.date === _today() ? c[key].data : null;
      } catch { return null; }
    }
    function aiCacheSet(key, data) {
      try {
        const c = JSON.parse(localStorage.getItem("saha-ai-cache") || "{}");
        c[key] = { date: _today(), data };
        // Prune: keep only today's entries
        for (const k of Object.keys(c)) { if (c[k].date !== _today()) delete c[k]; }
        localStorage.setItem("saha-ai-cache", JSON.stringify(c));
      } catch {}
    }

    // ── City AI analysis button ──
    document.getElementById("ss-sehir-analiz-btn")?.addEventListener("click", async () => {
      if (!mapSehir) return;
      const btn   = document.getElementById("ss-sehir-analiz-btn");
      const sonuc = document.getElementById("ss-sehir-sonuc");
      if (!btn || !sonuc) return;

      const cacheKey = `sehir:${mapSehir}:${mapDays}`;
      const forceRefresh = btn.dataset.forceRefresh === "1";

      if (!forceRefresh) {
        const cached = aiCacheGet(cacheKey);
        if (cached) {
          sonuc.style.display = "block";
          renderSsJson(sonuc, cached);
          btn.textContent = "✓ Bugün analiz edildi · 🔄 Yenile";
          btn.dataset.forceRefresh = "1";
          return;
        }
      }

      btn.dataset.forceRefresh = "0";
      btn.textContent = "⏳ Analiz ediliyor…"; btn.disabled = true;
      sonuc.style.display = "block";
      sonuc.innerHTML = `<div style="padding:10px;font-size:12px;color:#7c3aed">Ziyaret notları analiz ediliyor…</div>`;
      try {
        const p = new URLSearchParams({ kapsam: "sehir", sehir: mapSehir });
        if (mapDays > 0) {
          const t = new Date(), f = new Date(); f.setDate(f.getDate() - mapDays + 1);
          p.set("from", f.toISOString().slice(0, 10)); p.set("to", t.toISOString().slice(0, 10));
        }
        const result = await api(`/api/saha/ai/saha-sesi?${p}`);
        aiCacheSet(cacheKey, result);
        renderSsJson(sonuc, result);
        btn.textContent = "✓ Analiz edildi · 🔄 Yenile";
        btn.dataset.forceRefresh = "1";
      } catch(e) {
        sonuc.innerHTML = `<div style="color:#ef4444;padding:10px">Hata: ${esc(e.message)}</div>`;
        btn.textContent = "🤖 Bu şehri analiz et";
        btn.dataset.forceRefresh = "0";
      }
      btn.disabled = false;
    });

    // ── Saha Sesi kapsam buttons ──
    document.getElementById("ss-kapsam-bar")?.querySelectorAll(".ss-kapsam-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        ssKapsam = btn.dataset.k;
        document.querySelectorAll(".ss-kapsam-btn").forEach(b => {
          const on = b.dataset.k === ssKapsam;
          b.style.background  = on ? "#8b5cf6" : "#fff";
          b.style.color       = on ? "#fff"    : "#374151";
          b.style.borderColor = on ? "#8b5cf6" : "#e5e7eb";
        });
        renderSsFiltre();
      });
    });

    // ── Saha Sesi period buttons ──
    document.getElementById("ss-donem-bar")?.querySelectorAll(".ss-donem-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        ssDays = Number(btn.dataset.d);
        document.querySelectorAll(".ss-donem-btn").forEach(b => {
          const on = Number(b.dataset.d) === ssDays;
          b.style.borderColor = on ? "#8b5cf6" : "#e5e7eb";
          b.style.background  = on ? "#f5f3ff" : "#fff";
          b.style.color       = on ? "#7c3aed" : "#374151";
          b.style.fontWeight  = on ? "700"     : "400";
        });
      });
    });

    async function renderSsFiltre() {
      const el = document.getElementById("ss-filtre"); if (!el) return;
      if (ssKapsam === "tum" || ssKapsam === "durum") { el.innerHTML = ""; return; }
      if (ssKapsam === "temsilci") {
        el.innerHTML = `<div class="mini-durum">Yükleniyor…</div>`;
        try {
          const { repler } = await api("/api/saha/admin/reps");
          el.innerHTML = `<select class="giris" id="ss-rep" style="font-size:16px;padding:7px 10px">
            <option value="">— Temsilci seçin —</option>
            ${repler.filter(r => r.module_role === "rep").map(r => `<option value="${esc(r.id)}">${esc(r.full_name)}</option>`).join("")}
          </select>`;
        } catch { el.innerHTML = ""; }
        return;
      }
      if (ssKapsam === "musteri") {
        el.innerHTML = `<input class="giris" id="ss-musteri-ara" placeholder="Müşteri adı ara…" style="font-size:16px;padding:7px 10px">
          <div id="ss-musteri-sonuc" style="font-size:12px;color:#6b7280;margin-top:4px"></div>
          <input type="hidden" id="ss-musteri-id">`;
        document.getElementById("ss-musteri-ara")?.addEventListener("input", () => {
          const q   = document.getElementById("ss-musteri-ara").value.trim().toLowerCase();
          const res = document.getElementById("ss-musteri-sonuc"); if (!res) return;
          if (q.length < 2) { res.innerHTML = ""; return; }
          const m = (S.musteriler || []).filter(x => x.firma?.toLowerCase().includes(q)).slice(0, 6);
          res.innerHTML = m.map(x =>
            `<div data-mid="${esc(x.id)}" data-madi="${esc(x.firma)}" style="padding:5px 8px;cursor:pointer;border-radius:6px;margin:2px 0;background:#f8fafc">${esc(x.firma)}</div>`
          ).join("") || "<div style='padding:4px'>Sonuç yok</div>";
          res.querySelectorAll("[data-mid]").forEach(d => d.addEventListener("click", () => {
            document.getElementById("ss-musteri-id").value = d.dataset.mid;
            document.getElementById("ss-musteri-ara").value = d.dataset.madi;
            res.innerHTML = `<span style="color:#10b981">✓ ${esc(d.dataset.madi)} seçildi</span>`;
          }));
        });
      }
    }

    function renderSsJson(sonuc, data) {
      const { json, analiz, not_sayisi, prior_sayisi, aciklama, karsilastirma } = data;
      if (!json) {
        sonuc.innerHTML = `
          <div style="background:#faf5ff;border:1px solid #e9d5ff;border-radius:10px;padding:14px">
            <div style="font-size:11px;color:#7c3aed;font-weight:600;margin-bottom:8px">📊 ${not_sayisi} not · ${esc(aciklama)}</div>
            <div style="white-space:pre-wrap;font-size:13px;line-height:1.6">${esc(analiz||"").replace(/\*\*(.*?)\*\*/g,"<b>$1</b>")}</div>
          </div>`; return;
      }
      const trendBadge = t => {
        if (!t || t === "stabil") return "";
        const map = { yeni:["🆕","#8b5cf6"], artiyor:["↑","#ef4444"], azaliyor:["↓","#10b981"] };
        const [ic, clr] = map[t] || ["","#6b7280"];
        return `<span style="font-size:9px;font-weight:700;color:${clr};margin-left:5px">${ic}</span>`;
      };
      const siklikRenk = s => s==="yüksek"?"#ef4444":s==="orta"?"#f59e0b":"#6b7280";
      sonuc.innerHTML = `
        <div style="background:#faf5ff;border:1px solid #e9d5ff;border-radius:12px;padding:14px">
          <div style="border-bottom:1px solid #e9d5ff;padding-bottom:10px;margin-bottom:12px">
            <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:5px">
              <div style="font-size:11px;color:#7c3aed;font-weight:600">📊 ${not_sayisi} not · ${esc(aciklama)}</div>
              ${karsilastirma ? `<div style="font-size:10px;color:#8b5cf6;font-weight:600">↔ ${prior_sayisi} not önceki dönem</div>` : ""}
            </div>
            ${json.ozet_cumlesi ? `<div style="font-size:14px;font-weight:700;color:#1e1b4b;line-height:1.4;font-style:italic">"${esc(json.ozet_cumlesi)}"</div>` : ""}
          </div>
          ${(json.saha_nabzi||json.nabiz) ? `<div style="font-size:13px;color:#374151;line-height:1.65;margin-bottom:14px">${esc(json.saha_nabzi||json.nabiz)}</div>` : ""}
          ${json.kritik_konular?.length ? `
          <div style="margin-bottom:14px">
            <div style="font-size:11px;font-weight:700;color:#374151;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.4px">🔔 Kritik Konular</div>
            ${json.kritik_konular.map(k => `
            <div style="display:flex;gap:8px;align-items:flex-start;margin-bottom:8px">
              <span style="font-size:10px;font-weight:700;color:${siklikRenk(k.siklik)};padding:2px 6px;border:1px solid currentColor;border-radius:10px;white-space:nowrap;margin-top:1px;flex-shrink:0">${(k.siklik||"?").toUpperCase()}</span>
              <div>
                <div style="font-size:12px;font-weight:600;color:#1f2937">${esc(k.konu)}${trendBadge(k.trend)}${k.kaynak==="her_ikisi"?`<span style="font-size:10px;background:#ede9fe;color:#6d28d9;padding:1px 5px;border-radius:8px;margin-left:5px">✦ sayı+saha</span>`:k.kaynak==="sadece_sayi"?`<span style="font-size:10px;background:#dbeafe;color:#1d4ed8;padding:1px 5px;border-radius:8px;margin-left:5px">📊 sayı</span>`:""}</div>
                <div style="font-size:12px;color:#6b7280;margin-top:1px">${esc(k.detay)}</div>
              </div>
            </div>`).join("")}
          </div>` : ""}
          ${json.kör_noktalar?.length ? `
          <div style="background:#fffbeb;border:1px solid #fde68a;border-radius:10px;padding:12px;margin-bottom:12px">
            <div style="font-size:11px;font-weight:700;color:#b45309;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.4px">🔍 Kör Noktalar</div>
            ${json.kör_noktalar.map(k => `<div style="margin-bottom:6px"><div style="font-size:12px;font-weight:600;color:#78350f">${esc(k.konu)}</div><div style="font-size:12px;color:#92400e;margin-top:1px">${esc(k.detay)}</div></div>`).join("")}
          </div>` : ""}
          ${json.riskli_musteriler?.length ? `
          <div style="background:#fef2f2;border:1px solid #fecaca;border-radius:10px;padding:12px;margin-bottom:12px">
            <div style="font-size:11px;font-weight:700;color:#ef4444;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.4px">⚠ Riskli Müşteriler</div>
            ${json.riskli_musteriler.map(r => `<div style="margin-bottom:6px"><span style="font-size:12px;font-weight:700;color:#7f1d1d">${esc(r.musteri)}</span><span style="font-size:12px;color:#b91c1c"> — ${esc(r.neden)}</span></div>`).join("")}
          </div>` : ""}
          ${json.firsatlar?.length ? `
          <div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:10px;padding:12px;margin-bottom:12px">
            <div style="font-size:11px;font-weight:700;color:#16a34a;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.4px">✨ Fırsatlar</div>
            ${json.firsatlar.map(f => `<div style="margin-bottom:6px"><div style="font-size:12px;font-weight:700;color:#14532d">${esc(f.firsat)}</div><div style="font-size:12px;color:#15803d;margin-top:1px">${esc(f.detay)}</div></div>`).join("")}
          </div>` : ""}
          ${json.temsilci_gozlem ? `
          <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:12px;margin-bottom:12px">
            <div style="font-size:11px;font-weight:700;color:#64748b;margin-bottom:6px;text-transform:uppercase;letter-spacing:0.4px">👁 Temsilci Gözlemi</div>
            <div style="font-size:12px;color:#475569;line-height:1.5">${esc(json.temsilci_gozlem)}</div>
          </div>` : ""}
          ${json.aksiyonlar?.length ? `
          <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:12px;margin-bottom:12px">
            <div style="font-size:11px;font-weight:700;color:#1d4ed8;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.4px">✅ Önerilen Aksiyonlar</div>
            ${json.aksiyonlar.map((a,i) => `<div style="font-size:13px;color:#1e3a8a;margin-bottom:5px;font-weight:500">${i+1}. ${esc(a)}</div>`).join("")}
          </div>` : ""}
          <button id="ss-kopyala" class="btn kucuk cizgili" style="width:100%;border-color:#8b5cf6;color:#8b5cf6">📋 Analizi Kopyala</button>
        </div>`;
      document.getElementById("ss-kopyala")?.addEventListener("click", () => {
        const nabizText = json.saha_nabzi || json.nabiz || "";
        const text = [
          `SAHA SESİ — ${aciklama}`,
          `${not_sayisi} not analiz edildi${karsilastirma?` (önceki dönem: ${prior_sayisi} not)`:""}`,
          json.ozet_cumlesi ? `\n"${json.ozet_cumlesi}"` : "",
          nabizText ? `\n${nabizText}` : "",
          json.kritik_konular?.length  ? `\nKRİTİK KONULAR:\n${json.kritik_konular.map(k=>`• ${k.konu}: ${k.detay}`).join("\n")}` : "",
          json.kör_noktalar?.length    ? `\nKÖR NOKTALAR:\n${json.kör_noktalar.map(k=>`• ${k.konu}: ${k.detay}`).join("\n")}` : "",
          json.riskli_musteriler?.length ? `\nRİSKLİ MÜŞTERİLER:\n${json.riskli_musteriler.map(r=>`• ${r.musteri}: ${r.neden}`).join("\n")}` : "",
          json.firsatlar?.length       ? `\nFIRSATLAR:\n${json.firsatlar.map(f=>`• ${f.firsat}: ${f.detay}`).join("\n")}` : "",
          json.temsilci_gozlem         ? `\nTEMSİLCİ GÖZLEMİ:\n${json.temsilci_gozlem}` : "",
          json.aksiyonlar?.length      ? `\nÖNERİLEN AKSİYONLAR:\n${json.aksiyonlar.map((a,i)=>`${i+1}. ${a}`).join("\n")}` : ""
        ].filter(Boolean).join("\n");
        navigator.clipboard?.writeText(text).then(() => uyari("✓ Analiz panoya kopyalandı", true)).catch(()=>{});
      });
    }

    // ── Saha Sesi analiz button ──
    document.getElementById("ss-analiz-btn")?.addEventListener("click", async () => {
      const btn   = document.getElementById("ss-analiz-btn");
      const sonuc = document.getElementById("ss-sonuc");
      if (!btn || !sonuc) return;
      if (!ssKapsam) { uyari("Önce bir kapsam seçin (Tüm KRB, Temsilci, vb.)"); return; }
      const params = new URLSearchParams({ kapsam: ssKapsam });
      if (ssKapsam === "durum") params.set("durum", "PASIF,RISKLI");
      let subId = "";
      if (ssKapsam === "temsilci") {
        const v = document.getElementById("ss-rep")?.value;
        if (!v) { uyari("Lütfen bir temsilci seçin."); return; }
        params.set("rep_id", v); subId = v;
      }
      if (ssKapsam === "musteri") {
        const v = document.getElementById("ss-musteri-id")?.value;
        if (!v) { uyari("Lütfen bir müşteri seçin."); return; }
        params.set("musteri_id", v); subId = v;
      }
      if (ssDays > 0) {
        const t = new Date(), f = new Date(); f.setDate(f.getDate() - ssDays + 1);
        params.set("from", f.toISOString().slice(0, 10)); params.set("to", t.toISOString().slice(0, 10));
      }
      const cacheKey = `ss:${ssKapsam}:${subId}:${ssDays}`;
      const forceRefresh = btn.dataset.forceRefresh === "1";
      if (!forceRefresh) {
        const cached = aiCacheGet(cacheKey);
        if (cached) {
          sonuc.style.display = "block";
          renderSsJson(sonuc, cached);
          btn.textContent = "✓ Bugün analiz edildi · 🔄 Yenile";
          btn.dataset.forceRefresh = "1";
          return;
        }
      }
      btn.dataset.forceRefresh = "0";
      btn.textContent = "⏳ Analiz ediliyor…"; btn.disabled = true;
      sonuc.style.display = "block";
      sonuc.innerHTML = `<div style="padding:12px;font-size:12px;color:#7c3aed">Notlar toplanıyor ve karşılaştırmalı analiz yapılıyor…</div>`;
      try {
        const result = await api(`/api/saha/ai/saha-sesi?${params}`);
        aiCacheSet(cacheKey, result);
        renderSsJson(sonuc, result);
        btn.textContent = "✓ Analiz edildi · 🔄 Yenile";
        btn.dataset.forceRefresh = "1";
      } catch(e) {
        sonuc.innerHTML = `<div style="color:#ef4444;padding:10px">Hata: ${esc(e.message)}</div>`;
        btn.textContent = "🤖 Saha Sesini Analiz Et";
        btn.dataset.forceRefresh = "0";
      }
      btn.disabled = false;
    });
  }


  // ── Tab switcher ──────────────────────────────────────────────────────────
  const loadTab = tabId => {
    activeTab = tabId;
    main().querySelectorAll(".rp-tab").forEach(btn => {
      const on = btn.dataset.t === tabId;
      btn.style.borderColor  = on ? "#3b82f6" : "#e5e7eb";
      btn.style.borderBottom = on ? "1px solid #fff" : "1px solid #e5e7eb";
      btn.style.background   = on ? "#fff" : "#f9fafb";
      btn.style.color        = on ? "#1d4ed8" : "#6b7280";
      btn.style.fontWeight   = on ? "700" : "500";
    });
    switch(tabId) {
      case "ozet":        rpOzet();        break;
      case "temsilciler": rpTemsilciler(); break;
      case "pipeline":    rpPipeline();    break;
      case "pazar":       rpPazar();       break;
      case "harita":      rpHarita();      break;
    }
  };

  main().querySelectorAll(".rp-tab").forEach(btn => {
    btn.addEventListener("click", () => loadTab(btn.dataset.t));
  });

  main().querySelectorAll(".rp-preset").forEach(btn => {
    btn.addEventListener("click", () => {
      const days = Number(btn.dataset.days);
      const t = new Date(), f = new Date(); f.setDate(f.getDate() - days + 1);
      document.getElementById("rp-from").value = f.toISOString().slice(0, 10);
      document.getElementById("rp-to").value   = t.toISOString().slice(0, 10);
      if (activeTab !== "harita") loadTab(activeTab);
    });
  });

  function shiftRange(dir) {
    const fEl = document.getElementById("rp-from"), tEl = document.getElementById("rp-to");
    const f = new Date(fEl.value + "T12:00:00"), t = new Date(tEl.value + "T12:00:00");
    const diff = Math.round((t - f) / 86400000) + 1;
    f.setDate(f.getDate() + dir * diff); t.setDate(t.getDate() + dir * diff);
    fEl.value = f.toISOString().slice(0, 10); tEl.value = t.toISOString().slice(0, 10);
    if (activeTab !== "harita") loadTab(activeTab);
  }
  document.getElementById("rp-prev").addEventListener("click", () => shiftRange(-1));
  document.getElementById("rp-next").addEventListener("click", () => shiftRange(1));
  document.getElementById("rp-from").addEventListener("change", () => { if (activeTab !== "harita") loadTab(activeTab); });
  document.getElementById("rp-to").addEventListener("change",   () => { if (activeTab !== "harita") loadTab(activeTab); });

  loadTab("ozet");
}


// ── Ortak UI parçaları ───────────────────────────────────────────────────────
function cipSecici(id, liste) {
  return `
  <div class="cipler" id="${id}">
    ${liste.map(x => `<button type="button" class="cip" data-v="${esc(x)}">${esc(x)}</button>`).join("")}
    <input class="cip-ekle" placeholder="+ diğer" size="8">
  </div>`;
}
function cipDegerler(id) {
  const kutu = document.getElementById(id);
  if (!kutu) return [];
  return [...kutu.querySelectorAll(".cip.on")].map(b => b.dataset.v);
}
function cipleriBagla(kok) {
  kok.querySelectorAll(".cipler").forEach(kutu => {
    kutu.querySelectorAll(".cip").forEach(b => {
      if (!b.dataset.bagli) {
        b.dataset.bagli = "1";
        b.addEventListener("click", () => b.classList.toggle("on"));
      }
    });
    const inp = kutu.querySelector(".cip-ekle");
    if (inp && !inp.dataset.bagli) {
      inp.dataset.bagli = "1";
      inp.addEventListener("keydown", ev => {
        if (ev.key === "Enter" && inp.value.trim()) {
          ev.preventDefault();
          const v = inp.value.trim();
          const b = document.createElement("button");
          b.type = "button"; b.className = "cip on"; b.dataset.v = v; b.textContent = v;
          b.addEventListener("click", () => b.classList.toggle("on"));
          kutu.insertBefore(b, inp);
          inp.value = "";
        }
      });
    }
  });
}

// ── Ses girişi — tüm textarea.giris elemanlarına otomatik mikrofon butonu ──
function sesGirisBagla(kok) {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) return; // unsupported browser
  kok.querySelectorAll("textarea.giris").forEach(ta => {
    if (ta.dataset.sesBagli) return;
    ta.dataset.sesBagli = "1";
    // Wrap textarea in relative container
    const wrap = document.createElement("div");
    wrap.className = "ses-wrap";
    ta.parentNode.insertBefore(wrap, ta);
    wrap.appendChild(ta);
    // Mic button
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "ses-btn";
    btn.title = "Sesle gir (Türkçe)";
    btn.innerHTML = "🎙";
    wrap.appendChild(btn);
    let rec = null;
    btn.addEventListener("click", () => {
      if (rec) { rec.stop(); return; }
      rec = new SR();
      rec.lang = "tr-TR";
      rec.continuous = true;
      rec.interimResults = false;
      btn.classList.add("dinliyor");
      rec.onresult = ev => {
        const metin = Array.from(ev.results).map(r => r[0].transcript).join(" ").trim();
        if (metin) {
          ta.value = ta.value ? ta.value + " " + metin : metin;
          ta.dispatchEvent(new Event("input", { bubbles: true }));
        }
      };
      rec.onerror = () => { btn.classList.remove("dinliyor"); rec = null; };
      rec.onend  = () => { btn.classList.remove("dinliyor"); rec = null; };
      rec.start();
    });
  });
}

function modal(html) {
  const kok = document.getElementById("saha-modal");
  kok.innerHTML = `<div class="modal-fon"><div class="modal-kutu">${html}</div></div>`;
  kok.querySelector(".modal-fon").addEventListener("click", ev => { if (ev.target.classList.contains("modal-fon")) kapatModal(); });
  kok.querySelectorAll("[data-kapat]").forEach(b => b.addEventListener("click", kapatModal));
  cipleriBagla(kok);
  sesGirisBagla(kok);
}
function kapatModal() { const k = document.getElementById("saha-modal"); if (k) k.innerHTML = ""; }
window.kapatModal = kapatModal;

// ── Pipeline teklif listesi (rapor → pipeline kartlarına tıkınca açılır) ──────
window.pipelineTeklifListesi = async function(durum, baslik) {
  const from = window._pipelineFrom || "";
  const to   = window._pipelineTo   || "";
  const renk = durum === "KAZANILDI" ? "#10b981" : "#ef4444";
  const modal = document.getElementById("saha-modal");
  if (!modal) return;

  // Bottom-sheet overlay
  modal.innerHTML = `
    <div style="position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;flex-direction:column;justify-content:flex-end"
         id="ptl-overlay" onclick="if(event.target===this)kapatModal()">
      <div style="background:#f8fafc;border-radius:16px 16px 0 0;max-height:80vh;display:flex;flex-direction:column;overflow:hidden">
        <!-- Header -->
        <div style="display:flex;align-items:center;justify-content:space-between;padding:14px 16px;border-bottom:1px solid #e5e7eb;background:#fff">
          <div>
            <div style="font-size:15px;font-weight:700;color:#111827">${baslik}</div>
            <div style="font-size:11px;color:#6b7280;margin-top:2px">${from} → ${to}</div>
          </div>
          <button onclick="kapatModal()" style="padding:8px 14px;border:none;border-radius:8px;background:#f1f5f9;color:#374151;font-size:13px;font-weight:600;cursor:pointer;min-width:56px">✕ Kapat</button>
        </div>
        <!-- Body -->
        <div id="ptl-body" style="overflow-y:auto;padding:12px;flex:1">
          <div class="saha-load">Yükleniyor…</div>
        </div>
        <!-- Footer close -->
        <div style="padding:12px 16px;padding-bottom:calc(12px + env(safe-area-inset-bottom,0px));background:#fff;border-top:1px solid #e5e7eb">
          <button onclick="kapatModal()" style="width:100%;padding:13px;border:none;border-radius:12px;background:#0f172a;color:#fff;font-size:15px;font-weight:700;cursor:pointer">Kapat</button>
        </div>
      </div>
    </div>`;

  try {
    let qs = `/api/saha/teklifler?durum=${durum}&limit=200`;
    if (from) qs += `&from=${from}`;
    if (to)   qs += `&to=${to}`;
    const { teklifler } = await api(qs);
    const body = document.getElementById("ptl-body");
    if (!body) return;
    if (!teklifler?.length) {
      body.innerHTML = `<div class="saha-bos">Bu dönemde ${durum === "KAZANILDI" ? "kazanılan" : "kaybedilen"} teklif yok.</div>`;
      return;
    }
    const toplam = teklifler.reduce((s, t) => s + Number(t.toplam_tutar || 0), 0);
    body.innerHTML = `
      <div style="font-size:12px;color:#6b7280;margin-bottom:10px;font-weight:600">
        ${teklifler.length} teklif · Toplam <span style="color:${renk}">${toplam.toLocaleString("tr-TR")}₺</span>
      </div>
      <div style="display:flex;flex-direction:column;gap:8px">
        ${teklifler.map(t => {
          const [dl, dc] = TEKLIF_DURUM[t.durum] || [t.durum, "#999"];
          const tarih = t.updated_at ? new Date(t.updated_at).toLocaleDateString("tr-TR") : "—";
          const kalemler = (() => {
            if (Array.isArray(t.kalemler) && t.kalemler.length) return t.kalemler;
            if (typeof t.kalemler === "string") {
              try { const p = JSON.parse(t.kalemler); if (Array.isArray(p)) return p; } catch(_){}
            }
            return t.marka ? [{ marka: t.marka, ebat: t.ebat, adet: t.adet }] : [];
          })();
          const markalar = [...new Set(kalemler.map(k => k.marka).filter(Boolean))].join(", ") || esc(t.marka) || "—";
          return `
          <div onclick="kapatModal();teklifDetayModal(${JSON.stringify(t).replace(/"/g,'&quot;')})"
               style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:12px;cursor:pointer;active:background:#f9fafb">
            <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:6px">
              <div>
                <div style="font-size:13px;font-weight:700;color:#111827">${esc(t.firma)}</div>
                <div style="font-size:11px;color:#6b7280">${esc(t.il||"")}${t.musteri_kodu?" · #"+esc(t.musteri_kodu):""}</div>
              </div>
              <div style="text-align:right">
                <div style="font-size:14px;font-weight:700;color:${renk}">${Number(t.toplam_tutar||0).toLocaleString("tr-TR")}₺</div>
                <div style="font-size:10px;color:#94a3b8">${tarih}</div>
              </div>
            </div>
            <div style="display:flex;gap:6px;align-items:center;flex-wrap:wrap">
              <span style="font-size:11px;background:#f3f4f6;border-radius:6px;padding:2px 7px">${markalar}</span>
              ${t.kalem_sayisi > 1 ? `<span style="font-size:10px;color:#6b7280">${t.kalem_sayisi} kalem</span>` : ""}
              ${t.rep_full_name ? `<span style="font-size:10px;color:#6b7280;margin-left:auto">👤 ${esc(t.rep_full_name)}</span>` : ""}
            </div>
            ${durum === "KAYBEDILDI" && t.rakip_marka ? `
            <div style="margin-top:6px;font-size:11px;color:#ef4444">🏁 ${esc(t.rakip_marka)}${t.rakip_model?" · "+esc(t.rakip_model):""}</div>` : ""}
            ${durum === "KAYBEDILDI" && t.kayip_nedeni ? `
            <div style="font-size:11px;color:#f59e0b">⚠ ${KAYIP_NEDEN[t.kayip_nedeni]||esc(t.kayip_nedeni)}</div>` : ""}
          </div>`;
        }).join("")}
      </div>`;
  } catch(e) {
    const body = document.getElementById("ptl-body");
    if (body) body.innerHTML = hata(e);
  }
};

function uyari(mesaj, basari = false) {
  const el = document.createElement("div");
  el.className = "saha-toast" + (basari ? " ok" : "");
  el.textContent = mesaj;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3500);
}
// ── RAKIP FIYATLAR (SAHA_RAKIP_V2) ───────────────────────────────────────────
// UST SEVIYE olmali — dispatch (satir ~294) sadece kolon-0 fonksiyonlari gorur.
// V1'de bunu Rapor closure'ina koydum: "Can't find variable: vRakip" -> kabuk olmustu.
// TAZELIK_V1 — "ne zaman cekildi" her fiyatin YANINDA olmali.
function rkTazelik(ts) {
  if (!ts) return '<span style="color:#9ca3af">tarih yok</span>';
  const t = new Date(ts).getTime();
  if (isNaN(t)) return '<span style="color:#9ca3af">tarih yok</span>';
  const dk = Math.floor((Date.now() - t) / 60000);
  let metin, renk;
  if (dk < 60)          { metin = dk + " dk önce";              renk = "#059669"; }
  else if (dk < 1440)   { metin = Math.floor(dk / 60) + " saat önce"; renk = "#059669"; }
  else {
    const g = Math.floor(dk / 1440);
    metin = g + " gün önce";
    renk = g <= 1 ? "#059669" : (g <= 3 ? "#d97706" : "#dc2626");
  }
  const uyari = dk > 4320 ? ' ⚠' : '';   // 3 gunden eski
  return '<span style="color:' + renk + ';font-weight:600">🕐 ' + metin + uyari + '</span>';
}

async function vRakip() {
  const m = main();
  m.innerHTML = `
    <div style="padding:10px 12px">
      <div style="display:flex;gap:4px;margin-bottom:10px;overflow-x:auto">
        <button class="rkt on" data-t="ara"   style="white-space:nowrap;padding:7px 12px;border:1px solid #3b82f6;background:#3b82f6;color:#fff;border-radius:8px;font-size:12px;font-weight:600;cursor:pointer">🔍 Fiyat Ara</button>
        <button class="rkt"    data-t="trend" style="white-space:nowrap;padding:7px 12px;border:1px solid #e5e7eb;background:#f9fafb;color:#6b7280;border-radius:8px;font-size:12px;font-weight:600;cursor:pointer">📈 Trend</button>
        <button class="rkt"    data-t="dot"   style="white-space:nowrap;padding:7px 12px;border:1px solid #e5e7eb;background:#f9fafb;color:#6b7280;border-radius:8px;font-size:12px;font-weight:600;cursor:pointer">📅 Eski Üretim</button>
      </div>
      <div id="rk-bilgi" style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:10px 12px;margin-bottom:12px;font-size:12px;color:#1e40af">
        <b>İnternet piyasası.</b> Müşterinin telefonunda gördüğü fiyat. Marka veya ebat girin.
      </div>
      <div style="display:flex;gap:6px;margin-bottom:8px">
        <input id="rk-marka" class="giris" placeholder="Marka (Lassa…)" style="flex:1;font-size:16px">
        <input id="rk-ebat" class="giris" placeholder="Ebat (205/55R16)" style="flex:1;font-size:16px">
      </div>
      <div style="display:flex;gap:6px;margin-bottom:10px">
        <select id="rk-seg" class="giris" style="flex:1;font-size:15px">
          <option value="">Tümü</option>
          <option value="TUKETICI">🚗 Binek</option>
          <option value="TICARI">🚚 Ticari (kamyon/van)</option>
        </select>
        <button class="btn" id="rk-ara" style="flex-shrink:0">Ara</button>
      </div>
      <div id="rk-sonuc"></div>
    </div>`;

  const ara = async () => {
    const marka = (document.getElementById("rk-marka") || {}).value || "";
    const ebat  = (document.getElementById("rk-ebat")  || {}).value || "";
    const seg   = (document.getElementById("rk-seg")   || {}).value || "";
    const box   = document.getElementById("rk-sonuc");
    if (!box) return;
    if (!marka.trim() && !ebat.trim()) { box.innerHTML = '<div class="saha-bos">Marka veya ebat girin.</div>'; return; }
    box.innerHTML = '<div class="saha-load">Aranıyor…</div>';
    try {
      const qs = new URLSearchParams({ limit: "300" });
      if (marka.trim()) qs.set("marka", marka.trim());
      if (ebat.trim())  qs.set("ebat", ebat.trim());
      if (seg)          qs.set("segment", seg);
      const d = await api("/api/rakip/piyasa?" + qs.toString());
      const rows = (d && d.rows) || [];
      if (!rows.length) {
        box.innerHTML = '<div class="saha-bos">İnternette ilan bulunamadı.<br>'
          + '<span style="font-size:11px;color:#94a3b8">Veri yok = rakip yok DEĞİL. Taramamız bu üründe dar olabilir.</span></div>';
        return;
      }
      const grup = {};
      rows.forEach(function(r) {
        const eb = r.genislik
          ? (r.profil == null ? r.genislik + "R" + r.cap : r.genislik + "/" + r.profil + "R" + r.cap)
          : "—";
        const k = (r.marka || "?") + "|" + (r.desen || "") + "|" + eb;
        if (!grup[k]) grup[k] = { marka: r.marka, ebat: eb, model: r.model, segment: r.segment, ilan: [] };
        grup[k].ilan.push(r);
      });
      // SIRALAMA_V1: EN YENI cekilen urun en ustte. (Once ilan sayisina gore siralaniyordu;
      // temsilci en taze fiyati gormeli — bayat bir urun cok ilanli diye ustte kalmamali.)
      const _sonCekim = function(g) {
        const z = g.ilan.map(function(x) { return x.scraped_at ? new Date(x.scraped_at).getTime() : 0; });
        return Math.max.apply(null, z.length ? z : [0]);
      };
      const liste = Object.keys(grup).map(function(k) { return grup[k]; })
        .sort(function(a, b) {
          const d = _sonCekim(b) - _sonCekim(a);
          return d !== 0 ? d : (b.ilan.length - a.ilan.length);
        }).slice(0, 25);
      const tl = function(n) { return Number(n).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺"; };

      box.innerHTML = liste.map(function(g) {
        const fs = g.ilan.map(function(x) { return parseFloat(x.fiyat); })
          .filter(function(x) { return !isNaN(x); }).sort(function(a, b) { return a - b; });
        if (!fs.length) return "";
        const enUcuz = fs[0], enPahali = fs[fs.length - 1], medyan = fs[Math.floor(fs.length / 2)];
        const kaynak = Object.keys(g.ilan.reduce(function(a, x) { a[x.kaynak] = 1; return a; }, {}));
        // TAZELIK_V1: bu urunun fiyatlari NE ZAMAN cekildi?
        const zamanlar = g.ilan.map(function(x) { return x.scraped_at; })
          .filter(Boolean).map(function(z) { return new Date(z).getTime(); })
          .filter(function(z) { return !isNaN(z); }).sort(function(a, b) { return b - a; });
        const enTaze = zamanlar.length ? zamanlar[0] : null;
        const enEski = zamanlar.length ? zamanlar[zamanlar.length - 1] : null;
        const bayat  = enTaze && (Date.now() - enTaze) > 3 * 86400000;
        const eski = g.ilan.filter(function(x) { return x.uretim_yili && x.uretim_yili <= 2023; });
        const ucuzIlan = g.ilan.filter(function(x) { return parseFloat(x.fiyat) === enUcuz; })[0] || {};
        return '<div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:10px 12px;margin-bottom:8px">'
          + '<div style="display:flex;justify-content:space-between;gap:8px">'
          +   '<div style="min-width:0">'
          +     '<div style="font-weight:700;font-size:14px;color:#111">' + esc(g.marka)
          +       ' <span style="color:#6b7280;font-weight:500">' + esc((g.model || "").slice(0, 32)) + '</span></div>'
          +     '<div style="font-family:monospace;font-size:12px;color:#6b7280;margin-top:2px">' + esc(g.ebat)
          +       (g.segment && g.segment !== "BINEK"
                    ? ' <span style="background:#fef3c7;color:#92400e;border-radius:4px;padding:1px 5px;font-size:10px">🚚 Ticari</span>' : "")
          +     '</div>'
          +   '</div>'
          +   '<div style="text-align:right;flex-shrink:0">'
          +     '<div style="font-size:18px;font-weight:800;color:#059669">' + tl(enUcuz) + '</div>'
          +     '<div style="font-size:10px;color:#9ca3af">en ucuz</div>'
          +   '</div>'
          + '</div>'
          + '<div style="display:flex;gap:10px;margin-top:8px;font-size:11px;color:#6b7280;flex-wrap:wrap">'
          +   '<span>medyan <b style="color:#374151">' + tl(medyan) + '</b></span>'
          +   '<span>en yüksek <b style="color:#374151">' + tl(enPahali) + '</b></span>'
          +   '<span>' + fs.length + ' ilan · ' + kaynak.length + ' pazaryeri</span>'
          + '</div>'
          + '<div style="margin-top:6px;padding-top:6px;border-top:1px dashed #e5e7eb;font-size:11px;display:flex;justify-content:space-between;align-items:center;gap:6px;flex-wrap:wrap">'
          +   '<span>' + rkTazelik(enTaze ? new Date(enTaze).toISOString() : null) + '</span>'
          +   (enEski && enTaze && (enTaze - enEski) > 86400000
                ? '<span style="color:#9ca3af">en eski ilan: ' + rkTazelik(new Date(enEski).toISOString()) + '</span>' : '')
          + '</div>'
          + (bayat
              ? '<div style="margin-top:6px;background:#fef2f2;border:1px solid #fecaca;border-radius:6px;padding:5px 8px;font-size:11px;color:#b91c1c">'
                + '⚠ <b>Bu fiyat 3 günden eski.</b> Müşteriye söylemeden önce ilanı açıp doğrulayın.</div>' : '')
          + (eski.length
              ? '<div style="margin-top:6px;background:#fef2f2;border-radius:6px;padding:5px 8px;font-size:11px;color:#b91c1c">⚠ '
                + eski.length + ' ilan <b>' + Math.min.apply(null, eski.map(function(x) { return x.uretim_yili; }))
                + ' üretim</b> — ucuzsa sebebi bu olabilir. Müşteriye söyleyin.</div>' : "")
          + (fs.length < 5
              ? '<div style="margin-top:6px;font-size:11px;color:#92400e">⚠ Az ilan (' + fs.length + ') — kesin yorum yapmayın.</div>' : "")
          + (ucuzIlan.url
              ? '<a href="' + esc(ucuzIlan.url) + '" target="_blank" rel="noopener noreferrer" '
                + 'style="display:inline-block;margin-top:8px;font-size:11px;color:#2563eb;text-decoration:none">'
                + 'En ucuz ilanı aç ↗ (' + esc(ucuzIlan.kaynak || "") + ')</a>' : "")
          + '</div>';
      }).join("");
    } catch (e) {
      box.innerHTML = '<div class="saha-bos" style="color:#dc2626">Hata: ' + esc((e && e.message) || "bilinmiyor") + '</div>';
    }
  };
  // ── TREND: son 30 gunde fiyat yukseliyor mu, dusuyor mu ──
  const trend = async function() {
    const ebat = ((document.getElementById("rk-ebat") || {}).value || "").trim();
    const marka = ((document.getElementById("rk-marka") || {}).value || "").trim();
    const box = document.getElementById("rk-sonuc");
    if (!box) return;
    if (!ebat) { box.innerHTML = '<div class="saha-bos">Trend için EBAT girin (örn 205/55R16).</div>'; return; }
    box.innerHTML = '<div class="saha-load">Trend çıkarılıyor…</div>';
    try {
      const qs = new URLSearchParams({ ebat: ebat, gun: "30", grup: "piyasa" });
      if (marka) qs.set("marka", marka);
      const d = await api("/api/rakip/trend?" + qs.toString());
      const seri = (d && (d.seri || d.noktalar || d.rows)) || [];
      if (seri.length < 3) {
        box.innerHTML = '<div class="saha-bos">Bu ebatta trend için yeterli gün yok.<br>'
          + '<span style="font-size:11px;color:#94a3b8">Az veri = fiyat sabit DEĞİL. Yorum yapmayın.</span></div>';
        return;
      }
      const val = function(x) { return Number(x.medyan != null ? x.medyan : (x.p50 != null ? x.p50 : x.fiyat)); };
      const ilk = val(seri[0]), son = val(seri[seri.length - 1]);
      const pct = Math.round((son - ilk) / ilk * 100);
      const yon = pct > 3 ? { t: "YÜKSELİYOR", c: "#dc2626", i: "↗" }
                : pct < -3 ? { t: "DÜŞÜYOR", c: "#059669", i: "↘" }
                : { t: "YATAY", c: "#6b7280", i: "→" };
      const fs = seri.map(val).filter(function(x) { return !isNaN(x); });
      const mn = Math.min.apply(null, fs), mx = Math.max.apply(null, fs);
      const W = 300, H = 70;
      const pts = fs.map(function(v, i) {
        const x = (i / Math.max(fs.length - 1, 1)) * W;
        const y = H - ((v - mn) / Math.max(mx - mn, 1)) * H;
        return x.toFixed(0) + "," + y.toFixed(0);
      }).join(" ");
      const tl = function(n) { return Number(n).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺"; };
      box.innerHTML = '<div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:12px">'
        + '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">'
        +   '<div style="font-weight:700;font-size:14px">' + esc(ebat) + (marka ? " · " + esc(marka) : "") + '</div>'
        +   '<div style="font-size:15px;font-weight:800;color:' + yon.c + '">' + yon.i + " %" + Math.abs(pct) + '</div>'
        + '</div>'
        + '<div style="font-size:12px;color:' + yon.c + ';font-weight:600;margin-bottom:8px">Son 30 gün: fiyat ' + yon.t + '</div>'
        + '<svg viewBox="0 0 ' + W + ' ' + H + '" style="width:100%;height:70px">'
        +   '<polyline points="' + pts + '" fill="none" stroke="' + yon.c + '" stroke-width="2"/>'
        + '</svg>'
        + '<div style="display:flex;justify-content:space-between;font-size:11px;color:#6b7280;margin-top:6px">'
        +   '<span>' + tl(ilk) + ' <span style="color:#9ca3af">(30 gün önce)</span></span>'
        +   '<span><b style="color:#111">' + tl(son) + '</b> bugün</span>'
        + '</div>'
        + '<div style="margin-top:10px;font-size:11px;color:#6b7280;background:#f9fafb;border-radius:6px;padding:7px 9px">'
        +   (pct > 3 ? 'Fiyat yükseliyor — müşteriye "şimdi alın" demek için gerçek bir gerekçeniz var.'
             : pct < -3 ? 'Fiyat düşüyor — müşteri beklemek isteyebilir. Buna hazır olun.'
             : 'Fiyat yatay — acele ettirecek bir hareket yok.')
        + '</div></div>';
    } catch (e) {
      box.innerHTML = '<div class="saha-bos" style="color:#dc2626">Hata: ' + esc((e && e.message) || "?") + '</div>';
    }
  };

  // ── ESKI URETIM (DOT): rakip eski stok bosaltiyor mu ──
  const dot = async function() {
    const marka = ((document.getElementById("rk-marka") || {}).value || "").trim();
    const ebat  = ((document.getElementById("rk-ebat")  || {}).value || "").trim();
    const box = document.getElementById("rk-sonuc");
    if (!box) return;
    box.innerHTML = '<div class="saha-load">Eski üretim taranıyor…</div>';
    try {
      const qs = new URLSearchParams({ min_indirim: "20" });
      if (marka) qs.set("marka", marka);
      if (ebat)  qs.set("ebat", ebat);
      const d = await api("/api/rakip/dot?" + qs.toString());
      const f = (d && d.firsatlar) || [];
      if (!f.length) {
        box.innerHTML = '<div class="saha-bos">Bu aramada eski üretim indirimi bulunamadı.</div>';
        return;
      }
      const tl = function(n) { return Number(n).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺"; };
      box.innerHTML = '<div style="background:#fffbeb;border:1px solid #fde68a;border-radius:8px;padding:8px 10px;margin-bottom:10px;font-size:11.5px;color:#92400e">'
        + '<b>Rakip eski üretim stoğunu indirimle boşaltıyor.</b> Müşteri bu fiyatı görüp size gelebilir. '
        + 'Fark üretim yılından — bunu <b>anlatın</b>, bizim lastiğimiz yeniyse bu bir <b>avantaj</b>.</div>'
        + f.slice(0, 20).map(function(r) {
          return '<div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:10px 12px;margin-bottom:8px">'
            + '<div style="font-weight:700;font-size:13.5px">' + esc(r.marka) + ' <span style="color:#6b7280;font-weight:500">' + esc(r.desen || "") + '</span></div>'
            + '<div style="font-family:monospace;font-size:12px;color:#6b7280;margin:2px 0 8px">' + esc(r.ebat) + '</div>'
            + '<div style="display:flex;align-items:center;gap:8px;font-size:12px">'
            +   '<span style="background:#fee2e2;color:#b91c1c;border-radius:5px;padding:2px 7px;font-weight:700">' + r.eski_yil + '</span>'
            +   '<b style="color:#b91c1c">' + tl(r.eski_fiyat) + '</b>'
            +   '<span style="color:#9ca3af">→</span>'
            +   '<span style="background:#dcfce7;color:#166534;border-radius:5px;padding:2px 7px;font-weight:700">' + r.yeni_yil + '</span>'
            +   '<b style="color:#166534">' + tl(r.yeni_fiyat) + '</b>'
            +   '<span style="margin-left:auto;font-weight:800;color:#dc2626">−%' + r.indirim + '</span>'
            + '</div>'
            + '<div style="margin-top:6px;font-size:11px;color:#6b7280">' + esc(r.eski_kaynak || "") + ' üzerinde'
            + (r.eski_url ? ' · <a href="' + esc(r.eski_url) + '" target="_blank" rel="noopener noreferrer" style="color:#2563eb;text-decoration:none">ilanı aç ↗</a>' : "")
            + '</div>'
            + '<div style="margin-top:4px;font-size:11px">' + rkTazelik(r.scraped_at || r.son_gorulme) + '</div>'
            + '</div>';
        }).join("");
    } catch (e) {
      box.innerHTML = '<div class="saha-bos" style="color:#dc2626">Hata: ' + esc((e && e.message) || "?") + '</div>';
    }
  };

  // ── alt sekme gecisi ──
  let mod = "ara";
  const bilgiler = {
    ara:   '<b>İnternet piyasası.</b> Müşterinin telefonunda gördüğü fiyat. Marka veya ebat girin.',
    trend: '<b>Fiyat trendi.</b> Son 30 günde yükseliyor mu, düşüyor mu? <b>Ebat girin.</b>',
    dot:   '<b>Eski üretim.</b> Rakip 2023 ve öncesi stoğu indirimle boşaltıyor mu? Marka/ebat opsiyonel.'
  };
  const calistir = function() {
    if (mod === "trend") trend();
    else if (mod === "dot") dot();
    else ara();
  };
  Array.prototype.forEach.call(document.querySelectorAll(".rkt"), function(b) {
    b.addEventListener("click", function() {
      mod = b.getAttribute("data-t");
      Array.prototype.forEach.call(document.querySelectorAll(".rkt"), function(x) {
        const on = x === b;
        x.style.background = on ? "#3b82f6" : "#f9fafb";
        x.style.color = on ? "#fff" : "#6b7280";
        x.style.borderColor = on ? "#3b82f6" : "#e5e7eb";
      });
      const bi = document.getElementById("rk-bilgi");
      if (bi) bi.innerHTML = bilgiler[mod];
      const box = document.getElementById("rk-sonuc");
      if (box) box.innerHTML = "";
      if (mod === "dot") calistir();
    });
  });

  const btn = document.getElementById("rk-ara");
  if (btn) btn.addEventListener("click", calistir);
  ["rk-marka", "rk-ebat"].forEach(function(id) {
    const el = document.getElementById(id);
    if (el) el.addEventListener("keydown", function(ev) { if (ev.key === "Enter") calistir(); });
  });
}

// ── DUYURULAR ────────────────────────────────────────────────────────────────
async function vPiyasa() {
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
  // ⚠ UC_ARIZA_V1 — 'g' bu kapsamda TANIMLI DEGILDI.
  //   Eftal 14 Tem 10:17 ve 10:23'te 16 kez denedi: "Can't find variable: g".
  //   Piyasa ekraninin UC BUTONU DA bu yuzden oluydu.
  const g = id => document.getElementById(id)?.value.trim() || "";
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
  // ⚠ UC_ARIZA_V1 — 'g' bu kapsamda da yoktu.
  const g = id => document.getElementById(id)?.value.trim() || "";
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
  // ⚠ UC_ARIZA_V1 — 'g' bu kapsamda da yoktu.
  const g = id => document.getElementById(id)?.value.trim() || "";
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

async function vDuyurular() {
  try {
    const { duyurular, rep_sayisi } = await api("/api/saha/duyurular");
    const isYonetici = S.role !== "rep";
    const okunmamis = duyurular.filter(d => !d.okundu).length;
    tabBadge("duyurular", isYonetici ? 0 : okunmamis);

    const onemRenk = { ACIL: "#ef4444", YUKSEK: "#f59e0b" };
    const onemEtiket = { ACIL: "🚨 Acil", YUKSEK: "⚠️ Önemli" };

    main().innerHTML = `
      <button class="saha-cta" id="yeni-duyuru">📢 Yeni Paylaşım</button>
      ${duyurular.length ? duyurular.map(d => {
        const tarih = new Date(d.created_at).toLocaleDateString("tr-TR", { day: "numeric", month: "short" });
        const unread = !d.okundu && !isYonetici;
        return `<div class="kart" data-did="${d.id}" style="${unread ? "border-left:3px solid #0284c7;" : ""}">
          <div class="kart-ust">
            <b>${esc(d.baslik)}</b>
            <span style="display:flex;gap:4px;align-items:center">
              ${d.tip === "PIYASA" ? `<span class="rozet" style="background:#0891b2">📊 Piyasa</span>` : ""}${d.onem !== "NORMAL" ? `<span class="rozet" style="background:${onemRenk[d.onem]}">${onemEtiket[d.onem]}</span>` : ""}
              ${unread ? `<span class="rozet" style="background:#0284c7">Yeni</span>` : ""}
            </span>
          </div>
          <div class="kart-alt">
            <span>${esc(d.yazan_adi)}</span><span>${tarih}</span>
            ${Number(d.yorum_sayisi) ? `<span>💬 ${d.yorum_sayisi}</span>` : ""}
            ${isYonetici ? `<span>👁 ${d.okuyan_sayisi}/${rep_sayisi}</span>` : ""}
          </div>
        </div>`;
      }).join("") : `<div class="saha-bos">Henüz duyuru yok.</div>`}
    `;

    main().querySelector("#yeni-duyuru")?.addEventListener("click", yeniDuyuruModal);
    main().querySelectorAll("[data-did]").forEach(el =>
      el.addEventListener("click", () => duyuruDetayModal(el.dataset.did)));
  } catch (e) { main().innerHTML = hata(e); }
}

function yeniDuyuruModal() {
  modal(`
    <h3>Yeni Paylaşım</h3>
    <label class="etiket">Tür</label>
    <select id="dy-tip" class="giris">
      <option value="DUYURU">📢 Duyuru</option>
      <option value="PIYASA">📊 Piyasa Bilgisi</option>
    </select>
    <label class="etiket">Başlık *</label>
    <input id="dy-baslik" class="giris" placeholder="Duyuru başlığı…">
    <label class="etiket">Önem Seviyesi</label>
    <select id="dy-onem" class="giris">
      <option value="NORMAL">Normal</option>
      <option value="YUKSEK">⚠️ Önemli</option>
      <option value="ACIL">🚨 Acil</option>
    </select>
    <label class="etiket">İçerik *</label>
    <textarea id="dy-icerik" class="giris" rows="5" placeholder="Duyuru metni…"></textarea>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>İptal</button>
      <button class="btn" id="dy-kaydet">Yayınla</button>
    </div>`);
  document.getElementById("dy-kaydet").addEventListener("click", async () => {
    const baslik = document.getElementById("dy-baslik").value.trim();
    const icerik = document.getElementById("dy-icerik").value.trim();
    const onem = document.getElementById("dy-onem").value;
    if (!baslik || !icerik) { uyari("Başlık ve içerik zorunludur."); return; }
    try {
      const tip = document.getElementById("dy-tip")?.value || "DUYURU";
      await api("/api/saha/duyurular", { method: "POST", body: JSON.stringify({ baslik, icerik, onem, tip }) });
      kapatModal(); loadView("duyurular");
    } catch (e) { uyari(e.message); }
  });
}

async function duyuruDetayModal(did) {
  modal(`<div class="saha-load">Yükleniyor…</div>`);
  api(`/api/saha/duyurular/${did}/oku`, { method: "PUT", body: "{}" }).then(() => { if (S.view === "bugun" || S.view === "duyurular") loadView(S.view); }).catch(() => {});
  try {
    const { duyuru: d, yorumlar, okuyanlar } = await api(`/api/saha/duyurular/${did}`);
    const ROL_RENK = { admin: "#7c3aed", manager: "#0284c7", rep: "#374151" };
    const ROL_ETK = { admin: "GM", manager: "Müdür", rep: "Temsilci" };
    const onemRenk = { ACIL: "#ef4444", YUKSEK: "#f59e0b", NORMAL: "#64748b" };

    function yorumHTML(y) {
      const renk = ROL_RENK[y.rol] || "#374151";
      const ts = new Date(y.created_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
      return `<div>
        <div style="display:flex;align-items:center;gap:6px;margin-bottom:2px">
          <span style="background:${renk};color:#fff;border-radius:5px;padding:1px 6px;font-size:10px;font-weight:700">${ROL_ETK[y.rol] || y.rol}</span>
          <span style="font-size:12px;font-weight:600;color:#334155">${esc(y.user_adi)}</span>
          <span style="font-size:11px;color:#94a3b8;margin-left:auto">${ts}</span>
        </div>
        <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;border-top-left-radius:2px;padding:8px 10px;font-size:13px;color:#0f172a;white-space:pre-wrap">${esc(y.icerik)}</div>
      </div>`;
    }

    modal(`
      <div style="display:flex;align-items:flex-start;gap:8px;margin-bottom:4px">
        <h3 style="margin:0;flex:1">${esc(d.baslik)}</h3>
        ${d.tip === "PIYASA" ? `<span class="rozet" style="background:#0891b2">📊 Piyasa</span>` : ""}${d.onem !== "NORMAL" ? `<span class="rozet" style="background:${onemRenk[d.onem]}">${d.onem === "ACIL" ? "🚨 Acil" : "⚠️ Önemli"}</span>` : ""}
      </div>
      <div style="font-size:12px;color:#94a3b8;margin-bottom:12px">${esc(d.yazan_adi)} · ${new Date(d.created_at).toLocaleString("tr-TR")}</div>
      <div style="font-size:14px;color:#1e293b;white-space:pre-wrap;padding:12px;background:#f8fafc;border-radius:8px;margin-bottom:12px">${esc(d.icerik)}</div>
      ${okuyanlar.length ? `<div style="font-size:12px;color:#64748b;margin-bottom:12px">👁 <b>${okuyanlar.length}</b> kişi okudu: ${okuyanlar.map(o => esc(o.full_name)).join(", ")}</div>` : ""}
      <div style="font-size:12px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.4px;margin-bottom:8px">Yorumlar</div>
      <div id="dy-yorumlar" style="display:flex;flex-direction:column;gap:8px;margin-bottom:10px">
        ${yorumlar.length ? yorumlar.map(yorumHTML).join("") : `<div style="font-size:12px;color:#94a3b8;font-style:italic">Henüz yorum yok.</div>`}
      </div>
      <div style="display:flex;gap:8px;align-items:flex-end">
        <textarea id="dy-inp" class="giris" rows="2" placeholder="Yorum yaz…" style="flex:1;resize:none"></textarea>
        <button class="btn kucuk" id="dy-gonder" style="flex-shrink:0">Gönder</button>
      </div>
      <div class="modal-btnlar">
        <button class="btn gri" data-kapat>Kapat</button>
        ${S.role !== "rep" ? `<button class="btn" style="background:#ef4444" id="dy-sil">Sil</button>` : ""}
      </div>`);

    document.getElementById("dy-gonder").addEventListener("click", async () => {
      const inp = document.getElementById("dy-inp");
      const text = inp?.value.trim();
      if (!text) return;
      inp.disabled = true;
      try {
        const { yorumlar: yeni } = await api(`/api/saha/duyurular/${did}/yorum`, { method: "POST", body: JSON.stringify({ icerik: text }) });
        inp.value = "";
        const yd = document.getElementById("dy-yorumlar");
        if (yd) yd.innerHTML = yeni.length ? yeni.map(yorumHTML).join("") : `<div style="font-size:12px;color:#94a3b8;font-style:italic">Henüz yorum yok.</div>`;
      } catch (e) { uyari(e.message); }
      finally { if (inp) inp.disabled = false; }
    });
    document.getElementById("dy-inp")?.addEventListener("keydown", ev => {
      if (ev.key === "Enter" && !ev.shiftKey) { ev.preventDefault(); document.getElementById("dy-gonder").click(); }
    });
    document.getElementById("dy-sil")?.addEventListener("click", async () => {
      if (!confirm("Bu duyuruyu silmek istediğinize emin misiniz?")) return;
      await api(`/api/saha/duyurular/${did}`, { method: "DELETE" });
      kapatModal(); loadView("duyurular");
    });
  } catch (e) {
    modal(`<div>${hata(e)}</div><div class="modal-btnlar"><button class="btn gri" data-kapat>Kapat</button></div>`);
  }
}

// ── MESAJLAR ─────────────────────────────────────────────────────────────────
async function vMesajlar() {
  try {
    const data = await api("/api/saha/konusmalar");

    if (S.role === "rep") {
      // Rep: direct thread view
      const { konusma_id, mesajlar, yayimlar } = data;
      renderMesajThread(konusma_id, mesajlar, yayimlar, null);
    } else {
      // Manager: list of rep conversations + broadcast
      const { konusmalar, yayimlar } = data;
      const toplam_okunmamis = konusmalar.reduce((s, k) => s + k.okunmamis, 0);
      tabBadge("mesajlar", toplam_okunmamis);

      main().innerHTML = `
        <button class="saha-cta" id="yayim-btn">📣 Toplu Mesaj Gönder</button>
        ${yayimlar.length ? `<div style="background:#fefce8;border:1px solid #fde047;border-radius:10px;padding:10px 12px;margin-bottom:10px">
          <div style="font-size:11px;font-weight:700;color:#854d0e;margin-bottom:6px">SON YAYIMLAR</div>
          ${yayimlar.map(y => `<div style="font-size:12px;color:#713f12;padding:4px 0;border-bottom:1px solid #fef08a">${esc(y.icerik.slice(0,80))}${y.icerik.length>80?"…":""} <span style="color:#a16207">${new Date(y.created_at).toLocaleDateString("tr-TR")}</span></div>`).join("")}
        </div>` : ""}
        <div style="font-size:11px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.5px;margin:8px 0 6px">Bireysel Konuşmalar</div>
        ${konusmalar.map(k => `
          <div class="kart" data-rep-id="${k.rep_id}" style="${k.okunmamis ? "border-left:3px solid #0284c7;" : ""}">
            <div class="kart-ust">
              <b>👤 ${esc(k.rep_adi)}</b>
              ${k.okunmamis ? `<span class="rozet" style="background:#0284c7">${k.okunmamis} yeni</span>` : ""}
            </div>
            ${k.son_mesaj ? `<div class="kart-alt"><span style="color:#64748b;font-style:italic">${k.son_mesaj.gonderen_rol === "rep" ? "↩ " : ""}${esc(k.son_mesaj.icerik.slice(0,60))}${k.son_mesaj.icerik.length>60?"…":""}</span><span>${new Date(k.son_mesaj.created_at).toLocaleDateString("tr-TR")}</span></div>` : `<div class="kart-alt"><span style="color:#94a3b8;font-style:italic">Henüz mesaj yok</span></div>`}
          </div>`).join("")}
      `;

      main().querySelector("#yayim-btn").addEventListener("click", yayimMesajModal);
      main().querySelectorAll("[data-rep-id]").forEach(el =>
        el.addEventListener("click", async () => {
          const repId = el.dataset.repId;
          const repAdi = el.querySelector("b").textContent.replace("👤 ", "");
          main().innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
          const { konusma_id, mesajlar } = await api(`/api/saha/konusmalar/${repId}`);
          renderMesajThread(konusma_id, mesajlar, [], repAdi);
        }));
    }
  } catch (e) { main().innerHTML = hata(e); }
}

function renderMesajThread(konusmaId, mesajlar, yayimlar, repAdi) {
  const isManager = S.role !== "rep";

  function mesajEl(m, isYayim = false) {
    const benim = m.gonderen_id === S.me.id;
    const ts = new Date(m.created_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
    return `<div style="display:flex;flex-direction:column;align-items:${benim ? "flex-end" : "flex-start"};margin-bottom:10px">
      <div style="font-size:11px;color:#94a3b8;margin-bottom:2px">${esc(m.gonderen_adi)} · ${ts}${isYayim ? " · 📣 Yayım" : ""}</div>
      <div style="max-width:80%;background:${benim ? "#0284c7" : isYayim ? "#fef3c7" : "#f1f5f9"};color:${benim ? "#fff" : "#0f172a"};border-radius:${benim ? "12px 12px 2px 12px" : "12px 12px 12px 2px"};padding:10px 12px;font-size:13px;white-space:pre-wrap">${esc(m.icerik)}</div>
    </div>`;
  }

  // Merge and sort DM + broadcast messages by time
  const dmMsgs = mesajlar.map(m => ({ ...m, _yayim: false }));
  const yayimMsgs = yayimlar.map(m => ({ ...m, gonderen_id: null, _yayim: true }));
  const all = [...dmMsgs, ...yayimMsgs].sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

  main().innerHTML = `
    ${repAdi ? `<button class="btn gri kucuk" id="msg-geri" style="margin-bottom:10px">← Geri</button>
    <div style="font-size:14px;font-weight:700;margin-bottom:10px">💬 ${esc(repAdi)}</div>` : `<div style="font-size:14px;font-weight:700;margin-bottom:10px">💬 Yönetici ile Konuşma</div>`}
    <div id="msg-thread" style="display:flex;flex-direction:column;min-height:200px;margin-bottom:12px">
      ${all.length ? all.map(m => mesajEl(m, m._yayim)).join("") : `<div style="color:#94a3b8;font-size:13px;font-style:italic;text-align:center;padding:20px 0">Henüz mesaj yok.</div>`}
    </div>
    <div style="display:flex;gap:8px;align-items:flex-end">
      <textarea id="msg-inp" class="giris" rows="2" placeholder="Mesaj yaz…" style="flex:1;resize:none"></textarea>
      <button class="btn kucuk" id="msg-gonder" style="flex-shrink:0">Gönder</button>
    </div>
  `;

  // Scroll to bottom
  const thread = document.getElementById("msg-thread");
  if (thread) thread.scrollTop = thread.scrollHeight;

  main().querySelector("#msg-geri")?.addEventListener("click", () => loadView("mesajlar"));

  document.getElementById("msg-gonder").addEventListener("click", async () => {
    const inp = document.getElementById("msg-inp");
    const text = inp?.value.trim();
    if (!text) return;
    inp.disabled = true;
    try {
      await api(`/api/saha/konusmalar/${konusmaId}`, { method: "POST", body: JSON.stringify({ icerik: text }) });
      // Append optimistically
      const me = S.me;
      const now = new Date().toISOString();
      const fakeMsg = { gonderen_id: me.id, gonderen_adi: me.name, gonderen_rol: S.role, icerik: text, created_at: now, _yayim: false };
      const t = document.getElementById("msg-thread");
      if (t) { t.insertAdjacentHTML("beforeend", mesajEl(fakeMsg)); t.scrollTop = t.scrollHeight; }
      inp.value = "";
    } catch (e) { uyari(e.message); }
    finally { if (inp) inp.disabled = false; }
  });
  document.getElementById("msg-inp")?.addEventListener("keydown", ev => {
    if (ev.key === "Enter" && !ev.shiftKey) { ev.preventDefault(); document.getElementById("msg-gonder").click(); }
  });
}

async function yayimMesajModal() {
  modal(`<div class="saha-load">Yükleniyor…</div>`);
  let reps = [];
  try { ({ reps } = await api("/api/saha/reps")); } catch { /* fallback: no list */ }

  modal(`
    <h3>📣 Toplu Mesaj Gönder</h3>
    <label class="etiket" style="margin-bottom:6px">Alıcılar</label>
    <div style="border:1px solid #e2e8f0;border-radius:8px;padding:8px 10px;margin-bottom:10px;max-height:160px;overflow-y:auto">
      <label style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;padding-bottom:6px;border-bottom:1px solid #f1f5f9;margin-bottom:6px;cursor:pointer">
        <input type="checkbox" id="yayim-tumü" style="width:15px;height:15px"> Tüm temsilciler
      </label>
      ${reps.map(r => `
        <label style="display:flex;align-items:center;gap:8px;font-size:13px;padding:3px 0;cursor:pointer">
          <input type="checkbox" class="yayim-rep" data-id="${r.id}" style="width:15px;height:15px"> ${esc(r.full_name)}
        </label>`).join("")}
    </div>
    <label class="etiket">Mesaj *</label>
    <textarea id="yayim-inp" class="giris" rows="4" placeholder="Mesaj metni…"></textarea>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>İptal</button>
      <button class="btn" id="yayim-gonder">Gönder</button>
    </div>`);

  // "Tüm temsilciler" toggles all
  document.getElementById("yayim-tumü").addEventListener("change", function() {
    document.querySelectorAll(".yayim-rep").forEach(cb => cb.checked = this.checked);
  });
  // Individual unchecks "Tüm" if any deselected
  document.querySelectorAll(".yayim-rep").forEach(cb => cb.addEventListener("change", () => {
    const all = [...document.querySelectorAll(".yayim-rep")];
    document.getElementById("yayim-tumü").checked = all.every(c => c.checked);
  }));

  document.getElementById("yayim-gonder").addEventListener("click", async () => {
    const text = document.getElementById("yayim-inp")?.value.trim();
    if (!text) { uyari("Mesaj boş olamaz."); return; }
    const tumü = document.getElementById("yayim-tumü").checked;
    const secili = [...document.querySelectorAll(".yayim-rep:checked")].map(c => c.dataset.id);
    if (!tumü && !secili.length) { uyari("En az bir temsilci seçin."); return; }
    try {
      if (tumü) {
        await api("/api/saha/konusmalar/yayim", { method: "POST", body: JSON.stringify({ icerik: text }) });
      } else {
        await api("/api/saha/konusmalar/coklu", { method: "POST", body: JSON.stringify({ rep_ids: secili, icerik: text }) });
      }
      kapatModal(); uyari(`Mesaj ${tumü ? "tüm temsilcilere" : `${secili.length} temsilciye`} gönderildi.`, true);
      loadView("mesajlar");
    } catch (e) { uyari(e.message); }
  });
}

// ── TEMSİLCİLER (manager / admin only) ──────────────────────────────────────
const TR_ILLER = [
  "Adana","Adıyaman","Afyonkarahisar","Ağrı","Amasya","Ankara","Antalya","Artvin",
  "Aydın","Balıkesir","Bilecik","Bingöl","Bitlis","Bolu","Burdur","Bursa",
  "Çanakkale","Çankırı","Çorum","Denizli","Diyarbakır","Edirne","Elazığ","Erzincan",
  "Erzurum","Eskişehir","Gaziantep","Giresun","Gümüşhane","Hakkari","Hatay","Isparta",
  "İçel (Mersin)","İstanbul","İzmir","Kars","Kastamonu","Kayseri","Kırklareli","Kırşehir",
  "Kocaeli","Konya","Kütahya","Malatya","Manisa","Kahramanmaraş","Mardin","Muğla",
  "Muş","Nevşehir","Niğde","Ordu","Rize","Sakarya","Samsun","Siirt",
  "Sinop","Sivas","Tekirdağ","Tokat","Trabzon","Tunceli","Şanlıurfa","Uşak",
  "Van","Yozgat","Zonguldak","Aksaray","Bayburt","Karaman","Kırıkkale","Batman",
  "Şırnak","Bartın","Ardahan","Iğdır","Yalova","Karabük","Kilis","Osmaniye","Düzce"
];

// Province centers [lat, lon] — used for Turkey bubble map
const IL_KOORD = {
  "Adana":          [37.0, 35.3], "Adıyaman":       [37.8, 38.3], "Afyonkarahisar": [38.8, 30.5],
  "Ağrı":           [39.7, 43.1], "Amasya":         [40.7, 35.8], "Ankara":         [39.9, 32.9],
  "Antalya":        [36.9, 30.7], "Artvin":         [41.2, 41.8], "Aydın":          [37.8, 28.0],
  "Balıkesir":      [39.6, 27.9], "Bilecik":        [40.1, 29.9], "Bingöl":         [38.9, 40.5],
  "Bitlis":         [38.4, 42.1], "Bolu":           [40.7, 31.6], "Burdur":         [37.7, 30.3],
  "Bursa":          [40.2, 29.1], "Çanakkale":      [40.1, 26.4], "Çankırı":        [40.6, 33.6],
  "Çorum":          [40.5, 34.9], "Denizli":        [37.8, 29.1], "Diyarbakır":     [37.9, 40.2],
  "Edirne":         [41.7, 26.6], "Elazığ":         [38.7, 39.2], "Erzincan":       [39.7, 39.5],
  "Erzurum":        [39.9, 41.3], "Eskişehir":      [39.8, 30.5], "Gaziantep":      [37.1, 37.4],
  "Giresun":        [40.9, 38.4], "Gümüşhane":      [40.5, 39.5], "Hakkari":        [37.6, 44.0],
  "Hatay":          [36.4, 36.2], "Isparta":        [37.8, 30.6], "İçel (Mersin)":  [36.8, 34.6],
  "İstanbul":       [41.0, 28.9], "İzmir":          [38.4, 27.1], "Kars":           [40.6, 43.1],
  "Kastamonu":      [41.4, 33.8], "Kayseri":        [38.7, 35.5], "Kırklareli":     [41.7, 27.2],
  "Kırşehir":       [39.1, 34.2], "Kocaeli":        [40.8, 29.9], "Konya":          [37.9, 32.5],
  "Kütahya":        [39.4, 29.9], "Malatya":        [38.4, 38.3], "Manisa":         [38.6, 27.4],
  "Kahramanmaraş":  [37.6, 36.9], "Mardin":         [37.3, 40.7], "Muğla":          [37.2, 28.4],
  "Muş":            [38.7, 41.5], "Nevşehir":       [38.6, 34.7], "Niğde":          [37.9, 34.7],
  "Ordu":           [40.9, 37.9], "Rize":           [41.0, 40.5], "Sakarya":        [40.7, 30.4],
  "Samsun":         [41.3, 36.3], "Siirt":          [37.9, 42.0], "Sinop":          [42.0, 35.2],
  "Sivas":          [39.7, 37.0], "Tekirdağ":       [41.0, 27.5], "Tokat":          [40.3, 36.6],
  "Trabzon":        [41.0, 39.7], "Tunceli":        [39.1, 39.5], "Şanlıurfa":      [37.2, 38.8],
  "Uşak":           [38.7, 29.4], "Van":            [38.5, 43.4], "Yozgat":         [39.8, 34.8],
  "Zonguldak":      [41.5, 31.8], "Aksaray":        [38.4, 34.0], "Bayburt":        [40.3, 40.2],
  "Karaman":        [37.2, 33.2], "Kırıkkale":      [39.9, 33.5], "Batman":         [37.9, 41.1],
  "Şırnak":         [37.5, 42.5], "Bartın":         [41.6, 32.3], "Ardahan":        [41.1, 42.7],
  "Iğdır":          [39.9, 44.0], "Yalova":         [40.7, 29.3], "Karabük":        [41.2, 32.6],
  "Kilis":          [36.7, 37.1], "Osmaniye":       [37.1, 36.2], "Düzce":          [40.8, 31.2]
};

async function vTemsilciler() {
  if (!["manager","admin"].includes(S.role)) {
    main().innerHTML = `<div class="saha-bos">Bu bölüm sadece müdür ve adminler içindir.</div>`; return;
  }
  const renderPage = async () => {
    try {
      const { repler } = await api("/api/saha/admin/reps");
      const m = main();
      m.innerHTML = `
        <div style="padding:12px">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
            <b style="font-size:15px">Saha Temsilcileri</b>
            ${S.role === "admin" ? `<button class="btn" id="tr-yeni-btn">＋ Temsilci Ekle</button>` : ""}
          </div>
          <div id="tr-liste"></div>
        </div>`;
      const liste = m.querySelector("#tr-liste");
      liste.innerHTML = repler.map(r => {
        const initials = (r.full_name || "?").split(" ").map(w => w[0]).join("").slice(0,2).toUpperCase();
        const rolRenk = r.module_role === "admin" ? "#7c3aed" : r.module_role === "manager" ? "#0284c7" : "#16a34a";
        const rolEtiket = r.module_role === "admin" ? "GM" : r.module_role === "manager" ? "Müdür" : "Temsilci";
        const aktiflik = r.active ? "" : `<span style="color:#ef4444;font-size:11px;margin-left:6px">● Pasif</span>`;
        const sonGiris = r.last_login_at ? new Date(r.last_login_at).toLocaleDateString("tr-TR") : "Giriş yok";
        const sonZiyaret = r.son_ziyaret ? new Date(r.son_ziyaret).toLocaleDateString("tr-TR") : "—";
        const sehirCipleri = (r.sehirler || []).slice(0,6).map(il =>
          `<span style="background:#dbeafe;color:#1e40af;border-radius:10px;padding:1px 7px;font-size:11px">${esc(il)}</span>`
        ).join(" ") + (r.sehirler?.length > 6 ? `<span style="font-size:11px;color:#666"> +${r.sehirler.length - 6}</span>` : "");
        return `
          <div class="tr-kart" data-id="${r.id}" style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:14px;margin-bottom:10px;cursor:pointer">
            <div style="display:flex;align-items:flex-start;gap:12px">
              <div style="width:44px;height:44px;border-radius:50%;background:${rolRenk};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:16px;flex-shrink:0">${esc(initials)}</div>
              <div style="flex:1;min-width:0">
                <div style="font-weight:600;font-size:14px">${esc(r.full_name)}${aktiflik}</div>
                <div style="font-size:12px;color:#6b7280;margin-top:1px">${esc(r.email)} ${r.telefon ? `· ${esc(r.telefon)}` : ""}</div>
                <div style="margin-top:4px;display:flex;gap:8px;flex-wrap:wrap">
                  <span style="background:${rolRenk}22;color:${rolRenk};border-radius:8px;padding:1px 8px;font-size:11px;font-weight:600">${rolEtiket}</span>
                  <span style="font-size:11px;color:#6b7280">👥 ${r.musteri_sayisi} müşteri</span>
                  <span style="font-size:11px;color:#6b7280">📋 ${r.ziyaret_30gun} ziyaret</span>
                  <span style="font-size:11px;color:#6b7280">Son: ${sonGiris}</span>
                </div>
                <div style="margin-top:6px;display:flex;gap:4px;flex-wrap:wrap;min-height:20px">
                  ${sehirCipleri || `<span style="font-size:11px;color:#9ca3af;font-style:italic">Şehir atanmamış</span>`}
                </div>
              </div>
              <div style="font-size:20px;color:#9ca3af">›</div>
            </div>
          </div>`;
      }).join("") || `<div class="saha-bos">Henüz temsilci yok.</div>`;

      // Wire card clicks → detail panel
      m.querySelectorAll(".tr-kart").forEach(kart => {
        kart.addEventListener("click", () => {
          const rep = repler.find(r => r.id === kart.dataset.id);
          if (rep) temsilciDetayModal(rep, renderPage);
        });
      });

      // New rep button
      m.querySelector("#tr-yeni-btn")?.addEventListener("click", () => yeniTemsilciModal(renderPage));

    } catch(e) { main().innerHTML = hata(e); }
  };
  await renderPage();
}

// ── NOTLARIM ─────────────────────────────────────────────────────────────────

async function vNotlarim() {
  const render = async () => {
    try {
      const { notlar } = await api("/api/saha/notlar");
      const m = main();
      const today = new Date().toISOString().slice(0, 10);
      const bekleyenler  = notlar.filter(n => !n.tamamlandi);
      // Tab badge: count pending reminders due today or overdue
      const acilNotlar = bekleyenler.filter(n => n.hatirlatma_tarihi && n.hatirlatma_tarihi <= today);
      tabBadge("notlarim", acilNotlar.length);
      const tamamlananlar = notlar.filter(n => n.tamamlandi);
      m.innerHTML = `
        <div style="padding:12px">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px">
            <b style="font-size:15px">Notlarım</b>
            <button class="btn" id="not-yeni-btn">＋ Not Ekle</button>
          </div>
          <div id="not-liste">
            ${bekleyenler.length === 0 && tamamlananlar.length === 0
              ? `<div class="saha-bos">Henüz not yok.<br>Ziyaretlerdeki hatırlatmaları veya yapılacakları buraya ekleyin.</div>`
              : ""}
            ${bekleyenler.map(n => notKart(n, today)).join("")}
            ${tamamlananlar.length > 0
              ? `<div style="margin-top:16px;font-size:12px;color:#94a3b8;text-transform:uppercase;letter-spacing:.4px;margin-bottom:6px">Tamamlananlar (${tamamlananlar.length})</div>
                 ${tamamlananlar.map(n => notKart(n, today)).join("")}`
              : ""}
          </div>
        </div>`;

      m.querySelector("#not-yeni-btn").addEventListener("click", () => notEkleModal(render));

      m.querySelectorAll("[data-not-id]").forEach(el => {
        el.addEventListener("click", async ev => {
          const id = el.dataset.notId;
          const not = notlar.find(n => n.id === id);
          if (!not) return;
          const toggleBtn = ev.target.closest("[data-toggle-done]");
          if (toggleBtn) {
            ev.stopPropagation();
            try {
              await api(`/api/saha/notlar/${id}`, { method: "PUT", body: JSON.stringify({ tamamlandi: !not.tamamlandi }) });
              render();
            } catch(e) { uyari(e.message); }
            return;
          }
          const delBtn = ev.target.closest("[data-sil-not]");
          if (delBtn) {
            ev.stopPropagation();
            if (!confirm("Bu notu silmek istiyor musunuz?")) return;
            try {
              await api(`/api/saha/notlar/${id}`, { method: "DELETE" });
              render();
            } catch(e) { uyari(e.message); }
            return;
          }
          notDuzenleModal(not, render);
        });
      });
    } catch(e) { main().innerHTML = hata(e); }
  };
  await render();
}

function notKart(n, today) {
  const tarih = n.created_at ? new Date(n.created_at).toLocaleDateString("tr-TR", { day: "numeric", month: "short" }) : "";
  const hatirlatmaGecti = n.hatirlatma_tarihi && !n.tamamlandi && n.hatirlatma_tarihi < today;
  const hatirlatmaBugun = n.hatirlatma_tarihi && !n.tamamlandi && n.hatirlatma_tarihi === today;
  const hatirlatmaStr = n.hatirlatma_tarihi
    ? new Date(n.hatirlatma_tarihi + "T00:00:00").toLocaleDateString("tr-TR", { day: "numeric", month: "short" })
    : null;
  const hatirlatmaRenk = hatirlatmaGecti ? "#ef4444" : hatirlatmaBugun ? "#f97316" : "#0284c7";
  return `
    <div class="kart" data-not-id="${n.id}" style="cursor:pointer;opacity:${n.tamamlandi ? ".55" : "1"}">
      <div class="kart-ust" style="gap:8px;align-items:flex-start">
        <button data-toggle-done style="flex-shrink:0;background:none;border:2px solid ${n.tamamlandi ? "#10b981" : "#cbd5e1"};border-radius:50%;width:22px;height:22px;min-width:22px;cursor:pointer;display:flex;align-items:center;justify-content:center;color:${n.tamamlandi ? "#10b981" : "transparent"};font-size:12px;padding:0;margin-top:1px">✓</button>
        <span style="flex:1;font-size:14px;line-height:1.45;${n.tamamlandi ? "text-decoration:line-through;color:#94a3b8" : "color:#0f172a"}">${esc(n.icerik)}</span>
        <button data-sil-not style="flex-shrink:0;background:none;border:none;color:#cbd5e1;font-size:16px;cursor:pointer;padding:0;line-height:1;margin-top:1px">🗑</button>
      </div>
      <div class="kart-alt" style="margin-top:5px">
        <span style="color:#94a3b8">${tarih}</span>
        ${hatirlatmaStr ? `<span style="color:${hatirlatmaRenk};font-weight:600">⏰ ${hatirlatmaStr}${hatirlatmaGecti ? " · gecikti" : hatirlatmaBugun ? " · bugün" : ""}</span>` : ""}
      </div>
    </div>`;
}

function notEkleModal(onSave) {
  const minTarih = new Date().toISOString().slice(0, 10);
  modal(`
    <h3>Not Ekle</h3>
    <label>Not
      <textarea class="giris" id="nm-icerik" rows="4" placeholder="Ne yapmam gerekiyor?"></textarea>
    </label>
    <label style="margin-top:10px;display:block">Hatırlatma Tarihi (opsiyonel)
      <input type="date" class="giris" id="nm-tarih" min="${minTarih}">
    </label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="nm-kaydet">Ekle</button>
    </div>`);
  document.getElementById("nm-kaydet").addEventListener("click", async () => {
    const icerik = document.getElementById("nm-icerik").value.trim();
    if (!icerik) { uyari("Not boş olamaz."); return; }
    const tarih = document.getElementById("nm-tarih").value || null;
    try {
      await api("/api/saha/notlar", { method: "POST", body: JSON.stringify({ icerik, hatirlatma_tarihi: tarih }) });
      kapatModal();
      onSave();
    } catch(e) { uyari(e.message); }
  });
}

function notDuzenleModal(n, onSave) {
  modal(`
    <h3>Notu Düzenle</h3>
    <label>Not
      <textarea class="giris" id="nd-icerik" rows="4">${esc(n.icerik)}</textarea>
    </label>
    <label style="margin-top:10px;display:block">Hatırlatma Tarihi
      <input type="date" class="giris" id="nd-tarih" value="${n.hatirlatma_tarihi || ""}">
    </label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="nd-kaydet">Kaydet</button>
    </div>`);
  document.getElementById("nd-kaydet").addEventListener("click", async () => {
    const icerik = document.getElementById("nd-icerik").value.trim();
    if (!icerik) { uyari("Not boş olamaz."); return; }
    const tarih = document.getElementById("nd-tarih").value || null;
    try {
      await api(`/api/saha/notlar/${n.id}`, { method: "PUT", body: JSON.stringify({ icerik, hatirlatma_tarihi: tarih }) });
      kapatModal();
      onSave();
    } catch(e) { uyari(e.message); }
  });
}

// ── REP PROFİL — ev/merkez konumu modal ──────────────────────────────────────
async function repProfilModal(onSave) {
  let mevcut = {};
  try { mevcut = await api("/api/saha/rep-profil"); } catch {}

  modal(`
    <div style="padding:20px;min-width:300px;max-width:400px">
      <div style="font-weight:700;font-size:15px;color:#0f172a;margin-bottom:4px">📍 Merkez / Ev Konumu</div>
      <div style="font-size:12px;color:#64748b;margin-bottom:16px">Rota önerisi için başlangıç noktanı belirle.</div>
      <label style="font-size:12px;font-weight:600;color:#374151">Adres / Şehir</label>
      <input id="rp-adres" class="giris" type="text" placeholder="örn: Ankara, Çankaya" value="${esc(mevcut.base_adres||'')}" style="margin:4px 0 12px;width:100%;box-sizing:border-box">
      <div style="display:flex;gap:8px;margin-bottom:12px">
        <div style="flex:1">
          <label style="font-size:12px;font-weight:600;color:#374151">Enlem</label>
          <input id="rp-lat" class="giris" type="number" step="0.000001" placeholder="39.9334" value="${mevcut.base_lat||''}" style="margin-top:4px;width:100%;box-sizing:border-box">
        </div>
        <div style="flex:1">
          <label style="font-size:12px;font-weight:600;color:#374151">Boylam</label>
          <input id="rp-lng" class="giris" type="number" step="0.000001" placeholder="32.8597" value="${mevcut.base_lng||''}" style="margin-top:4px;width:100%;box-sizing:border-box">
        </div>
      </div>
      <button id="rp-gps" class="btn" style="width:100%;margin-bottom:12px;background:#0ea5e9;color:#fff">📡 GPS ile Konumumu Al</button>
      <div style="display:flex;gap:8px">
        <button data-kapat class="btn" style="flex:1;background:#f1f5f9;color:#374151">İptal</button>
        <button id="rp-kaydet" class="btn" style="flex:1">Kaydet</button>
      </div>
    </div>`);

  document.getElementById("rp-gps")?.addEventListener("click", function() {
    if (!navigator.geolocation) { uyari("Tarayıcı konum desteklemiyor."); return; }
    this.textContent = "⏳ Konum alınıyor…";
    navigator.geolocation.getCurrentPosition(pos => {
      document.getElementById("rp-lat").value = pos.coords.latitude.toFixed(6);
      document.getElementById("rp-lng").value = pos.coords.longitude.toFixed(6);
      document.getElementById("rp-gps").textContent = "✓ Konum alındı";
    }, () => { uyari("Konum alınamadı."); document.getElementById("rp-gps").textContent = "📡 GPS ile Konumumu Al"; }, { timeout: 8000 });
  });

  document.getElementById("rp-kaydet")?.addEventListener("click", async () => {
    const adres = document.getElementById("rp-adres").value.trim();
    const lat   = parseFloat(document.getElementById("rp-lat").value) || null;
    const lng   = parseFloat(document.getElementById("rp-lng").value) || null;
    if (!adres && (lat === null || lng === null)) { uyari("Adres veya koordinat girilmeli."); return; }
    try {
      await api("/api/saha/rep-profil", { method: "PUT", body: JSON.stringify({ base_adres: adres, base_lat: lat, base_lng: lng }) });
      uyari("Konum kaydedildi.", true);
      kapatModal();
      if (onSave) onSave();
    } catch(e) { uyari(e.message); }
  });
}

// ── REP BRAIN ────────────────────────────────────────────────────────────────

async function vRepBrain() {
  const m = main();
  // Daily greeting guard — once per calendar day per user
  const todayKey = `rep_brain_greeted_${S.me.id || "rep"}_${new Date().toISOString().slice(0, 10)}`;

  // Fetch rep profile to check if base address is set
  let repProfil = {};
  try { repProfil = await api("/api/saha/rep-profil"); } catch {}

  m.innerHTML = `
    <div style="display:flex;flex-direction:column;height:100%;min-height:0">
      <div style="padding:8px 12px;background:#f8fafc;border-bottom:1px solid #e2e8f0;display:flex;align-items:center;gap:10px;flex-shrink:0">
        <span style="font-size:22px;line-height:1">🤖</span>
        <div style="flex:1">
          <div style="font-weight:700;font-size:14px;color:#0f172a">Asistan & Koç</div>
          <div style="font-size:11px;color:#64748b">Kişisel asistan + gelişim koçun</div>
        </div>
        <button id="rb-profil-btn" title="Merkez konumu ayarla" style="background:none;border:none;font-size:17px;cursor:pointer;padding:4px;color:#64748b">⚙️</button>
      </div>
      ${!repProfil.base_adres ? `
      <div id="rb-konum-banner" style="margin:8px 12px 0;padding:8px 12px;background:#fffbeb;border:1px solid #fcd34d;border-radius:8px;font-size:12px;color:#92400e;display:flex;align-items:center;gap:8px">
        <span>📍</span>
        <span style="flex:1">Rota önerisi için merkez konumunu ayarla.</span>
        <button id="rb-banner-ayarla" style="font-size:11px;font-weight:700;background:#f59e0b;color:#fff;border:none;border-radius:6px;padding:3px 8px;cursor:pointer">Ayarla</button>
      </div>` : ""}
      <div id="rb-msgs" style="flex:1;overflow-y:auto;padding:12px;display:flex;flex-direction:column;gap:8px"></div>
      <div style="padding:6px 12px;background:#f8fafc;border-top:1px solid #e2e8f0;overflow-x:auto;display:flex;gap:6px;flex-shrink:0;scrollbar-width:none">
        ${[
          ["🏆 Bu haftam nasıl?","Bu haftam nasıl gidiyor?"],
          ["🎯 Gelişim alanlarım","Gelişim alanlarım neler? Dürüstçe analiz et."],
          ["😴 Kimi ihmal ediyorum?","Hangi müşterileri ihmal ediyorum?"],
          ["📉 Kayıplarımı analiz et","Son kayıplarımı analiz et, tekrarlayan neden var mı?"],
          ["💡 Bugün ne yapmalıyım?","Bugün öncelikli olarak ne yapmalıyım?"],
          ["📍 Rota öner","Bugün hangi müşterileri hangi sırayla ziyaret etmeliyim? Rota öner."]
        ].map(([label, msg]) =>
          `<button class="rb-chip" data-msg="${esc(msg)}" style="white-space:nowrap;padding:5px 11px;border:1.5px solid #e2e8f0;border-radius:20px;background:#fff;font-size:11px;font-weight:600;color:#374151;cursor:pointer;flex-shrink:0">${label}</button>`
        ).join("")}
      </div>
      <div style="padding:8px 12px;border-top:1px solid #e2e8f0;display:flex;gap:8px;background:#fff;flex-shrink:0;align-items:flex-end">
        <textarea id="rb-input" class="giris" rows="2" placeholder="Sorunuzu yazın…" style="flex:1;resize:none"></textarea>
        <button class="btn" id="rb-gonder" style="padding:10px 14px">Gönder</button>
      </div>
    </div>`;

  sesGirisBagla(m);
  const msgsEl = m.querySelector("#rb-msgs");

  // Load existing conversation history
  let histMsgs = [];
  try {
    const data = await api("/api/saha/rep-brain?action=history");
    histMsgs = data.messages || [];
  } catch {}
  histMsgs.forEach(msg => rbRenderMsg(msgsEl, msg.role, msg.content));

  // Daily greeting — only if no history and not greeted today
  if (!histMsgs.length) {
    localStorage.setItem(todayKey, "1");
    const thinkEl = rbAddThinking(msgsEl);
    rbStream("/api/saha/rep-brain", { message: "Merhaba! Bugünkü ziyaret planımı ve son notlarımı kısaca özetle.", is_greeting: true }, thinkEl, msgsEl);
  }

  m.querySelector("#rb-gonder").addEventListener("click", () => rbSend(msgsEl));
  m.querySelector("#rb-input").addEventListener("keydown", ev => {
    if (ev.key === "Enter" && !ev.shiftKey) { ev.preventDefault(); rbSend(msgsEl); }
  });
  m.querySelectorAll(".rb-chip").forEach(chip => {
    chip.addEventListener("click", () => {
      const input = document.getElementById("rb-input");
      if (input) { input.value = chip.dataset.msg; input.focus(); }
      rbSend(msgsEl);
    });
  });
  m.querySelector("#rb-profil-btn")?.addEventListener("click", () => repProfilModal(() => vRepBrain()));
  m.querySelector("#rb-banner-ayarla")?.addEventListener("click", () => repProfilModal(() => vRepBrain()));
}

function rbRenderMsg(msgsEl, role, text) {
  const div = document.createElement("div");
  div.style.cssText = `max-width:85%;padding:10px 13px;border-radius:12px;font-size:13px;line-height:1.5;word-break:break-word;white-space:pre-wrap;${
    role === "user"
      ? "align-self:flex-end;background:#0284c7;color:#fff;border-bottom-right-radius:3px;margin-left:auto"
      : "align-self:flex-start;background:#f1f5f9;color:#0f172a;border-bottom-left-radius:3px"
  }`;
  div.textContent = text;
  msgsEl.appendChild(div);
  msgsEl.scrollTop = msgsEl.scrollHeight;
  return div;
}

function rbAddThinking(msgsEl) {
  const div = document.createElement("div");
  div.style.cssText = "align-self:flex-start;max-width:85%;padding:10px 13px;border-radius:12px;font-size:13px;line-height:1.5;background:#f1f5f9;color:#94a3b8;border-bottom-left-radius:3px";
  div.textContent = "Yazıyor…";
  msgsEl.appendChild(div);
  msgsEl.scrollTop = msgsEl.scrollHeight;
  return div;
}

const _rotaRe = /rota|güzergah|güzergâh|yol plan|ziyaret sırala|yakın|öncelik|hangisine önce|hangi müşteri önce|bugün nereye|nereden başla|sırası nasıl/i;

function rbSend(msgsEl) {
  const input = document.getElementById("rb-input");
  if (!input) return;
  const text = input.value.trim();
  if (!text) return;
  input.value = "";
  rbRenderMsg(msgsEl, "user", text);
  const thinkEl = rbAddThinking(msgsEl);

  if (_rotaRe.test(text) && navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      pos => rbStream("/api/saha/rep-brain", {
        message: text, is_greeting: false,
        current_lat: pos.coords.latitude, current_lng: pos.coords.longitude
      }, thinkEl, msgsEl),
      () => rbStream("/api/saha/rep-brain", { message: text, is_greeting: false }, thinkEl, msgsEl),
      { timeout: 4000, maximumAge: 60000 }
    );
  } else {
    rbStream("/api/saha/rep-brain", { message: text, is_greeting: false }, thinkEl, msgsEl);
  }
}

async function rbStream(url, body, thinkEl, msgsEl) {
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...S.headers() },
      body: JSON.stringify(body)
    });
    if (!res.ok) { const d = await res.json().catch(() => ({})); throw new Error(d.error || `Hata (${res.status})`); }
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let full = "";
    let buf = "";
    thinkEl.style.color = "#0f172a";
    thinkEl.textContent = "";
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });
      const lines = buf.split("\n");
      buf = lines.pop();
      for (const line of lines) {
        if (!line.startsWith("data: ")) continue;
        const raw = line.slice(6).trim();
        if (raw === "[DONE]") break;
        try {
          const parsed = JSON.parse(raw);
          const delta = parsed?.delta?.text
            || parsed?.choices?.[0]?.delta?.content
            || parsed?.text || "";
          full += delta;
          thinkEl.textContent = full;
          msgsEl.scrollTop = msgsEl.scrollHeight;
        } catch {}
      }
    }
    if (!full) thinkEl.textContent = "(Yanıt alınamadı)";
  } catch(e) {
    thinkEl.style.color = "#ef4444";
    thinkEl.textContent = "Hata: " + e.message;
  }
}

function temsilciDetayModal(rep, onSave) {
  const rolRenk = rep.module_role === "admin" ? "#7c3aed" : rep.module_role === "manager" ? "#0284c7" : "#16a34a";
  const initials = (rep.full_name||"?").split(" ").map(w=>w[0]).join("").slice(0,2).toUpperCase();
  const secili = new Set(rep.sehirler || []);
  const ilHtml = TR_ILLER.map(il =>
    `<label style="display:inline-flex;align-items:center;gap:4px;padding:3px 8px;border-radius:16px;border:1px solid ${secili.has(il)?"#3b82f6":"#d1d5db"};background:${secili.has(il)?"#dbeafe":"#fff"};font-size:12px;cursor:pointer;margin:2px;white-space:nowrap">
      <input type="checkbox" value="${esc(il)}" ${secili.has(il)?"checked":""} style="display:none">
      ${esc(il)}
    </label>`
  ).join("");
  const isAdmin = S.role === "admin";
  modal(`
    <div style="display:flex;align-items:center;gap:12px;margin-bottom:16px">
      <div style="width:52px;height:52px;border-radius:50%;background:${rolRenk};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:20px">${esc(initials)}</div>
      <div>
        <div style="font-weight:700;font-size:16px">${esc(rep.full_name)}</div>
        <div style="font-size:12px;color:#6b7280">${esc(rep.email)}</div>
      </div>
    </div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:14px">
      <div>
        <div class="giris-etiket">Ad Soyad</div>
        <input class="giris" id="tr-ad" value="${esc(rep.full_name)}" placeholder="Ad Soyad">
      </div>
      <div>
        <div class="giris-etiket">Telefon</div>
        <input class="giris" id="tr-tel" value="${esc(rep.telefon||"")}" placeholder="+90 5xx xxx xx xx">
      </div>
    </div>
    ${isAdmin ? `<div style="margin-bottom:14px">
      <div class="giris-etiket">Rol</div>
      <select class="giris" id="tr-rol">
        <option value="rep" ${rep.module_role==="rep"?"selected":""}>Saha Temsilcisi</option>
        <option value="manager" ${rep.module_role==="manager"?"selected":""}>Bölge Müdürü</option>
        <option value="admin" ${rep.module_role==="admin"?"selected":""}>GM / Admin</option>
      </select>
    </div>` : ""}
    <div style="margin-bottom:10px">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">
        <div class="giris-etiket">Atanan Şehirler <span id="tr-sehir-sayi" style="color:#3b82f6;font-weight:600">(${secili.size})</span></div>
        <div style="display:flex;gap:6px">
          <button class="btn kucuk" id="tr-tumunu-sec">Tümünü Seç</button>
          <button class="btn kucuk" id="tr-temizle">Temizle</button>
        </div>
      </div>
      <div id="tr-il-grid" style="max-height:220px;overflow-y:auto;border:1px solid #e5e7eb;border-radius:8px;padding:8px;display:flex;flex-wrap:wrap">${ilHtml}</div>
    </div>
    <div class="modal-butonlar">
      <button class="btn tam" id="tr-kaydet" style="background:#16a34a">💾 Kaydet</button>
      ${Number(rep.musteri_sayisi) > 0 && isAdmin ? `<button class="btn tam" id="tr-devret" style="background:#f59e0b;color:#000">🔄 Müşteri Devret (${rep.musteri_sayisi})</button>` : ""}
      ${isAdmin ? `<button class="btn tam" id="tr-pasif" style="background:#ef4444">${rep.active ? "⛔ Devre Dışı Bırak" : "✅ Yeniden Aktifleştir"}</button>` : ""}
    </div>
  `);

  // City checkbox logic
  const grid = document.getElementById("tr-il-grid");
  const updateCount = () => {
    const n = grid.querySelectorAll("input:checked").length;
    document.getElementById("tr-sehir-sayi").textContent = `(${n})`;
    grid.querySelectorAll("label").forEach(lbl => {
      const cb = lbl.querySelector("input");
      lbl.style.borderColor = cb.checked ? "#3b82f6" : "#d1d5db";
      lbl.style.background  = cb.checked ? "#dbeafe" : "#fff";
    });
  };
  grid.addEventListener("change", updateCount);
  document.getElementById("tr-tumunu-sec").addEventListener("click", () => {
    grid.querySelectorAll("input").forEach(cb => cb.checked = true); updateCount();
  });
  document.getElementById("tr-temizle").addEventListener("click", () => {
    grid.querySelectorAll("input").forEach(cb => cb.checked = false); updateCount();
  });

  // Save
  document.getElementById("tr-kaydet").addEventListener("click", async () => {
    const sehirler = [...grid.querySelectorAll("input:checked")].map(cb => cb.value);
    const ad = document.getElementById("tr-ad").value.trim();
    const tel = document.getElementById("tr-tel").value.trim();
    const rol = document.getElementById("tr-rol")?.value;
    try {
      await Promise.all([
        api(`/api/saha/admin/reps/${rep.id}/sehirler`, { method: "PUT", body: JSON.stringify({ sehirler }) }),
        api(`/api/saha/admin/reps/${rep.id}`, { method: "PUT", body: JSON.stringify({ full_name: ad, telefon: tel, ...(rol ? { module_role: rol } : {}) }) })
      ]);
      kapatModal(); uyari("✓ Temsilci güncellendi.", true); onSave();
    } catch(e) { uyari(e.message || "Hata oluştu."); }
  });

  // Customer transfer
  document.getElementById("tr-devret")?.addEventListener("click", async () => {
    const { repler } = await api("/api/saha/admin/reps");
    const diger = repler.filter(r => r.id !== rep.id && r.active && r.module_role === "rep");
    if (!diger.length) { uyari("Devredilecek başka aktif temsilci yok."); return; }
    const sec = await new Promise(resolve => {
      modal(`
        <b>Müşteri Devret</b>
        <p style="font-size:13px;color:#6b7280;margin:8px 0">${rep.full_name} üzerindeki ${rep.musteri_sayisi} müşteri seçilen temsilciye aktarılacak.</p>
        <select class="giris" id="devir-hedef">
          ${diger.map(r => `<option value="${r.id}">${esc(r.full_name)} (${r.musteri_sayisi} müşteri)</option>`).join("")}
        </select>
        <div class="modal-butonlar" style="margin-top:10px">
          <button class="btn tam" id="devir-onayla" style="background:#f59e0b;color:#000">Devret</button>
          <button class="btn tam" id="devir-iptal">İptal</button>
        </div>
      `);
      document.getElementById("devir-onayla").addEventListener("click", () => resolve(document.getElementById("devir-hedef").value));
      document.getElementById("devir-iptal").addEventListener("click", () => { kapatModal(); resolve(null); });
    });
    if (!sec) return;
    try {
      const { aktarilan } = await api("/api/saha/admin/musteri-devret", { method: "POST", body: JSON.stringify({ kaynak_rep_id: rep.id, hedef_rep_id: sec }) });
      kapatModal(); uyari(`✓ ${aktarilan} müşteri devredildi.`, true); onSave();
    } catch(e) { uyari(e.message || "Devir hatası."); }
  });

  // Deactivate / Reactivate
  document.getElementById("tr-pasif")?.addEventListener("click", async () => {
    const aktiflestirilecek = !rep.active;
    const onay = aktiflestirilecek
      ? `"${rep.full_name}" saha erişimi yeniden aktifleştirilsin mi?`
      : `"${rep.full_name}" kullanıcısının saha erişimini kaldırmak istediğinizden emin misiniz?`;
    if (!confirm(onay)) return;
    try {
      if (aktiflestirilecek) {
        await api(`/api/saha/admin/reps/${rep.id}`, { method: "PUT", body: JSON.stringify({ active: true }) });
        kapatModal(); uyari("✓ Temsilci yeniden aktifleştirildi.", true); onSave();
      } else {
        await api(`/api/saha/admin/reps/${rep.id}`, { method: "DELETE" });
        kapatModal(); uyari("✓ Temsilci devre dışı bırakıldı.", true); onSave();
      }
    } catch(e) { uyari(e.message || "Hata."); }
  });
}

function yeniTemsilciModal(onSave) {
  modal(`
    <b style="font-size:15px">Yeni Temsilci Ekle</b>
    <div style="margin-top:14px;display:grid;gap:10px">
      <div>
        <div class="giris-etiket">Ad Soyad *</div>
        <input class="giris" id="ny-ad" placeholder="Ahmet Yılmaz">
      </div>
      <div>
        <div class="giris-etiket">E-posta *</div>
        <input class="giris" id="ny-email" type="email" placeholder="ahmet@krb.com.tr">
      </div>
      <div>
        <div class="giris-etiket">Telefon</div>
        <input class="giris" id="ny-tel" placeholder="+90 5xx xxx xx xx">
      </div>
      <div>
        <div class="giris-etiket">Rol</div>
        <select class="giris" id="ny-rol">
          <option value="rep">Saha Temsilcisi</option>
          <option value="manager">Bölge Müdürü</option>
          <option value="admin">GM / Admin</option>
        </select>
      </div>
    </div>
    <div class="modal-butonlar" style="margin-top:14px">
      <button class="btn tam" id="ny-kaydet" style="background:#16a34a">＋ Ekle</button>
    </div>
    <p style="font-size:11px;color:#9ca3af;margin-top:8px;text-align:center">Geçici şifre otomatik oluşturulur — ilk girişte değiştirilmesi zorunludur.</p>
  `);
  document.getElementById("ny-kaydet").addEventListener("click", async () => {
    const ad = document.getElementById("ny-ad").value.trim();
    const email = document.getElementById("ny-email").value.trim();
    const tel = document.getElementById("ny-tel").value.trim();
    const rol = document.getElementById("ny-rol").value;
    if (!ad || !email) { uyari("Ad Soyad ve e-posta zorunludur."); return; }
    try {
      const res = await api("/api/saha/admin/users", { method: "POST", body: JSON.stringify({ full_name: ad, email, telefon: tel, module_role: rol }) });
      kapatModal();
      if (res.gecici_sifre) {
        modal(`
          <b>✓ Temsilci Eklendi</b>
          <p style="margin:10px 0;font-size:13px">Geçici şifreyi kullanıcıya iletmeyi unutmayın:</p>
          <div style="background:#f1f5f9;border-radius:8px;padding:12px;text-align:center;font-size:18px;font-family:monospace;font-weight:700;letter-spacing:2px">${esc(res.gecici_sifre)}</div>
          <div class="modal-butonlar" style="margin-top:12px">
            <button class="btn tam" id="ny-tamam">Tamam</button>
          </div>
        `);
        document.getElementById("ny-tamam").addEventListener("click", () => { kapatModal(); onSave(); });
      } else {
        uyari("✓ Mevcut kullanıcıya saha erişimi verildi.", true); onSave();
      }
    } catch(e) { uyari(e.message || "Hata oluştu."); }
  });
}

// ── ÖNERİ MODAL (floating 💡 button) ─────────────────────────────────────────
const ONERI_DURUM_RENK  = { YENI: "#6b7280", INCELENIYOR: "#f59e0b", TAMAMLANDI: "#16a34a", REDDEDILDI: "#ef4444" };
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
          ${staff && o.sahip_gordu === false ? `· <span style="color:#d97706">✓ görülmedi</span>` : ""}
          ${staff && o.sahip_gordu === true && (o.mesaj_sayisi || 1) > 1 ? `· <span style="color:#0284c7">✓✓ görüldü</span>` : ""}
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
  const { oneri: o, mesajlar = [], okumalar = [], staff, ben } = d;

  // "Seen by" — anyone other than me who opened the thread AFTER the last message.
  const sonMsg = mesajlar.length ? mesajlar[mesajlar.length - 1] : null;
  const gorenler = sonMsg
    ? okumalar.filter(r => r.user_id !== ben && new Date(r.okundu_at) >= new Date(sonMsg.ts))
    : [];
  const gorulduHtml = !sonMsg ? "" : (gorenler.length
    ? `<div style="text-align:right;font-size:11px;color:#0284c7;margin-top:6px">✓✓ Görüldü — ${gorenler.map(r => `${esc(r.ad)} (${new Date(r.okundu_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })})`).join(", ")}</div>`
    : `<div style="text-align:right;font-size:11px;color:#94a3b8;margin-top:6px">✓ Gönderildi — henüz görülmedi</div>`);

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
    ${gorulduHtml}
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
      ${staff ? `<button class="btn" id="ot-sil" style="background:#dc2626;margin-right:auto">🗑 Sil</button>` : ""}
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn" id="ot-gonder">Gönder</button>
    </div>`);

  document.getElementById("ot-sil")?.addEventListener("click", async () => {
    if (!confirm(`"${o.baslik}" kaydı ve tüm mesajları kalıcı olarak silinecek. Geri alınamaz. Devam edilsin mi?`)) return;
    try {
      await api(`/api/saha/oneriler/${id}`, { method: "DELETE" });
      kapatModal();
      uyari("✓ Kayıt silindi.", true);
      if (S.view === "oneriler") await loadView("oneriler");
    } catch (e) { uyari(e.message); }
  });

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

async function oneriModal() {
  const KAT_LABEL = { HATA: "🐛 Hata Bildirimi", OZELLIK: "✨ Özellik İsteği", UI: "🎨 Arayüz", DIGER: "💬 Diğer" };
  // Load own past suggestions in background
  let gecmis = [];
  try { gecmis = (await api("/api/saha/oneriler")).oneriler || []; } catch {}

  const durumRenk = { YENI: "#6b7280", INCELENIYOR: "#f59e0b", TAMAMLANDI: "#16a34a", REDDEDILDI: "#ef4444" };
  const durumLabel = { YENI: "Yeni", INCELENIYOR: "İnceleniyor", TAMAMLANDI: "Tamamlandı", REDDEDILDI: "Reddedildi" };

  const gecmisHtml = gecmis.length ? `
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
    </details>` : "";

  modal(`
    <h3 style="margin-bottom:14px">💡 Öneri & Geri Bildirim</h3>
    <label style="display:block;margin-bottom:10px">
      <div class="giris-etiket">Kategori</div>
      <select class="giris" id="on-kat">
        ${Object.entries(KAT_LABEL).map(([v,l]) => `<option value="${v}">${l}</option>`).join("")}
      </select>
    </label>
    <label style="display:block;margin-bottom:10px">
      <div class="giris-etiket">Başlık *</div>
      <input class="giris" id="on-baslik" maxlength="120" placeholder="Kısa bir özet…">
    </label>
    <label style="display:block;margin-bottom:10px">
      <div class="giris-etiket">Açıklama *</div>
      <textarea class="giris" id="on-mesaj" rows="4" placeholder="Ne olmasını istiyorsunuz? Neden?"></textarea>
    </label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="on-gonder">Gönder</button>
    </div>
    ${gecmisHtml}
  `);

  document.querySelectorAll("[data-goid]").forEach(el => el.addEventListener("click", () => {
    kapatModal(); oneriThreadModal(el.dataset.goid);
  }));

  document.getElementById("on-gonder").addEventListener("click", async () => {
    const kategori = document.getElementById("on-kat").value;
    const baslik   = document.getElementById("on-baslik").value.trim();
    const mesaj    = document.getElementById("on-mesaj").value.trim();
    if (!baslik || !mesaj) { uyari("Başlık ve açıklama zorunludur."); return; }
    const btn = document.getElementById("on-gonder");
    btn.disabled = true; btn.textContent = "Gönderiliyor…";
    try {
      await api("/api/saha/oneri", { method: "POST", body: JSON.stringify({ kategori, baslik, mesaj }) });
      kapatModal();
      uyari("✓ Öneriniz iletildi, teşekkürler!", true);
    } catch(e) {
      btn.disabled = false; btn.textContent = "Gönder";
      uyari(e.message);
    }
  });
}

// ── SİSTEM (error report — manager/admin only) ───────────────────────────────
async function vSistem() {
  if (!S.isOwner) {
    main().innerHTML = `<div class="saha-bos">Bu bölüme erişim yetkiniz yok.</div>`;
    return;
  }
  main().innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
  try {
    const d = await api("/api/saha/hata-raporu?gun=7");
    const tipRenkler = { API_HATA: "#ef4444", JS_HATA: "#f97316", AG_HATA: "#8b5cf6", YAVAS_API: "#f59e0b", SESSIZ_HATA: "#6b7280" };
    const tipRow = (t) => `
      <div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid #1f2937">
        <span style="background:${tipRenkler[t.tip]||"#374151"};color:#fff;border-radius:4px;padding:2px 8px;font-size:11px;font-weight:600">${esc(t.tip)}</span>
        <span style="font-size:20px;font-weight:700;color:#f9fafb">${t.sayi}</span>
      </div>`;
    const endpointRow = (e) => `
      <div style="padding:6px 0;border-bottom:1px solid #1f2937;font-size:12px">
        <div style="color:#9ca3af;font-family:monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(e.endpoint||"-")}</div>
        <div style="display:flex;gap:12px;margin-top:2px">
          <span style="color:#f87171">${e.sayi} hata</span>
          ${e.ort_ms ? `<span style="color:#6b7280">ort. ${e.ort_ms}ms</span>` : ""}
        </div>
      </div>`;
    const userRow = (u) => `
      <div style="padding:6px 0;border-bottom:1px solid #1f2937;font-size:12px;display:flex;justify-content:space-between">
        <span style="color:#e5e7eb">${esc(u.kullanici || "Bilinmiyor")}</span>
        <span style="color:#f87171">${u.sayi} hata</span>
      </div>`;
    const sonHataRow = (h) => `
      <div style="padding:8px 0;border-bottom:1px solid #1f2937;font-size:12px">
        <div style="display:flex;justify-content:space-between;margin-bottom:3px">
          <span style="background:${tipRenkler[h.tip]||"#374151"};color:#fff;border-radius:3px;padding:1px 6px;font-size:10px">${esc(h.tip)}</span>
          <span style="color:#6b7280">${new Date(h.ts).toLocaleString("tr-TR")}</span>
        </div>
        <div style="color:#e5e7eb;margin-bottom:2px">${esc(h.hata_mesaji||"-")}</div>
        <div style="color:#6b7280">${esc(h.endpoint||h.view_adi||"")}</div>
      </div>`;

    main().innerHTML = `
      <div class="saha-baslik" style="padding:16px">
        <div style="font-size:18px;font-weight:700;color:#f9fafb">🔧 Sistem Durumu</div>
        <div style="font-size:12px;color:#6b7280;margin-top:2px">Son 7 günlük hata analizi</div>
      </div>
      <div style="padding:0 16px 80px;display:flex;flex-direction:column;gap:16px">

        <div style="background:#111827;border-radius:12px;padding:16px">
          <div style="font-size:13px;font-weight:600;color:#9ca3af;margin-bottom:12px;text-transform:uppercase;letter-spacing:.5px">Hata Özeti</div>
          ${d.ozet.length ? d.ozet.map(tipRow).join("") : `<div class="saha-bos">Hata kaydı yok 🎉</div>`}
        </div>

        ${d.endpoint_ozet.length ? `
        <div style="background:#111827;border-radius:12px;padding:16px">
          <div style="font-size:13px;font-weight:600;color:#9ca3af;margin-bottom:12px;text-transform:uppercase;letter-spacing:.5px">En Çok Hata Veren Endpoint'ler</div>
          ${d.endpoint_ozet.slice(0,10).map(endpointRow).join("")}
        </div>` : ""}

        ${d.user_ozet.length ? `
        <div style="background:#111827;border-radius:12px;padding:16px">
          <div style="font-size:13px;font-weight:600;color:#9ca3af;margin-bottom:12px;text-transform:uppercase;letter-spacing:.5px">Kullanıcı Bazlı</div>
          ${d.user_ozet.slice(0,10).map(userRow).join("")}
        </div>` : ""}

        <div style="background:#111827;border-radius:12px;padding:16px">
          <div style="font-size:13px;font-weight:600;color:#9ca3af;margin-bottom:12px;text-transform:uppercase;letter-spacing:.5px">Son Hatalar</div>
          ${d.son_hatalar.length ? d.son_hatalar.slice(0,50).map(sonHataRow).join("") : `<div class="saha-bos">Kayıt yok 🎉</div>`}
        </div>

        <div style="background:#111827;border-radius:12px;padding:16px" id="oneri-bolum">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">
            <div style="font-size:13px;font-weight:600;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px">Öneriler & Geri Bildirimler</div>
            <span style="font-size:12px;color:#6b7280" id="oneri-sayi">Yükleniyor…</span>
          </div>
          <div id="oneri-liste"><div class="saha-load">Yükleniyor…</div></div>
        </div>
      </div>`;

    // Load suggestions separately (non-blocking)
    (async () => {
      try {
        const od = await api("/api/saha/oneriler?gun=90");
        const oneriler = od.oneriler || [];
        const durumRenk = { YENI: "#6b7280", INCELENIYOR: "#f59e0b", TAMAMLANDI: "#16a34a", REDDEDILDI: "#ef4444" };
        const durumLabel = { YENI: "Yeni", INCELENIYOR: "İnceleniyor", TAMAMLANDI: "Tamamlandı", REDDEDILDI: "Reddedildi" };
        const katLabel = { HATA: "🐛", OZELLIK: "✨", UI: "🎨", DIGER: "💬" };
        document.getElementById("oneri-sayi").textContent = `${oneriler.length} kayıt (son 90 gün)`;
        const oneriRow = (o) => `
          <div style="padding:10px 0;border-bottom:1px solid #1f2937" data-oneri-id="${o.id}">
            <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px">
              <div style="flex:1;min-width:0">
                <div style="display:flex;gap:6px;align-items:center;margin-bottom:3px">
                  <span>${katLabel[o.kategori]||"💬"}</span>
                  <span style="color:#f9fafb;font-weight:600;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(o.baslik)}</span>
                </div>
                <div style="color:#9ca3af;font-size:12px">${esc(o.kullanici||"Bilinmiyor")} · ${new Date(o.ts).toLocaleDateString("tr-TR")}</div>
                <div style="color:#d1d5db;font-size:12px;margin-top:4px">${esc(o.mesaj)}</div>
                ${o.yonetici_notu ? `<div style="color:#6b7280;font-size:11px;font-style:italic;margin-top:3px">Not: ${esc(o.yonetici_notu)}</div>` : ""}
              </div>
              <div style="flex-shrink:0;display:flex;flex-direction:column;align-items:flex-end;gap:6px">
                <span style="background:${durumRenk[o.durum]};color:#fff;border-radius:4px;padding:2px 8px;font-size:11px;font-weight:600">${durumLabel[o.durum]}</span>
                <button class="btn gri" style="font-size:11px;padding:3px 8px"
                  data-oid="${o.id}" data-odurum="${o.durum}" data-onot="${esc(o.yonetici_notu||'')}">Güncelle</button>
              </div>
            </div>
          </div>`;
        const liste = document.getElementById("oneri-liste");
        if (!liste) return;
        liste.innerHTML = oneriler.length
          ? oneriler.map(oneriRow).join("")
          : `<div class="saha-bos">Henüz öneri yok 🎉</div>`;
        liste.querySelectorAll("button[data-oid]").forEach(btn => {
          btn.addEventListener("click", () =>
            oneriDurumModal(btn.dataset.oid, btn.dataset.odurum, btn.dataset.onot));
        });
      } catch(e) {
        const el = document.getElementById("oneri-liste");
        if (el) el.innerHTML = `<div class="saha-bos">⚠ ${esc(e.message)}</div>`;
      }
    })();
  } catch(e) { main().innerHTML = hata(e); }
}

function oneriDurumModal(oneriId, mevcutDurum, mevcutNot) {
  modal(`
    <h3 style="margin-bottom:14px">Öneri Durumunu Güncelle</h3>
    <label style="display:block;margin-bottom:10px">
      <div class="giris-etiket">Durum</div>
      <select class="giris" id="od-durum">
        <option value="YENI"${mevcutDurum==="YENI"?" selected":""}>Yeni</option>
        <option value="INCELENIYOR"${mevcutDurum==="INCELENIYOR"?" selected":""}>İnceleniyor</option>
        <option value="TAMAMLANDI"${mevcutDurum==="TAMAMLANDI"?" selected":""}>Tamamlandı</option>
        <option value="REDDEDILDI"${mevcutDurum==="REDDEDILDI"?" selected":""}>Reddedildi</option>
      </select>
    </label>
    <label style="display:block;margin-bottom:10px">
      <div class="giris-etiket">Yönetici Notu (opsiyonel)</div>
      <textarea class="giris" id="od-not" rows="3" placeholder="Neden reddedildi, ne zaman hayata geçirilecek…">${esc(mevcutNot||"")}</textarea>
    </label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="od-kaydet">Kaydet</button>
    </div>
  `);
  document.getElementById("od-kaydet").addEventListener("click", async () => {
    const durum = document.getElementById("od-durum").value;
    const yonetici_notu = document.getElementById("od-not").value.trim();
    const btn = document.getElementById("od-kaydet");
    btn.disabled = true; btn.textContent = "Kaydediliyor…";
    try {
      await api(`/api/saha/oneriler/${oneriId}`, { method: "PUT", body: JSON.stringify({ durum, yonetici_notu }) });
      kapatModal();
      uyari("✓ Güncellendi.", true);
      // Refresh the sistem view
      vSistem();
    } catch(e) { btn.disabled = false; btn.textContent = "Kaydet"; uyari(e.message); }
  });
}

function hata(e) {
  logHata("SESSIZ_HATA", { hata_mesaji: (e.message || String(e)).slice(0, 500) });
  return `<div class="saha-bos">⚠ ${esc(e.message || String(e))}</div>`;
}
function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

// Foto küçültme: max 1280px, JPEG 0.72 → base64
function kucult(file) {
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
}

// ── Stiller ──────────────────────────────────────────────────────────────────
function injectStyles() {
  if (document.getElementById("saha-css")) return;
  const css = document.createElement("style");
  css.id = "saha-css";
  css.textContent = `
/* DERIVE_TEMA_V2 */
/* ══════════════════════════════════════════════════════════════════
   DERIVE — TASARIM DILI v1
   Tek token seti · iki tema · mobil-once · her iki shell (bi + saha)

   ⚠ KURALLAR (ihlal edilirse tasarim dagilir):
   1. TEMA CIHAZA BAGLI, MODULE DEGIL. Ayni kisi ayni gun ofiste koyu,
      sahada acik kullanir. Modul temasi diye bir sey YOK.
   2. Her ekran ONCE 340px'te kurulur, sonra genisler. Tersi = yeniden tasarim.
   3. RAKAM = monospace + tabular-nums. HER YERDE. Sayilar birbirinin altinda
      hizalanmali; degisken genislikli rakam karsilastirmayi imkansiz kilar.
   4. TEK FONT AGIRLIGI (400). Vurgu renkle ve boslukla yapilir, kalinla degil.
   5. GRADIENT / GOLGE / GLOW / BLUR YOK. Hicbiri. Zemin duz.
   6. UC DURUM RENGI, iki temada AYNI ANLAM:
        kirmizi = KARAR GEREKIYOR · sari = DIKKAT · yesil = NORMAL
      ⚠ Kontrast degerleri temaya gore AYRI ayarlandi — koyu temanin kirmizisi
        beyaz zeminde ciglik atar, okunmaz. Ayni hex KULLANILAMAZ.
   7. DOKUNMA HEDEFI >= 44px. Fatih Bilen arabada, tek elle kullaniyor.
   8. TABLO YOK (mobilde). Kart var. Tablo hucresi kaynagini soyleyemez, kart soyler.
   ══════════════════════════════════════════════════════════════════ */

:root {
  /* ── DEGISMEYENLER: tema ne olursa olsun sabit ── */
  --mono: ui-monospace, "SF Mono", "JetBrains Mono", Menlo, monospace;
  --sans: -apple-system, BlinkMacSystemFont, "Inter", system-ui, sans-serif;

  --r-sm: 8px;  --r-md: 10px;  --r-lg: 14px;
  --b: 0.5px;                       /* sac teli. 1px kalin durur. */
  --dokunma: 44px;                  /* ⚠ minimum. Altina inme. */

  --a1: 4px;  --a2: 8px;  --a3: 12px;  --a4: 16px;
  --a5: 22px; --a6: 32px; --a7: 48px;

  --hiz: 140ms;
  --egri: cubic-bezier(.2,0,.2,1);

  /* ── OLCEK: mobil taban. Masaustunde --ol-* buyur, hiyerarsi korunur. ── */
  --ol-mini:  11px;
  --ol-kucuk: 13px;
  --ol-govde: 15px;                 /* ⚠ mobilde 14px altina inme, okunmaz */
  --ol-orta:  20px;
  --ol-buyuk: 26px;
  --ol-dev:   34px;                 /* tek hayati sayi (EVA) */
}

/* ══ KOYU TEMA (varsayilan: ofis, masaustu, aksam) ══ */
:root,
[data-tema="koyu"] {
  --zemin-0: #0A0A0B;               /* sayfa */
  --zemin-1: #0F0F11;               /* kart */
  --zemin-2: #15161A;               /* kart uzeri */
  --cizgi:   rgba(255,255,255,.07);
  --cizgi-g: rgba(255,255,255,.14); /* guclu */

  --tx-0: #F5F5F7;                  /* ana */
  --tx-1: #8A8A8F;                  /* ikincil */
  --tx-2: #6E6E76;                  /* ipucu */
  --tx-3: #4A4A50;                  /* zaman damgasi, en sessiz */

  --kirmizi:    #FF6B5A;
  --kirmizi-z:  #15100F;            /* zemin tonu */
  --sari:       #F5B950;
  --sari-z:     #14110A;
  --yesil:      #3ECF8E;
  --yesil-z:    #0A1410;
}

/* ══ ACIK TEMA (saha, gunes altinda, telefon) ══
   ⚠ Renkler KOYULASTIRILDI. Koyu temanin #FF6B5A'si beyazda okunmaz. */
[data-tema="acik"] {
  --zemin-0: #FBFBFA;
  --zemin-1: #FFFFFF;
  --zemin-2: #F4F4F2;
  --cizgi:   rgba(0,0,0,.09);
  --cizgi-g: rgba(0,0,0,.18);

  --tx-0: #16161A;
  --tx-1: #5F5F66;
  --tx-2: #85858C;
  --tx-3: #A8A8AE;

  --kirmizi:    #C43D28;            /* koyu temada #FF6B5A idi */
  --kirmizi-z:  #FDF0ED;
  --sari:       #8A5D06;            /* sari beyazda okunmaz -> kehribar */
  --sari-z:     #FEF6E7;
  --yesil:      #106B4A;
  --yesil-z:    #EAF7F1;
}

/* Cihaz koyu istiyorsa ve kullanici ezmemisse: koyu. */
@media (prefers-color-scheme: light) {
  :root:not([data-tema]) {
    --zemin-0:#FBFBFA; --zemin-1:#FFFFFF; --zemin-2:#F4F4F2;
    --cizgi:rgba(0,0,0,.09); --cizgi-g:rgba(0,0,0,.18);
    --tx-0:#16161A; --tx-1:#5F5F66; --tx-2:#85858C; --tx-3:#A8A8AE;
    --kirmizi:#C43D28; --kirmizi-z:#FDF0ED;
    --sari:#8A5D06;    --sari-z:#FEF6E7;
    --yesil:#106B4A;   --yesil-z:#EAF7F1;
  }
}

* { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }

body {
  margin: 0;
  background: var(--zemin-0);
  color: var(--tx-0);
  font-family: var(--sans);
  font-size: var(--ol-govde);
  font-weight: 400;                 /* ⚠ TEK AGIRLIK. 600/700 YOK. */
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
}

/* ── RAKAM ──────────────────────────────────────────────
   ⚠ Her sayi bunu alir. Istisna yok.                    */
.n {
  font-family: var(--mono);
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.01em;
}
.n-dev   { font-size: var(--ol-dev);   line-height: 1.1; }
.n-buyuk { font-size: var(--ol-buyuk); line-height: 1.15; }
.n-orta  { font-size: var(--ol-orta);  line-height: 1.2; }

.d-kirmizi { color: var(--kirmizi); }
.d-sari    { color: var(--sari); }
.d-yesil   { color: var(--yesil); }

/* ── ETIKET ── */
.etiket {
  font-size: var(--ol-mini);
  letter-spacing: .07em;
  color: var(--tx-2);
  text-transform: uppercase;
}

/* ── KART: tablonun yerini alan sey ──────────────────────
   ⚠ Mobilde tablo YOK. Her satir bir kart.               */
.kart {
  background: var(--zemin-1);
  border: var(--b) solid var(--cizgi);
  border-radius: var(--r-md);
  padding: var(--a3) var(--a4);
}
.kart-karar   { border-left: 2px solid var(--kirmizi); border-radius: 0 var(--r-md) var(--r-md) 0; }
.kart-dikkat  { border-left: 2px solid var(--sari);    border-radius: 0 var(--r-md) var(--r-md) 0; }
.kart-normal  { border-left: 2px solid var(--yesil);   border-radius: 0 var(--r-md) var(--r-md) 0; }

/* kart icinde rakam satiri: etiket solda, sayi sagda, alt alta hizali */
.satir {
  display: flex; justify-content: space-between; align-items: baseline;
  gap: var(--a3);
  font-family: var(--mono); font-variant-numeric: tabular-nums;
  font-size: var(--ol-kucuk);
  padding: 3px 0;
}
.satir > span:first-child { color: var(--tx-1); font-family: var(--sans); }

/* ── DOKUNMA NOKTASI ────────────────────────────────────
   ⚠ Her sayi tiklanabilir. Kaynagini + guvenini soyler,
     geri bildirim alir. Tablo hucresi bunu yapamaz.       */
.dn {
  cursor: pointer;
  border-bottom: 1px dotted var(--cizgi-g);
  transition: border-color var(--hiz) var(--egri);
}
.dn:hover, .dn:active { border-bottom-color: var(--tx-1); }

/* ── DUGME: >= 44px. Tek elle, arabada, eldivenle. ── */
.dg {
  min-height: var(--dokunma);
  padding: 0 var(--a4);
  background: none;
  border: var(--b) solid var(--cizgi-g);
  border-radius: var(--r-sm);
  color: var(--tx-0);
  font-family: var(--sans);
  font-size: var(--ol-govde);
  font-weight: 400;
  cursor: pointer;
  transition: background var(--hiz) var(--egri);
}
.dg:active { background: var(--zemin-2); transform: scale(.985); }
.dg-sessiz { color: var(--tx-1); border-color: var(--cizgi); }

/* ── ASISTAN SERIDI: alta sabit, basparmak bolgesi ── */
.as {
  position: sticky; bottom: 0; z-index: 20;
  background: var(--zemin-0);
  border-top: var(--b) solid var(--cizgi);
  padding: var(--a2) var(--a4) calc(var(--a3) + env(safe-area-inset-bottom));
}
.as-kutu {
  display: flex; align-items: center; gap: var(--a2);
  min-height: var(--dokunma);
  padding: 0 var(--a3);
  background: var(--zemin-1);
  border: var(--b) solid var(--cizgi-g);
  border-radius: var(--r-md);
}
.as-kutu input {
  flex: 1; min-width: 0;
  background: none; border: none; outline: none;
  color: var(--tx-0);
  font-family: var(--sans);
  font-size: 16px;                  /* ⚠ iOS 16px altinda ZOOM yapar. Dokunma. */
}

/* ── SEKME SERIDI (mobil): alt, 5 sekme, ikon + etiket ── */
.sekmeler { display: flex; justify-content: space-around; padding-top: var(--a2); }
.sekme {
  flex: 1; min-height: var(--dokunma);
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  gap: 2px;
  color: var(--tx-3);
  font-size: 10px;
  cursor: pointer;
}
.sekme.aktif { color: var(--tx-0); }

/* ── "MASAUSTU GEREKIR" bildirimi ────────────────────────
   ⚠ Ozur dilemez, gizlemez. Telefonun isi KARAR,
     masaustunun isi KESIF.                                */
.mu-gerek {
  padding: var(--a3) var(--a4);
  background: var(--zemin-2);
  border: var(--b) dashed var(--cizgi-g);
  border-radius: var(--r-md);
  color: var(--tx-1);
  font-size: var(--ol-kucuk);
  line-height: 1.5;
}

/* ── MASAUSTU: genisle. Hiyerarsi AYNI kalir. ── */
@media (min-width: 900px) {
  :root {
    --ol-govde: 15px;
    --ol-orta:  22px;
    --ol-buyuk: 28px;
    --ol-dev:   42px;
  }
  .as { position: sticky; }
  .sekmeler { display: none; }      /* masaustunde yan menu */
}

/* ⚠ HAREKET AZALTMA: erisilebilirlik, tercih degil. */
@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; animation: none !important; }
}

  .saha-app{width:100%;max-width:100%;height:100%;background:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#0f172a;display:flex;flex-direction:column;overflow:hidden}
  .saha-head{flex-shrink:0;z-index:20;background:#0f172a;color:#fff;padding:10px 14px;display:flex;align-items:center;gap:10px;flex-wrap:wrap}
  .saha-title{font-size:17px}.saha-title b{color:#38bdf8}
  .saha-user{margin-left:auto;font-size:12px;opacity:.9;display:flex;align-items:center;gap:6px}
  .saha-role{background:#38bdf8;color:#0f172a;padding:1px 7px;border-radius:9px;font-weight:700;font-size:11px}
  .saha-chips{display:flex;gap:6px}
  .chip{border:1px solid #475569;background:transparent;color:#cbd5e1;border-radius:14px;padding:3px 12px;font-size:12px;cursor:pointer}
  .chip.on{background:#38bdf8;border-color:#38bdf8;color:#0f172a;font-weight:700}
  .saha-main{flex:1;overflow-y:auto;-webkit-overflow-scrolling:touch;padding:12px 12px calc(12px + env(safe-area-inset-bottom,0px))}
  .saha-nav{flex-shrink:0;z-index:20;background:#fff;border-top:1px solid #e2e8f0;display:flex;padding-bottom:env(safe-area-inset-bottom,0px)}
  .saha-tab{flex:1;border:0;background:none;padding:8px 2px 10px;font-size:11px;color:#64748b;display:flex;flex-direction:column;align-items:center;gap:2px;cursor:pointer}
  .saha-tab span{font-size:19px}.saha-tab.on{color:#0284c7;font-weight:700}
  .saha-cta{width:100%;border:0;background:#0284c7;color:#fff;font-size:15px;font-weight:700;padding:13px;border-radius:12px;margin-bottom:12px;cursor:pointer}
  .cta-ikincil{background:#fff;color:#0284c7;border:1.5px solid #0284c7}
  .kirmizi-kenar{border-left:3px solid #ef4444}
  .kart{background:#fff;border-radius:12px;padding:12px;margin-bottom:10px;box-shadow:0 1px 2px rgba(15,23,42,.06);cursor:pointer}
  .kart.gecmis{border-left:3px solid #ef4444}
  @keyframes kayitVurgu{0%,100%{box-shadow:0 1px 2px rgba(15,23,42,.06)}50%{box-shadow:0 0 0 3px #0284c7,0 0 18px #0284c766}}
  .kayit-vurgu{animation:kayitVurgu 1s ease-in-out 3}
  .kart.secili{outline:3px solid #0284c7;outline-offset:-1px;background:#f0f9ff}
  .kart-ust{display:flex;justify-content:space-between;align-items:center;gap:8px;font-size:14px}
  .kart-alt{display:flex;flex-wrap:wrap;gap:8px;margin-top:5px;font-size:12px;color:#64748b}
  .kart-not{margin-top:7px;font-size:12px;color:#475569;background:#f8fafc;border-radius:7px;padding:7px}
  .kart-btnlar{display:flex;gap:8px;margin-top:9px}
  .rozet{color:#fff;font-size:10px;padding:2px 8px;border-radius:9px;white-space:nowrap}
  .rozet-cizgi{font-size:10px;padding:1px 7px;border-radius:9px;border:1px solid;white-space:nowrap}
  .erp-kod{background:#e2e8f0;border-radius:6px;padding:1px 6px;font-family:monospace;font-size:11px}
  .muk-grup{background:#fff;border-radius:12px;margin-bottom:10px;box-shadow:0 1px 3px rgba(15,23,42,.08);overflow:hidden}
  .muk-grup-baslik{display:flex;justify-content:space-between;align-items:center;padding:10px 12px;background:#f8fafc;border-bottom:1px solid #e2e8f0}
  .muk-grup-baslik-sol{display:flex;flex-direction:column;gap:2px}
  .muk-grup-baslik-erp{font-size:13px;font-weight:600;color:#0f172a}
  .muk-radio{display:flex;align-items:center;gap:10px;padding:8px 12px;border-bottom:1px solid #f1f5f9;cursor:pointer;transition:background .1s}
  .muk-radio:last-child{border-bottom:none}
  .muk-radio:hover{background:#f8fafc}
  .muk-radio-secili{background:#f0f9ff}
  .muk-radio input[type=radio]{accent-color:#0284c7;flex-shrink:0}
  .muk-radio-icerik{display:flex;justify-content:space-between;align-items:center;flex:1;gap:8px;min-width:0}
  .muk-radio-ad{font-size:13px;color:#0f172a;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .muk-radio-meta{font-size:11px;color:#94a3b8;white-space:nowrap;flex-shrink:0}
  .muk-grup-btn{padding:8px 12px 12px}
  .saha-bos{text-align:center;color:#94a3b8;padding:36px 12px;font-size:14px}
  .saha-load{text-align:center;color:#94a3b8;padding:36px}
  .giris{width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:9px;padding:10px;font-size:16px;margin:3px 0 9px;background:#fff}
  .saha-app label{font-size:12px;color:#475569;font-weight:600;display:block}
  .yanyana{display:flex;gap:9px}.yanyana>*{flex:1}
  .yanyana4{display:grid;grid-template-columns:repeat(4,1fr);gap:7px}
  .btn{border:0;background:#0284c7;color:#fff;border-radius:9px;padding:11px 15px;font-size:13px;font-weight:700;cursor:pointer}
  .btn.gri{background:#e2e8f0;color:#334155}
  .btn.cizgili{background:#fff;color:#0284c7;border:1.5px solid #0284c7}
  .btn.kucuk{padding:7px 11px;font-size:12px}
  .btn.kirmizi-btn{background:#ef4444}
  .dosya-btn{display:inline-flex;align-items:center;justify-content:center;text-align:center}
  .modal-fon{position:fixed;inset:0;background:rgba(15,23,42,.55);z-index:50;display:flex;align-items:flex-end;justify-content:center}
  .modal-kutu{background:#fff;color-scheme:light;border-radius:18px 18px 0 0;width:100%;max-width:min(95vw,760px);max-height:88vh;overflow-y:auto;padding:18px 16px 26px;color:#0f172a}
  @media(max-width:640px){.modal-kutu{max-width:100vw;border-radius:14px 14px 0 0;max-height:92vh;padding:14px 10px 0}.modal-kutu .modal-btnlar{position:sticky;bottom:0;background:#fff;display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap;margin:10px -10px 0;padding:10px 10px calc(14px + env(safe-area-inset-bottom,0px));border-top:1px solid #eef2f6;z-index:5}}
  .modal-kutu table{border-collapse:collapse;width:100%}
  .modal-kutu table thead tr{background:#e2e8f0 !important}
  .modal-kutu table thead th{color:#1e293b !important;font-weight:600;padding:6px 8px}
  .modal-kutu table tbody tr{background:#fff !important}
  .modal-kutu table tbody td{color:#0f172a !important;background:#fff !important;padding:6px 8px;border-bottom:1px solid #e2e8f0}
  .modal-kutu table tfoot tr{background:#f1f5f9 !important}
  .modal-kutu table tfoot td{color:#0f172a !important;background:#f1f5f9 !important;padding:7px 8px}
  @media(min-width:640px){.modal-fon{align-items:center}.modal-kutu{border-radius:18px}}
  .modal-kutu h3{margin:0 0 13px;font-size:16px;color:#0f172a !important;opacity:1 !important;text-shadow:none !important}
  .modal-kutu h4{color:#475569 !important}
  .saha-app .giris,.modal-kutu .giris{color:#0f172a !important;background:#fff !important;border:1px solid #cbd5e1 !important;box-shadow:none !important;font-size:16px !important}
  .saha-app .giris:focus,.modal-kutu .giris:focus{border-color:#0284c7 !important;outline:none}
  .saha-app .giris::placeholder,.modal-kutu .giris::placeholder{color:#94a3b8 !important;opacity:1 !important}
  .modal-kutu b,.modal-kutu strong{color:inherit}
  .saha-app h3,.saha-app h4{font-family:inherit}
  .modal-btnlar{display:flex;gap:9px;margin-top:15px;justify-content:flex-end;flex-wrap:wrap}
  .modal-butonlar{display:flex;flex-direction:column;gap:8px;margin-top:12px}
  .btn.tam{width:100%;text-align:center}
  .ara-sonuc{max-height:46vh;overflow-y:auto}
  .ara-satir{padding:10px 8px;border-bottom:1px solid #f1f5f9;cursor:pointer;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
  .ara-satir small{color:#94a3b8;width:100%}
  .ara-satir.yeni{color:#0284c7}
  .cipler{display:flex;flex-wrap:wrap;gap:6px;margin:5px 0 10px}
  .cip{border:1px solid #cbd5e1;background:#fff;color:#475569;border-radius:13px;padding:4px 11px;font-size:12px;cursor:pointer}
  .cip.on{background:#0284c7;border-color:#0284c7;color:#fff;font-weight:700}
  .cip-ekle{border:1px dashed #cbd5e1;border-radius:13px;padding:4px 9px;font-size:12px;width:70px}
  .alan-grup{margin-bottom:6px}.alan-baslik{font-size:12px;color:#475569;font-weight:600}
  .mini-durum{font-size:12px;color:#64748b;margin:4px 0}
  .foto-izgara{display:flex;flex-wrap:wrap;gap:7px;margin:8px 0}
  .foto-izgara img{width:74px;height:74px;object-fit:cover;border-radius:9px}
  .det-satir{display:flex;justify-content:space-between;gap:10px;padding:6px 0;border-bottom:1px solid #f1f5f9;font-size:13px}
  .det-satir span{color:#64748b}
  .det-not{background:#f8fafc;border-radius:9px;padding:10px;font-size:13px;margin-top:9px;white-space:pre-wrap}
  .bolum-baslik{margin:17px 0 9px;font-size:13px;color:#475569;text-transform:uppercase;letter-spacing:.4px}
  .esik-kutu{background:#fff;border-radius:11px;padding:10px 12px;font-size:12px;color:#475569;margin-bottom:11px;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
  .bakiye-satir{margin-top:6px;font-size:12px;color:#475569}
  .kirmizi{color:#ef4444;font-weight:700}
  .bilgi-kutu{background:#f0f9ff;border:1px solid #bae6fd;border-radius:9px;padding:10px;font-size:13px;margin:9px 0}
  .ozet-izgara{display:grid;grid-template-columns:repeat(auto-fit,minmax(100px,1fr));gap:9px;margin-bottom:6px}
  .ozet-kut{background:#fff;border-radius:11px;padding:13px 9px;text-align:center}
  .ozet-kut b{display:block;font-size:21px;color:#0284c7}
  .ozet-kut span{font-size:11px;color:#64748b}
  .tablo{width:100%;background:#fff;border-radius:11px;border-collapse:collapse;overflow:hidden;font-size:12px}
  .tablo th{background:#f8fafc;text-align:left;padding:8px;color:#475569}
  .tablo td{padding:8px;border-top:1px solid #f1f5f9}
  .saha-toast{position:fixed;bottom:calc(92px + env(safe-area-inset-bottom,0px));left:50%;transform:translateX(-50%);background:#0f172a;color:#fff;padding:11px 17px;border-radius:11px;font-size:13px;z-index:20000;max-width:88vw;box-shadow:0 6px 18px rgba(0,0,0,.25)}
  .saha-toast.ok{background:#10b981}
  @media(max-width:390px){
    .saha-head{padding:8px 10px;gap:8px}
    .saha-main{padding:8px 8px calc(8px + env(safe-area-inset-bottom,0px))}
    .giris{font-size:16px;padding:9px}
    .yanyana4{grid-template-columns:repeat(2,1fr)}
    .modal-kutu{padding:14px 12px 22px}
    .ara-sonuc{max-height:40vh}
  }
  @media(max-width:360px){
    .btn{padding:9px 12px;font-size:12px}
    .cipler{gap:4px}
    .cip{padding:3px 8px;font-size:11px}
  }
  @keyframes sesNabiz{0%,100%{opacity:1}50%{opacity:.3}}
  .ses-wrap{position:relative;display:block}
  .ses-btn{position:absolute;right:7px;bottom:9px;background:none;border:none;cursor:pointer;font-size:19px;line-height:1;padding:2px;border-radius:6px;color:#94a3b8;transition:color .15s}
  .ses-btn:hover{color:#3b82f6}
  .ses-btn.dinliyor{color:#ef4444;animation:sesNabiz .7s ease-in-out infinite}
  .ses-wrap textarea{padding-right:34px}
  .takvim-kont{background:#fff;border-radius:13px;padding:12px;margin-bottom:12px;box-shadow:0 1px 2px rgba(15,23,42,.06)}
  .tak-baslik{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px}
  .tak-ay-adi{font-size:14px;font-weight:700;color:#0f172a;text-transform:capitalize}
  .tak-gunler-baslik{display:grid;grid-template-columns:repeat(7,1fr);text-align:center;font-size:11px;color:#94a3b8;font-weight:600;margin-bottom:4px}
  .tak-hb{padding:3px 0}
  .tak-izgara{display:flex;flex-direction:column;gap:3px}
  .tak-hafta{display:grid;grid-template-columns:repeat(7,1fr);gap:2px}
  .tak-gun{min-height:40px;border-radius:9px;display:flex;flex-direction:column;align-items:center;justify-content:center;cursor:pointer;font-size:13px;color:#334155;position:relative;gap:2px;padding:2px 0}
  .tak-gun:hover{background:#f1f5f9}
  .tak-gun.bos{pointer-events:none}
  .tak-gun.bugun .tak-sayi{background:#0284c7;color:#fff;border-radius:50%;width:24px;height:24px;display:flex;align-items:center;justify-content:center;font-weight:700}
  .tak-gun.secili{background:#e0f2fe;outline:2px solid #0284c7;outline-offset:-2px}
  .tak-gun.gecmis-gun{color:#94a3b8}
  .tak-rozet{background:#f97316;color:#fff;font-size:9px;font-weight:700;border-radius:9px;padding:0 5px;min-width:16px;text-align:center;line-height:16px}
  .tak-gun-panel{background:#fff;border-radius:13px;padding:12px;box-shadow:0 1px 2px rgba(15,23,42,.06)}
  .tak-gun-baslik{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;font-size:14px}`;
  document.head.appendChild(css);
}
