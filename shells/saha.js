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
  S = {
    container, me, role, headers,
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
    loadView("ziyaretler");
  }
}

// ── API yardımcıları ─────────────────────────────────────────────────────────
async function api(path, options = {}) {
  const res = await fetch(path, {
    ...options,
    headers: { "Content-Type": "application/json", ...S.headers(), ...(options.headers || {}) }
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `İstek başarısız (${res.status})`);
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
function layout() {
  const tabs = [
    ["ziyaretler", "📋", "Ziyaretler"], ["plan", "🗓️", "Plan"],
    ["musteriler", "🏪", "Müşteri"], ["iskonto", "💰", "Teklif"], ["rapor", "📊", "Rapor"],
    ...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Temsilci"]] : [])
  ];
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
      ${tabs.map(([id, ico, l]) => `<button class="saha-tab${id === "ziyaretler" ? " on" : ""}" data-v="${id}"><span>${ico}</span>${l}</button>`).join("")}
    </nav>
    <div id="saha-modal"></div>
  </div>`;
}

function wireNav() {
  S.container.querySelectorAll(".saha-tab").forEach(b =>
    b.addEventListener("click", () => {
      S.container.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x === b));
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
    window.location.href = "/";
  });
}

function main() { return S.container.querySelector("#saha-main"); }
function loadView(v) {
  S.view = v;
  const m = main();
  m.scrollTop = 0; // reset scroll position when switching tabs
  m.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
  return ({ ziyaretler: vZiyaretler, plan: vPlan, musteriler: vMusteriler, iskonto: vIskonto, rapor: vRapor, temsilciler: vTemsilciler }[v] || vZiyaretler)();
}
function tipQS() { return S.semsiye ? `&tip=${S.semsiye}` : ""; }

// Tab badge: shows action-count on a nav tab
function tabBadge(v, sayi) {
  const tab = S.container.querySelector(`.saha-tab[data-v="${v}"]`);
  if (!tab) return;
  const mevcut = tab.querySelector(".tab-rozet");
  if (sayi > 0) {
    if (mevcut) { mevcut.textContent = sayi; }
    else { tab.insertAdjacentHTML("beforeend", `<sup class="tab-rozet" style="background:#ef4444;color:#fff;border-radius:9px;padding:0 5px;font-size:10px;margin-left:2px;vertical-align:super">${sayi}</sup>`); }
  } else {
    mevcut?.remove();
  }
}

// ── ZİYARETLER ───────────────────────────────────────────────────────────────
async function vZiyaretler() {
  try {
    const { ziyaretler } = await api(`/api/saha/ziyaretler?durum=TAMAMLANDI${tipQS()}`);
    S.ziyaretler = ziyaretler;
    // "Bugün Ziyaret" tile tıklandıysa sadece bugünküleri göster
    const bugunFiltre = !!window.__sahaGunFiltre;
    window.__sahaGunFiltre = false;
    const bugunISO = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const liste = bugunFiltre
      ? ziyaretler.filter(z => z.ziyaret_tarihi && String(z.ziyaret_tarihi).slice(0, 10) === bugunISO)
      : ziyaretler;
    const filtreBandi = bugunFiltre
      ? `<div style="background:#dbeafe;border:1px solid #93c5fd;border-radius:9px;padding:8px 12px;font-size:12px;color:#1d4ed8;margin-bottom:10px">
           📅 Bugünkü ziyaretler — ${liste.length} kayıt
           <button style="background:none;border:0;color:#1d4ed8;font-size:11px;cursor:pointer;text-decoration:underline;margin-left:8px" id="filtre-kaldir">Tümünü göster</button>
         </div>`
      : "";
    main().innerHTML = `
      <button class="saha-cta" id="yeni-ziyaret">＋ Yeni Ziyaret</button>
      ${filtreBandi}
      ${liste.length ? liste.map(zKart).join("") : `<div class="saha-bos">${bugunFiltre ? "Bugün tamamlanan ziyaret yok." : "Henüz ziyaret yok. İlk ziyaretini kaydet!"}</div>`}`;
    main().querySelector("#yeni-ziyaret").addEventListener("click", () => musteriSecModal(z => ziyaretFormModal(z, "kaydet")));
    main().querySelector("#filtre-kaldir")?.addEventListener("click", () => loadView("ziyaretler"));
    main().querySelectorAll("[data-zid]").forEach(el =>
      el.addEventListener("click", () => ziyaretDetayModal(el.dataset.zid)));
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
  const z = S.ziyaretler.find(x => x.id === zid) || {};
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
    <div id="det-fotolar" class="foto-izgara"></div>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn" id="det-teklif">＋ Teklif</button>
    </div>`);
  document.getElementById("det-teklif")?.addEventListener("click", () => {
    kapatModal(); teklifFormModal({ id: z.musteri_id, firma: z.firma }, zid);
  });
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
    <h3>${musteriKodu ? "ERP Cariyi Sahaya Ekle" : "Yeni Müşteri"}</h3>
    ${musteriKodu ? `<div class="bilgi-kutu">ERP kodu <b>${esc(musteriKodu)}</b> bağlanacak — bakiye ve satış geçmişi otomatik görünür.</div>` : ""}
    <label>Firma<input class="giris" id="ym-firma" value="${esc(firma)}"></label>
    <label>Tip
      <select class="giris" id="ym-tip">
        <option value="">Seçin…</option>
        <option value="TUKETICI" ${S.semsiye === "TUKETICI" ? "selected" : ""}>Tüketici (PSR bayi)</option>
        <option value="TICARI" ${S.semsiye === "TICARI" ? "selected" : ""}>Ticari (TBR/OTR)</option>
      </select></label>
    <div class="yanyana">
      <label>İl<input class="giris" id="ym-il"></label>
      <label>İlçe<input class="giris" id="ym-ilce"></label>
    </div>
    <label>Segment<input class="giris" id="ym-segment" placeholder="bayi / lojistik / maden…"></label>
    <div class="yanyana">
      <label>Yetkili<input class="giris" id="ym-yetkili"></label>
      <label>Telefon<input class="giris" id="ym-tel"></label>
    </div>
    <div class="yanyana">
      <label>VKN (Vergi No)<input class="giris" id="ym-vkn" inputmode="numeric" placeholder="10 hane"></label>
      <label>TC Kimlik No<input class="giris" id="ym-tcno" inputmode="numeric" placeholder="11 hane"></label>
    </div>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="ym-kaydet">Kaydet ve Devam</button>
    </div>`);
  document.getElementById("ym-kaydet").addEventListener("click", async () => {
    const g = id => document.getElementById(id).value.trim();
    if (!g("ym-firma") || !g("ym-tip")) { uyari("Firma ve tip zorunlu."); return; }
    try {
      const { musteri } = await api("/api/saha/musteriler", {
        method: "POST",
        body: JSON.stringify({
          firma: g("ym-firma"), tip: g("ym-tip"), il: g("ym-il") || null, ilce: g("ym-ilce") || null,
          segment: g("ym-segment") || null, yetkili: g("ym-yetkili") || null,
          telefon: g("ym-tel") || null, vergi_no: g("ym-vkn") || null,
          tc_no: g("ym-tcno") || null, musteri_kodu: musteriKodu
        })
      });
      kapatModal(); devam(musteri);
    } catch (e) { uyari(e.message); }
  });
}

// ── ZİYARET FORMU (kaydet = tamamlandı | planla = ileri tarih) ──────────────
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
      <div id="zf-foto-liste" class="foto-izgara"></div>` : ""}
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      ${mod !== "planla" ? `<button class="btn cizgili" id="zf-planla">🗓️ Planla</button>` : ""}
      <button class="btn" id="zf-kaydet">${mod === "planla" ? "Planla" : "✓ Kaydet"}</button>
    </div>`);

  // Pre-select chips from customer profile (ticari only)
  if (!tuketici) {
    const mSek = Array.isArray(mus.sektorler) ? mus.sektorler : [];
    const mTed = Array.isArray(mus.tedarikci_markalar) ? mus.tedarikci_markalar : [];
    document.querySelectorAll('#zf-sektorler .cip').forEach(b => { if (mSek.includes(b.dataset.v)) b.classList.add('on'); });
    document.querySelectorAll('#zf-tedarikci .cip').forEach(b => { if (mTed.includes(b.dataset.v)) b.classList.add('on'); });
  }

  const konum = { lat: null, lng: null };
  const fotolar = [];
  document.getElementById("zf-konum")?.addEventListener("click", () => {
    const st = document.getElementById("zf-konum-durum");
    st.textContent = "Konum alınıyor…";
    navigator.geolocation.getCurrentPosition(
      p => { konum.lat = p.coords.latitude; konum.lng = p.coords.longitude; st.textContent = `✓ Konum alındı (±${Math.round(p.coords.accuracy)}m)`; },
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
        await api(`/api/saha/ziyaretler/${ziyaret.id}`, {
          method: "PUT", body: JSON.stringify({ action: "checkin", lat: konum.lat, lng: konum.lng })
        }).catch(() => {});
      }
      for (const f of fotolar) {
        await api(`/api/saha/ziyaretler/${ziyaret.id}/foto`, {
          method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" })
        }).catch(() => {});
      }
      const durumSecim = document.getElementById("zf-durum")?.value;
      if (durumSecim) {
        await api(`/api/saha/musteriler/${mus.id}`, {
          method: "PUT", body: JSON.stringify({ durum: durumSecim })
        }).catch(() => {});
      }
      // Update customer profile with sektorler + tedarikci_markalar (ticari only)
      if (!tuketici) {
        await api(`/api/saha/musteriler/${mus.id}`, {
          method: "PUT", body: JSON.stringify({ sektorler: sektorSecim, tedarikci_markalar: tedarikSecim })
        }).catch(() => {});
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
      // Update nokta durumu (tuketici)
      const durumSecim = tuketici ? document.getElementById("pt-durum")?.value : null;
      if (durumSecim && z.musteri_id) {
        await api(`/api/saha/musteriler/${z.musteri_id}`, { method: "PUT", body: JSON.stringify({ durum: durumSecim }) }).catch(() => {});
      }
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
  const yukle = async (q = "") => {
    const { musteriler } = await api(`/api/saha/musteriler?q=${encodeURIComponent(q)}${tipQS()}`);
    S.musteriler = musteriler;
    document.getElementById("mus-liste").innerHTML = musteriler.length ? musteriler.map(m => {
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
    }).join("") : `<div class="saha-bos">Müşteri bulunamadı.</div>`;

    document.querySelectorAll("[data-mid]").forEach(el => el.addEventListener("click", () => {
      const m = S.musteriler.find(x => x.id === el.dataset.mid);
      if (S.birlestirSecim) {
        // Birleştirme modu: dokunma = seç/bırak
        if (S.birlestirSecim.has(m.id)) { S.birlestirSecim.delete(m.id); el.classList.remove("secili"); }
        else { S.birlestirSecim.add(m.id); el.classList.add("secili"); }
        const s = document.getElementById("birlestir-sayi");
        if (s) s.textContent = `${S.birlestirSecim.size} kart seçili`;
        return;
      }
      musteriDetayModal(m);
    }));
  };
  S.birlestirSecim = null; // null = normal mod; Set = birleştirme modu
  main().innerHTML = `
    <button class="saha-cta" id="yeni-musteri">＋ Müşteri</button>
    ${S.role !== "rep" ? `<div id="bakim-paneli"></div>` : ""}
    <input class="giris" id="mus-filtre" placeholder="Müşteri ara…" autocomplete="off">
    <div id="mus-liste"><div class="saha-load">Yükleniyor…</div></div>`;
  if (S.role !== "rep") bakimPaneliYukle();
  // ＋ Müşteri: search/create without requiring a visit intent
  main().querySelector("#yeni-musteri").addEventListener("click", () =>
    musteriSecModal(async m => {
      await loadView("musteriler");
      musteriDetayModal(m);
    }));
  let t = null;
  document.getElementById("mus-filtre").addEventListener("input", ev => {
    clearTimeout(t); t = setTimeout(() => yukle(ev.target.value.trim()), 300);
  });
  try { await yukle(); } catch (e) { main().innerHTML = hata(e); }
}

// ── Veri bakımı: eşleştirme onayı + mükerrer birleştirme (GM/müdür) ─────────
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
    ${m.kimlik_vergi_no ? `<div class="det-satir"><span>VKN</span><b>${esc(m.kimlik_vergi_no)}</b></div>` : ""}
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
      ${yonetici && bekleyenler.length ? `
        <h4 class="bolum-baslik" style="color:#f59e0b">⏳ Onay Bekleyen (${bekleyenler.length})</h4>
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
      <div style="overflow-x:auto;border-radius:8px;border:1px solid #e2e8f0">
        <div style="display:grid;grid-template-columns:28px 1fr 56px ${approverMode ? "80px 110px" : "80px 90px"} 90px 64px${approverMode ? " auto" : ""};background:#e2e8f0;padding:6px 0;font-size:11px;font-weight:600;color:#1e293b">
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
          <div style="display:grid;grid-template-columns:28px 1fr 56px ${approverMode ? "80px 110px" : "80px 90px"} 90px 64px${approverMode ? " auto" : ""};padding:8px 0;border-top:1px solid #f1f5f9;font-size:12px;background:#fff;color:#0f172a;align-items:center">
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
                    style="width:68px;padding:3px 6px;border:1px solid #cbd5e1;border-radius:5px;font-size:12px;text-align:right;color:#0f172a;background:#fff">`
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
        <div style="display:grid;grid-template-columns:28px 1fr 56px ${approverMode ? "80px 110px" : "80px 90px"} 90px 64px${approverMode ? " auto" : ""};padding:8px 0;border-top:1px solid #e2e8f0;background:#f8fafc;font-size:12px;color:#0f172a">
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
    const listeFiyati = gNum("tf-liste-fiyati");
    const ekIsk       = gNum("tf-ek-iskonto") || 0;
    const adet        = Number(g("tf-adet")) || 1;
    const birim       = listeFiyati != null ? Math.round(listeFiyati * (1 - ekIsk / 100) * 100) / 100 : null;
    return {
      kalem_kodu            : g("tf-kalem-kodu")   || null,
      marka, model          : g("tf-model")         || null,
      ebat                  : g("tf-ebat")           || null,
      kategori              : g("tf-kategori")       || null,
      sezon                 : g("tf-sezon")          || null,
      alt_grup              : g("tf-kategori") === "TICARI" ? (g("tf-altgrup") || null) : null,
      adet, liste_fiyati    : listeFiyati,
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
    ["tf-kalem-kodu","tf-marka","tf-model","tf-ebat","tf-liste-fiyati",
     "tf-ek-iskonto","tf-tesvik-garantili","tf-tesvik-maksimum",
     "tf-destek-pct","tf-kampanya-id","tf-kampanya-turu","tf-kampanya-deger","tf-not"]
      .forEach(id => { const el = document.getElementById(id); if (el) el.value = ""; });
    document.getElementById("tf-adet").value = "4";
    document.getElementById("tf-liste-fiyat-goster").textContent = "—";
    document.getElementById("tf-liste-fiyat-goster").style.color = "#94a3b8";
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
    try {
      await api("/api/saha/teklifler", {
        method: "POST",
        body: JSON.stringify({
          musteri_id: mus.id,
          ziyaret_id: ziyaretId,
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
  const bugun = simdi.toISOString().slice(0, 10);

  main().innerHTML = `
    <div id="rp-haftalik"></div>
    <div style="padding:10px 12px 0">
      <div style="display:flex;gap:5px;margin-bottom:8px">
        ${[["7G",7],["30G",30],["3A",90],["1Y",365]].map(([l,d]) =>
          `<button class="rp-preset" data-days="${d}" style="flex:1;padding:5px 0;border:1px solid #e5e7eb;border-radius:6px;background:#fff;font-size:12px;font-weight:500;color:#374151;cursor:pointer">${l}</button>`
        ).join("")}
      </div>
      <div style="display:flex;align-items:center;gap:6px">
        <button id="rp-prev" style="padding:4px 10px;border:1px solid #e5e7eb;border-radius:6px;background:#fff;cursor:pointer;font-size:15px;color:#374151">‹</button>
        <input type="date" class="giris" id="rp-from" value="${ayBasi}" style="flex:1;font-size:16px;padding:5px 8px">
        <span style="color:#9ca3af;font-size:12px">→</span>
        <input type="date" class="giris" id="rp-to" value="${bugun}" style="flex:1;font-size:16px;padding:5px 8px">
        <button id="rp-next" style="padding:4px 10px;border:1px solid #e5e7eb;border-radius:6px;background:#fff;cursor:pointer;font-size:15px;color:#374151">›</button>
      </div>
    </div>
    <div id="rp-icerik" style="padding-bottom:24px"><div class="saha-load">Yükleniyor…</div></div>
    ${["manager","admin"].includes(S.role) ? `
    <div id="rp-saha-sesi" style="padding:0 12px 80px">
      <div style="font-size:11px;font-weight:700;color:#374151;margin:8px 0 10px;padding-left:10px;border-left:3px solid #8b5cf6;text-transform:uppercase;letter-spacing:0.5px">Saha Haritası & Sesi 🤖</div>
      <div style="background:#fff;border:1px solid #e5e7eb;border-radius:12px;padding:14px">

        <!-- Turkey Map — Layer + Metric Controls -->
        <div style="margin-bottom:12px">
          <!-- Layer toggle -->
          <div style="display:flex;gap:5px;margin-bottom:7px" id="ss-layer-bar">
            ${[["ziyaret","📍 Ziyaret"],["teklif","💼 Teklif"],["satis","💰 Satış"]].map(([v,l],i) =>
              `<button class="ss-layer-btn" data-l="${v}" style="flex:1;padding:4px 0;border:1.5px solid ${i===0?"#8b5cf6":"#e5e7eb"};background:${i===0?"#8b5cf6":"#fff"};color:${i===0?"#fff":"#374151"};border-radius:8px;font-size:11px;font-weight:${i===0?"700":"500"};cursor:pointer">${l}</button>`
            ).join("")}
          </div>
          <!-- Sub-controls: shown conditionally by layer -->
          <div id="ss-layer-sub" style="margin-bottom:6px"></div>
          <!-- Map -->
          <div id="ss-harita" style="position:relative;background:#f8fafc;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden;min-height:60px">
            <div style="padding:16px;text-align:center;font-size:12px;color:#94a3b8">Harita yükleniyor…</div>
          </div>
          <div id="ss-sehir-info" style="display:none;font-size:12px;font-weight:500;color:#1d4ed8;background:#eff6ff;border:1px solid #bfdbfe;border-radius:8px;padding:8px 10px;margin-top:6px"></div>
        </div>

        <!-- Text Scope Selectors -->
        <div style="font-size:11px;color:#6b7280;margin-bottom:6px">Veya kapsam seçin:</div>
        <div style="display:flex;gap:6px;margin-bottom:12px;flex-wrap:wrap" id="ss-kapsam-bar">
          ${[["tum","Tüm KRB"],["temsilci","Temsilci"],["durum","Pasif/Riskli"],["musteri","Müşteri"]].map(([v,l]) =>
            `<button class="ss-kapsam-btn" data-k="${v}" style="padding:5px 14px;border-radius:20px;border:1.5px solid #e5e7eb;background:#fff;color:#374151;font-size:12px;font-weight:600;cursor:pointer">${l}</button>`
          ).join("")}
        </div>
        <div id="ss-filtre" style="margin-bottom:10px"></div>

        <!-- Period Selector -->
        <div style="font-size:11px;color:#6b7280;margin-bottom:6px">Dönem <span style="color:#8b5cf6;font-size:10px">(önceki dönemle karşılaştırır)</span></div>
        <div style="display:flex;gap:5px;margin-bottom:12px" id="ss-donem-bar">
          ${[["30G",30],["90G",90],["1Y",365],["Tümü",0]].map(([l,d],i) =>
            `<button class="ss-donem-btn" data-d="${d}" style="flex:1;padding:5px 0;border:1.5px solid ${i===0?"#8b5cf6":"#e5e7eb"};background:${i===0?"#f5f3ff":"#fff"};color:${i===0?"#7c3aed":"#374151"};border-radius:8px;font-size:12px;font-weight:${i===0?"700":"400"};cursor:pointer">${l}</button>`
          ).join("")}
        </div>

        <button id="ss-analiz-btn" class="btn" style="width:100%;background:#8b5cf6;margin-bottom:0">🤖 Saha Sesini Analiz Et</button>
        <div id="ss-sonuc" style="display:none;margin-top:12px"></div>
      </div>
    </div>` : ""}`;

  // Bu Hafta — forward-looking section loaded in parallel
  (async () => {
    try {
      const hafta7 = new Date(simdi); hafta7.setDate(hafta7.getDate() + 7);
      const hafta7Iso = hafta7.toISOString().slice(0, 10);
      const [{ ziyaretler: planlar }, { teklifler }] = await Promise.all([
        api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`),
        api("/api/saha/teklifler")
      ]);
      const gecmis    = planlar.filter(z => z.planlanan_tarih && z.planlanan_tarih.slice(0, 10) < bugun);
      const buhafta   = planlar.filter(z => { const d = z.planlanan_tarih?.slice(0, 10); return d && d >= bugun && d <= hafta7Iso; });
      const onaylandi = teklifler.filter(t => t.durum === "ONAYLANDI");
      const kutu = document.getElementById("rp-haftalik");
      if (!kutu) return;
      if (!gecmis.length && !buhafta.length && !onaylandi.length) { kutu.innerHTML = ""; return; }
      kutu.innerHTML = `
        <div style="padding:10px 12px 0">
          <div style="background:#f8fafc;border:1px solid #e5e7eb;border-radius:10px;padding:10px 12px">
            <div style="font-size:11px;font-weight:700;color:#64748b;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.5px">Bu Hafta</div>
            <div class="ozet-izgara" style="margin-bottom:${gecmis.length || onaylandi.length ? "6px" : "0"}">
              ${gecmis.length  ? `<div class="ozet-kut" style="background:#fef2f2;cursor:pointer" id="rp-gecmis-kut"><b style="color:#ef4444">${gecmis.length}</b><span>Gecikmiş Plan ⚠</span></div>` : ""}
              ${buhafta.length ? `<div class="ozet-kut"><b>${buhafta.length}</b><span>Bu Hafta Planlı</span></div>` : ""}
              ${onaylandi.length ? `<div class="ozet-kut" style="background:#f0f9ff;cursor:pointer" id="rp-onaylandi-kut"><b style="color:#0ea5e9">${onaylandi.length}</b><span>Sunulmayı Bekliyor</span></div>` : ""}
            </div>
            ${gecmis.length    ? `<div style="font-size:11px;color:#94a3b8">⚠ ${gecmis.slice(0,3).map(z => `<b>${esc(z.firma)}</b> (${new Date(z.planlanan_tarih).toLocaleDateString("tr-TR")})`).join(" · ")}${gecmis.length > 3 ? ` +${gecmis.length - 3} daha` : ""}</div>` : ""}
            ${onaylandi.length ? `<div style="font-size:11px;color:#0369a1;margin-top:2px">📋 ${onaylandi.slice(0,3).map(t => `<b>${esc(t.firma)}</b>`).join(", ")}${onaylandi.length > 3 ? ` +${onaylandi.length - 3} daha` : ""}</div>` : ""}
          </div>
        </div>`;
      kutu.querySelector("#rp-gecmis-kut")?.addEventListener("click", () => {
        S.container.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x.dataset.v === "plan"));
        loadView("plan");
      });
      kutu.querySelector("#rp-onaylandi-kut")?.addEventListener("click", () => {
        S.container.querySelectorAll(".saha-tab").forEach(x => x.classList.toggle("on", x.dataset.v === "iskonto"));
        loadView("iskonto");
      });
    } catch { const k = document.getElementById("rp-haftalik"); if (k) k.innerHTML = ""; }
  })();

  // Preset quick-select buttons
  main().querySelectorAll(".rp-preset").forEach(btn => {
    btn.addEventListener("click", () => {
      const days = Number(btn.dataset.days);
      const t = new Date(), f = new Date(); f.setDate(f.getDate() - days + 1);
      document.getElementById("rp-from").value = f.toISOString().slice(0, 10);
      document.getElementById("rp-to").value   = t.toISOString().slice(0, 10);
      yukle();
    });
  });

  // Prev / next: shift by current range duration
  function shiftRange(dir) {
    const fEl = document.getElementById("rp-from"), tEl = document.getElementById("rp-to");
    const f = new Date(fEl.value + "T12:00:00"), t = new Date(tEl.value + "T12:00:00");
    const diff = Math.round((t - f) / 86400000) + 1;
    f.setDate(f.getDate() + dir * diff); t.setDate(t.getDate() + dir * diff);
    fEl.value = f.toISOString().slice(0, 10); tEl.value = t.toISOString().slice(0, 10);
    yukle();
  }
  document.getElementById("rp-prev").addEventListener("click", () => shiftRange(-1));
  document.getElementById("rp-next").addEventListener("click", () => shiftRange(1));

  const bolumBaslik = txt =>
    `<div style="font-size:11px;font-weight:700;color:#374151;margin:16px 0 8px;padding-left:10px;border-left:3px solid #3b82f6;text-transform:uppercase;letter-spacing:0.5px">${txt}</div>`;

  const yukle = async () => {
    const from = document.getElementById("rp-from").value, to = document.getElementById("rp-to").value;
    const icerik = document.getElementById("rp-icerik");
    if (!icerik) return;
    icerik.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    try {
      const istekler = [
        api(`/api/saha/rapor/ozet?from=${from}&to=${to}${tipQS()}`),
        api(`/api/saha/rapor/bolge-marka?from=${from}&to=${to}`),
        api(`/api/saha/rapor/rakip?from=${from}&to=${to}`),
        api(`/api/saha/rapor/teklif?from=${from}&to=${to}`)
      ];
      if (S.role !== "rep") istekler.push(api(`/api/saha/rapor/rep-performans?from=${from}&to=${to}`));
      const [ozet, bolge, rakip, teklif, rep] = await Promise.all(istekler);
      const o = ozet.ozet;
      const bolgeler = {};
      for (const s of bolge.satirlar) (bolgeler[s.bolge] = bolgeler[s.bolge] || []).push(s);

      const to_ = teklif.ozet;
      const sonuclanan = Number(to_.kazanilan) + Number(to_.kaybedilen);
      const winRate    = sonuclanan ? Math.round(1000 * to_.kazanilan / sonuclanan) / 10 : null;
      const kazTutar   = Number(to_.kazanilan_tutar || 0);
      const kayTutar   = Number(to_.kaybedilen_tutar || 0);

      icerik.innerHTML = `
        <div style="padding:10px 12px">

          <div class="ozet-izgara">
            ${[["Ziyaret", o.toplam_ziyaret,"#3b82f6"],["Benzersiz Nokta",o.benzersiz_nokta,"#8b5cf6"],
               ["Planlanan",o.planlanan,"#6b7280"],["Yeni Nokta",o.yeni_nokta,"#10b981"],
               ["Pasif/Riskli",o.pasif_riskli,"#ef4444"]]
              .map(([l,v,c]) => `<div class="ozet-kut"><b style="color:${c}">${v||0}</b><span>${l}</span></div>`).join("")}
          </div>

          ${bolumBaslik("Teklif Performansı")}
          <div class="ozet-izgara">
            <div class="ozet-kut"><b>${to_.toplam}</b><span>Teklif</span></div>
            <div class="ozet-kut"><b style="color:#10b981">${to_.kazanilan}</b><span>Kazanılan</span></div>
            <div class="ozet-kut"><b style="color:#ef4444">${to_.kaybedilen}</b><span>Kaybedilen</span></div>
            <div class="ozet-kut"><b>${to_.bekleyen}</b><span>Açık</span></div>
            <div class="ozet-kut"><b style="color:${winRate != null && winRate >= 50 ? "#10b981" : "#f59e0b"}">${winRate != null ? "%" + winRate : "—"}</b><span>Win Rate</span></div>
          </div>
          ${(kazTutar || kayTutar) ? `
          <div style="display:flex;gap:8px;margin-top:8px">
            ${kazTutar ? `<div style="flex:1;background:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;padding:8px;text-align:center"><div style="font-size:11px;color:#16a34a;font-weight:600">Kazanılan Ciro</div><div style="font-size:14px;font-weight:700;color:#15803d">${kazTutar.toLocaleString("tr-TR")}₺</div></div>` : ""}
            ${kayTutar ? `<div style="flex:1;background:#fef2f2;border:1px solid #fecaca;border-radius:8px;padding:8px;text-align:center"><div style="font-size:11px;color:#ef4444;font-weight:600">Kaybedilen</div><div style="font-size:14px;font-weight:700;color:#dc2626">${kayTutar.toLocaleString("tr-TR")}₺</div></div>` : ""}
          </div>` : ""}
          ${teklif.marka_bazli.length ? `
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden;margin-top:10px">
            <table class="tablo" style="margin:0"><tr><th>Marka</th><th>Teklif</th><th>Kazanç</th><th>Kayıp</th><th>Win %</th></tr>
            ${teklif.marka_bazli.map(r => `<tr><td>${esc(r.marka)}</td><td>${r.teklif}</td><td>${r.kazanilan}</td><td>${r.kaybedilen}</td><td>${r.win_rate != null ? "%" + r.win_rate : "—"}</td></tr>`).join("")}</table>
          </div>` : ""}
          ${teklif.rakip_kayiplari.length ? `
          ${bolumBaslik("Kime Kaybediyoruz?")}
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden">
            <table class="tablo" style="margin:0"><tr><th>Rakip</th><th>Model</th><th>Kayıp</th><th>Tutar</th><th>Ort. Fiyat</th></tr>
            ${teklif.rakip_kayiplari.map(r => `<tr><td>${esc(r.rakip_marka)}</td><td>${esc(r.rakip_model)||"—"}</td><td>${r.kayip}</td><td>${Number(r.kayip_tutar).toLocaleString("tr-TR")}₺</td><td>${r.ort_rakip_fiyat ? Number(r.ort_rakip_fiyat).toLocaleString("tr-TR") + "₺" : "—"}</td></tr>`).join("")}</table>
          </div>` : ""}
          ${teklif.kayip_nedenleri.length ? `
          ${bolumBaslik("Kayıp Nedenleri")}
          <div style="display:flex;gap:6px;flex-wrap:wrap">
            ${teklif.kayip_nedenleri.map(n => `<div style="background:#fef3c7;border:1px solid #fde68a;border-radius:8px;padding:6px 10px;font-size:12px"><b>${KAYIP_NEDEN[n.neden]||n.neden}</b>: ${n.adet}</div>`).join("")}
          </div>` : ""}

          ${rep && rep.repler.length ? (() => {
            const maxZ = Math.max(...rep.repler.map(r => Number(r.ziyaret)), 1);
            return `
          ${bolumBaslik("Temsilci Performansı")}
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden">
            <table class="tablo" style="margin:0">
              <tr><th style="padding-left:12px">Temsilci</th><th>Ziyaret</th><th>Müşteri</th></tr>
              ${rep.repler.map(r => {
                const pct = Math.round(100 * Number(r.ziyaret) / maxZ);
                return `<tr>
                  <td style="padding-left:12px;font-weight:500">${esc(r.rep)}</td>
                  <td>
                    <div style="display:flex;align-items:center;gap:6px">
                      <div style="width:56px;background:#f3f4f6;border-radius:4px;height:6px;flex-shrink:0">
                        <div style="width:${pct}%;background:#3b82f6;border-radius:4px;height:6px;min-width:${pct>0?2:0}px"></div>
                      </div>
                      <span style="font-size:13px;font-weight:600;color:#1e40af">${r.ziyaret}</span>
                    </div>
                  </td>
                  <td style="color:#374151">${r.benzersiz_musteri}</td>
                </tr>`;
              }).join("")}
            </table>
          </div>`;
          })() : ""}

          ${rakip.rakipler.length ? `
          ${bolumBaslik("Rakip Görülme Analizi")}
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden">
            <table class="tablo" style="margin:0"><tr><th style="padding-left:12px">Rakip</th><th>Görülme</th><th>Oran</th></tr>
            ${rakip.rakipler.map(r => `<tr><td style="padding-left:12px">${esc(r.rakip)}</td><td>${r.gorulme}</td><td>%${r.oran}${Number(r.oran)>=20?" 🔴":Number(r.oran)>=10?" 🟡":""}</td></tr>`).join("")}
            </table>
          </div>` : ""}

          ${Object.keys(bolgeler).length ? `
          ${bolumBaslik("Bölge × Marka")}
          <div style="display:flex;flex-direction:column;gap:8px">
            ${Object.entries(bolgeler).map(([b, satirlar]) => `
            <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:10px 12px">
              <div style="font-size:12px;font-weight:700;color:#374151;margin-bottom:6px">${esc(b)}</div>
              <div style="display:flex;gap:5px;flex-wrap:wrap">
                ${satirlar.slice(0,10).map(s => `<span style="background:#f3f4f6;border-radius:6px;padding:2px 8px;font-size:12px">${esc(s.marka)}: <b>${s.gorulme}</b></span>`).join("")}
              </div>
            </div>`).join("")}
          </div>` : ""}

        </div>`;
    } catch (e) {
      const ic = document.getElementById("rp-icerik");
      if (ic) ic.innerHTML = hata(e);
    }
  };
  document.getElementById("rp-from").addEventListener("change", yukle);
  document.getElementById("rp-to").addEventListener("change", yukle);
  await yukle();

  // ── Saha Sesi panel logic (manager/admin only) ──
  if (!["manager","admin"].includes(S.role)) return;

  let ssKapsam = "";   // "" = none selected yet (map click sets "sehir")
  let ssSehir  = null; // city selected from map
  let ssDays   = 30;
  let _trGeo   = null; // cached province GeoJSON

  // Multi-layer map state
  let ssLayers    = new Set(["ziyaret"]);  // active layers (can be multiple)
  let ssMapColor  = "ziyaret";            // which layer drives map colors (most recently activated)
  let ssSatisMetrik  = "tumu";            // "tumu" | "tuketici" | "ticari"
  let ssTeklifMetrik = "toplam";          // "toplam" | "kazanma" | "kaybetme"
  let ssEbat      = "";
  let _ebatTimer  = null;
  let _haritaData = new Map();            // il → merged row {ziyaret, ciro, teklif_toplam, …}
  let _subInitialized = false;           // prevent renderLayerSub destroying ebat input on reload

  // ── Turkey Bubble Map ─────────────────────────────────────────────────────
  // Province name normalization (GeoJSON names → DB names)
  const IL_NORM = {
    "Mersin": "İçel (Mersin)", "İçel": "İçel (Mersin)",
    "Afyon": "Afyonkarahisar", "K.Maraş": "Kahramanmaraş",
    "Kahraman Maraş": "Kahramanmaraş", "Urfa": "Şanlıurfa"
  };
  const normIl = n => IL_NORM[n] || n;

  // ── Color engine ─────────────────────────────────────────────────────────────
  function bucketIdx(val, q) {
    // q = [q25, q50, q75, q90] — returns 0..3
    if (val >= q[3]) return 3;
    if (val >= q[2]) return 2;
    if (val >= q[1]) return 1;
    return 0;
  }
  function computeQ(rows, key) {
    const vals = rows.map(r => +(r[key]||0)).filter(v => v > 0).sort((a,b) => a-b);
    if (!vals.length) return [1,1,1,1];
    const p = f => vals[Math.min(Math.floor(f * vals.length), vals.length-1)];
    return [p(0.25), p(0.5), p(0.75), p(0.9)];
  }
  const NO_DATA_COLOR = "#c8d9eb"; // visible against #f0f4f8 background (all 81 provinces show)

  // Pure single-layer color — returns NO_DATA_COLOR if this layer has no data for the province
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

  // ilColor: try the active color driver, fall back to Ziyaret so the map never goes blank
  function ilColor(s, mapColorLayer, satisM, teklifM, qs) {
    const primary = ilColorSingle(s, mapColorLayer, satisM, teklifM, qs);
    if (primary !== NO_DATA_COLOR) return primary;
    // Province has no data for the active driver → show Ziyaret color if available
    if (mapColorLayer !== "ziyaret") {
      return ilColorSingle(s, "ziyaret", satisM, teklifM, qs);
    }
    return NO_DATA_COLOR;
  }

  function refreshHaritaColors() {
    const rows = [..._haritaData.values()];
    const qs = {
      teklif_toplam: computeQ(rows, "teklif_toplam"),
      ciro:          computeQ(rows, "ciro"),
      adet:          computeQ(rows, "adet"),
      ciro_tuketici: computeQ(rows, "ciro_tuketici"),
      ciro_ticari:   computeQ(rows, "ciro_ticari"),
    };
    main().querySelectorAll(".harita-sehir").forEach(path => {
      const il = path.dataset.il;
      const s = _haritaData.get(il);
      const fill = ilColor(s, ssMapColor, ssSatisMetrik, ssTeklifMetrik, qs);
      path.setAttribute("fill", fill);
      if (!path.dataset.sel) path.style.filter = ""; // clear stale hover brightness
    });
  }

  function renderLayerSub() {
    const el = document.getElementById("ss-layer-sub"); if (!el) return;
    const hadEbatFocus = document.activeElement?.id === "ss-ebat-input";
    // Always render all sub-controls — layer buttons only control coloring + tooltip visibility
    const html = `
      <div style="margin-bottom:5px">
        <span style="font-size:10px;color:#6b7280;font-weight:600">Teklif görünüm: </span>
        ${[["toplam","Toplam"],["kazanma","Kazanma %"],["kaybetme","Kayıp %"]].map(([v,l]) =>
          `<button class="ss-tm-btn" data-t="${v}" style="margin:0 2px;padding:3px 9px;border:1px solid ${ssTeklifMetrik===v?"#3b82f6":"#e5e7eb"};background:${ssTeklifMetrik===v?"#dbeafe":"#fff"};color:${ssTeklifMetrik===v?"#1d4ed8":"#374151"};border-radius:12px;font-size:11px;cursor:pointer">${l}</button>`
        ).join("")}
      </div>
      <div style="margin-bottom:5px">
        <span style="font-size:10px;color:#6b7280;font-weight:600">Satış metrik: </span>
        ${[["tumu","Tümü"],["tuketici","Tüketici"],["ticari","Ticari"]].map(([v,l]) =>
          `<button class="ss-sm-btn" data-s="${v}" style="margin:0 2px;padding:3px 9px;border:1px solid ${ssSatisMetrik===v?"#7c3aed":"#e5e7eb"};background:${ssSatisMetrik===v?"#ede9fe":"#fff"};color:${ssSatisMetrik===v?"#6d28d9":"#374151"};border-radius:12px;font-size:11px;cursor:pointer">${l}</button>`
        ).join("")}
      </div>
      <div style="display:flex;align-items:center;gap:6px;margin-bottom:4px">
        <span style="font-size:10px;color:#6b7280">🔍 Ebat:</span>
        <input id="ss-ebat-input" type="text" placeholder="205/55R16" value="${esc(ssEbat)}"
          style="flex:1;padding:4px 8px;border:1px solid #e5e7eb;border-radius:8px;font-size:12px;outline:none;background:#fff;color:#1f2937"/>
      </div>`;
    el.innerHTML = html;
    // Wire metric buttons — clicking a metric activates its layer + makes it the color driver
    main().querySelectorAll(".ss-tm-btn").forEach(b => {
      b.addEventListener("click", () => {
        ssTeklifMetrik = b.dataset.t;
        ssLayers.add("teklif");
        ssMapColor = "teklif";
        renderLayerSub(); refreshHaritaColors(); renderLayerButtons();
      });
    });
    main().querySelectorAll(".ss-sm-btn").forEach(b => {
      b.addEventListener("click", () => {
        ssSatisMetrik = b.dataset.s;
        ssLayers.add("satis");
        ssMapColor = "satis";
        renderLayerSub(); refreshHaritaColors(); renderLayerButtons();
      });
    });
    // Wire ebat input
    const ebatInput = document.getElementById("ss-ebat-input");
    if (ebatInput) {
      ebatInput.addEventListener("input", () => {
        ssEbat = ebatInput.value.trim();
        clearTimeout(_ebatTimer);
        _ebatTimer = setTimeout(() => loadHarita(), 500);
      });
      // Restore focus if ebat input was active before sub-panel rebuild
      if (hadEbatFocus) {
        ebatInput.focus();
        ebatInput.setSelectionRange(ssEbat.length, ssEbat.length);
      }
    }
  }

  function renderLayerButtons() {
    main().querySelectorAll(".ss-layer-btn").forEach(b => {
      const active    = ssLayers.has(b.dataset.l);
      const isPrimary = active && ssMapColor === b.dataset.l;
      // solid purple = color driver | outlined purple = active tooltip-only | gray = inactive
      b.style.border      = active     ? "1.5px solid #8b5cf6" : "1.5px solid #e5e7eb";
      b.style.background  = isPrimary  ? "#8b5cf6" : "#fff";
      b.style.color       = isPrimary  ? "#fff" : (active ? "#7c3aed" : "#9ca3af");
      b.style.fontWeight  = active     ? "700" : "400";
    });
  }

  async function renderTurkeyMap(container, sehirler) {
    // Store in Map for fast lookup
    _haritaData = new Map(sehirler.map(s => [normIl(s.il), s]));
    const rows = sehirler;
    const qs = {
      teklif_toplam: computeQ(rows, "teklif_toplam"),
      ciro:          computeQ(rows, "ciro"),
      adet:          computeQ(rows, "adet"),
      ciro_tuketici: computeQ(rows, "ciro_tuketici"),
      ciro_ticari:   computeQ(rows, "ciro_ticari"),
    };

    // Fetch real Turkey provinces GeoJSON (cached)
    if (!_trGeo) {
      container.innerHTML = `<div style="padding:16px;text-align:center;font-size:12px;color:#94a3b8">İl sınırları yükleniyor…</div>`;
      try {
        const r = await fetch("https://raw.githubusercontent.com/cihadturhan/tr-geojson/master/geo/tr-cities-utf8.json");
        if (!r.ok) throw new Error("fetch");
        _trGeo = await r.json();
      } catch {
        // Fallback: show bubble map on fetch failure
        container.innerHTML = `<div style="padding:12px;text-align:center;font-size:12px;color:#94a3b8">İl haritası yüklenemedi</div>`;
        return;
      }
    }

    // Simple equirectangular projection fitted to Turkey
    const LON0=25.5, LON1=44.8, LAT0=35.8, LAT1=42.2, W=1000, H=410;
    const toX = lon => +((lon-LON0)/(LON1-LON0)*W).toFixed(1);
    const toY = lat => +((1-(lat-LAT0)/(LAT1-LAT0))*H).toFixed(1);
    const ring2path = coords => coords.map((p,i) => `${i?"L":"M"}${toX(p[0])},${toY(p[1])}`).join("") + "Z";
    const geom2path = g => g.type === "Polygon"
      ? g.coordinates.map(ring2path).join(" ")
      : g.type === "MultiPolygon"
        ? g.coordinates.flatMap(poly => poly.map(ring2path)).join(" ")
        : "";

    const paths = _trGeo.features.map(f => {
      const geoName = f.properties?.name || f.properties?.NAME_1 || f.properties?.il || "";
      const il   = normIl(geoName);
      const s    = _haritaData.get(il); // undefined for cities with no data — ilColor handles via !s guard
      const sd   = s || {};
      const z    = +sd.ziyaret||0, mst = +sd.musteri||0, bad = +sd.sorunlu||0;
      const hasAny = z > 0 || +(sd.teklif_toplam||0) > 0 || +(sd.ciro||0) > 0;
      const fill = ilColor(s, ssMapColor, ssSatisMetrik, ssTeklifMetrik, qs);
      const d    = geom2path(f.geometry);
      if (!d) return "";
      return `<path d="${d}" fill="${fill}" stroke="white" stroke-width="0.5" stroke-linejoin="round"
        class="harita-sehir" data-il="${esc(il)}"
        style="cursor:${hasAny?"pointer":"default"}"/>`;
    }).join("");

    container.innerHTML = `
      <div style="position:relative;background:#f0f4f8;border-radius:8px;overflow:hidden">
        <svg viewBox="0 0 1000 410" xmlns="http://www.w3.org/2000/svg" style="width:100%;height:auto;display:block">
          ${paths}
        </svg>
        <div id="harita-tip" style="display:none;position:absolute;background:rgba(15,23,42,.93);color:#fff;font-size:11px;padding:6px 10px;border-radius:8px;pointer-events:none;z-index:10;line-height:1.6;max-width:200px;box-shadow:0 2px 8px rgba(0,0,0,.3)"></div>
      </div>`;

    container.querySelectorAll(".harita-sehir").forEach(path => {
      const il = path.dataset.il;
      const _s0 = _haritaData.get(il) || {};
      const hasAny = +(_s0.ziyaret||0) > 0 || +(_s0.teklif_toplam||0) > 0 || +(_s0.ciro||0) > 0;
      path.addEventListener("mouseenter", () => {
        const s = _haritaData.get(il) || {};
        const z = +(s.ziyaret||0);
        const hasAny = z > 0 || +(s.teklif_toplam||0) > 0 || +(s.ciro||0) > 0;
        if (hasAny && !path.dataset.sel) path.style.filter = "brightness(0.82)";
        const tip = document.getElementById("harita-tip"); if (!tip) return;
        let lines = [`<b>${esc(il)}</b>`];
        if (ssLayers.has("ziyaret")) {
          if (z > 0) {
            lines.push(`📍 ${z} ziyaret · ${s.musteri||0} müşteri${+(s.sorunlu||0)>0?" · ⚠️"+s.sorunlu+" sorunlu":""}`);
          } else { lines.push("📍 Ziyaret yok"); }
        }
        if (ssLayers.has("teklif")) {
          const tot = +(s.teklif_toplam||0);
          if (tot > 0) {
            const kaz = +(s.kazanildi||0), kay = +(s.kaybedildi||0);
            const pct = Math.round(kaz/tot*100);
            lines.push(`💼 ${tot} teklif · ${kaz} kazanıldı (${pct}%) · ${kay} kaybedildi`);
          } else { lines.push("💼 Teklif yok"); }
        }
        if (ssLayers.has("satis")) {
          const fmt = v => v>=1000000 ? (v/1000000).toFixed(1)+"M₺" : v>=1000 ? (v/1000).toFixed(0)+"K₺" : v.toFixed(0)+"₺";
          if (ssSatisMetrik === "tumu") {
            const cV = +(s.ciro||0), aV = +(s.adet||0);
            if (cV > 0 || aV > 0) lines.push(`💰 Toplam: ${fmt(cV)} · ${Math.round(aV)} adet`);
            else lines.push("💰 Satış yok");
          } else {
            const isT = ssSatisMetrik === "tuketici";
            const ciroKey = isT ? "ciro_tuketici" : "ciro_ticari";
            const adetKey = isT ? "adet_tuketici" : "adet_ticari";
            const label = isT ? "Tüketici" : "Ticari";
            const ciroVal = +(s[ciroKey]||0), adetVal = +(s[adetKey]||0);
            if (ciroVal > 0 || adetVal > 0) lines.push(`💰 ${label}: ${fmt(ciroVal)} · ${Math.round(adetVal)} adet`);
            else lines.push("💰 Satış yok");
          }
        }
        tip.innerHTML = lines.join("<br>");
        tip.style.display = "block";
      });
      path.addEventListener("mousemove", ev => {
        const tip = document.getElementById("harita-tip"); if (!tip) return;
        const r = container.getBoundingClientRect();
        let lx = ev.clientX - r.left + 14, ly = ev.clientY - r.top - 44;
        if (lx + 210 > r.width) lx -= 220;
        if (ly < 0) ly = ev.clientY - r.top + 10;
        tip.style.left = lx + "px"; tip.style.top = ly + "px";
      });
      path.addEventListener("mouseleave", () => {
        if (!path.dataset.sel) path.style.filter = "";
        const t = document.getElementById("harita-tip"); if (t) t.style.display = "none";
      });
      if (hasAny) {
        path.addEventListener("click", () => {
          container.querySelectorAll(".harita-sehir").forEach(p => {
            p.setAttribute("stroke","white"); p.setAttribute("stroke-width","0.5");
            p.style.filter = ""; delete p.dataset.sel;
          });
          path.setAttribute("stroke","#1e293b"); path.setAttribute("stroke-width","1.8");
          path.style.filter = "brightness(0.78)"; path.dataset.sel = "1";

          ssKapsam = "sehir"; ssSehir = il;
          main().querySelectorAll(".ss-kapsam-btn").forEach(b => { b.style.background="#fff"; b.style.color="#374151"; b.style.borderColor="#e5e7eb"; });
          document.getElementById("ss-filtre").innerHTML = "";
          const info = document.getElementById("ss-sehir-info");
          if (info) {
            const s = _haritaData.get(il) || {};
            const parts = [`📍 <b>${esc(il)}</b>`];
            if (ssLayers.has("ziyaret") && +(s.ziyaret||0) > 0)
              parts.push(`${s.ziyaret} ziyaret · ${s.musteri||0} müşteri${+(s.sorunlu||0)>0?" · ⚠️"+s.sorunlu:""}`);
            if (ssLayers.has("teklif") && +(s.teklif_toplam||0) > 0)
              parts.push(`💼 ${s.teklif_toplam} teklif · ${s.kazanildi||0} kazanıldı`);
            if (ssLayers.has("satis")) {
              const fmt = v => v>=1000000?(v/1000000).toFixed(1)+"M₺":v>=1000?(v/1000).toFixed(0)+"K₺":v.toFixed(0)+"₺";
              if (ssSatisMetrik === "tumu") {
                const mC = +(s.ciro||0), mA = +(s.adet||0);
                if (mC > 0 || mA > 0) parts.push(`💰 Toplam: ${fmt(mC)} · ${Math.round(mA)} adet`);
              } else {
                const isT2 = ssSatisMetrik === "tuketici";
                const mCiro = +(s[isT2 ? "ciro_tuketici" : "ciro_ticari"]||0);
                const mAdet = +(s[isT2 ? "adet_tuketici" : "adet_ticari"]||0);
                const mLbl = isT2 ? "Tüketici" : "Ticari";
                if (mCiro > 0 || mAdet > 0) parts.push(`💰 ${mLbl}: ${fmt(mCiro)} · ${Math.round(mAdet)} adet`);
              }
            }
            info.innerHTML = parts.join(" · ");
            info.style.display = "block";
          }
        });
      }
    });
  }

  // Load harita for current period + ebat filter
  async function loadHarita() {
    const el = document.getElementById("ss-harita");
    if (!el) return;
    el.innerHTML = `<div style="padding:24px;text-align:center;font-size:12px;color:#94a3b8">Harita yükleniyor…</div>`;
    try {
      const p = new URLSearchParams();
      if (ssDays > 0) {
        const t = new Date(), f = new Date();
        f.setDate(f.getDate() - ssDays + 1);
        p.set("from", f.toISOString().slice(0, 10));
        p.set("to",   t.toISOString().slice(0, 10));
      }
      if (ssEbat) p.set("ebat", ssEbat);
      const { sehirler } = await api("/api/saha/harita?" + p.toString());
      await renderTurkeyMap(el, sehirler || []);
      renderLayerSub();
      renderLayerButtons();
    } catch(err) {
      console.error("[loadHarita]", err);
      el.innerHTML = `<div style="padding:12px;text-align:center;font-size:12px;color:#ef4444">Harita yüklenemedi: ${esc(err?.message||"")}</div>`;
    }
  }
  loadHarita();

  // ── Layer toggle (multi-select) ────────────────────────────────────────────
  renderLayerButtons(); // sync initial button styles with ssLayers/ssMapColor state
  main().querySelectorAll(".ss-layer-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const l = btn.dataset.l;
      if (!ssLayers.has(l)) {
        // 1st tap on inactive → add to active layers (tooltip only, color driver unchanged)
        ssLayers.add(l);
      } else if (ssMapColor !== l) {
        // 2nd tap (already active, not driving) → make it the color driver
        ssMapColor = l;
      } else {
        // tap on current color driver → deactivate (keep at least one)
        if (ssLayers.size === 1) return;
        ssLayers.delete(l);
        ssMapColor = [...ssLayers][ssLayers.size - 1];
      }
      renderLayerButtons();
      renderLayerSub();
      refreshHaritaColors();
    });
  });

  // ── Kapsam (text) toggle ───────────────────────────────────────────────────
  main().querySelectorAll(".ss-kapsam-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      ssKapsam = btn.dataset.k; ssSehir = null;
      // Deselect map
      main().querySelectorAll(".harita-sehir").forEach(c => { c.setAttribute("stroke","#fff"); c.setAttribute("stroke-width","0.8"); });
      const info = document.getElementById("ss-sehir-info"); if (info) info.style.display = "none";
      // Style buttons
      main().querySelectorAll(".ss-kapsam-btn").forEach(b => {
        const on = b.dataset.k === ssKapsam;
        b.style.background   = on ? "#8b5cf6" : "#fff";
        b.style.color        = on ? "#fff"     : "#374151";
        b.style.borderColor  = on ? "#8b5cf6"  : "#e5e7eb";
      });
      renderSsFiltre();
    });
  });

  // ── Dönem toggle ───────────────────────────────────────────────────────────
  main().querySelectorAll(".ss-donem-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      ssDays = Number(btn.dataset.d);
      main().querySelectorAll(".ss-donem-btn").forEach(b => {
        const on = Number(b.dataset.d) === ssDays;
        b.style.background  = on ? "#f5f3ff" : "#fff";
        b.style.color       = on ? "#7c3aed" : "#374151";
        b.style.borderColor = on ? "#8b5cf6" : "#e5e7eb";
        b.style.fontWeight  = on ? "700"     : "400";
      });
      ssSehir = null; ssKapsam = "";
      main().querySelectorAll(".ss-kapsam-btn").forEach(b => { b.style.background="#fff"; b.style.color="#374151"; b.style.borderColor="#e5e7eb"; });
      const info2 = document.getElementById("ss-sehir-info"); if (info2) info2.style.display = "none";
      loadHarita();
    });
  });

  // ── Dynamic filter ─────────────────────────────────────────────────────────
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
        const q = document.getElementById("ss-musteri-ara").value.trim().toLowerCase();
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

  // ── Result card renderer ───────────────────────────────────────────────────
  function renderSsJson(sonuc, data) {
    const { json, analiz, not_sayisi, prior_sayisi, aciklama, karsilastirma } = data;
    if (!json) {
      sonuc.innerHTML = `
        <div style="background:#faf5ff;border:1px solid #e9d5ff;border-radius:10px;padding:14px">
          <div style="font-size:11px;color:#7c3aed;font-weight:600;margin-bottom:8px">📊 ${not_sayisi} not · ${esc(aciklama)}</div>
          <div style="white-space:pre-wrap;font-size:13px;line-height:1.6">${esc(analiz||"").replace(/\*\*(.*?)\*\*/g,"<b>$1</b>")}</div>
        </div>`;
      return;
    }

    const trendBadge = t => {
      if (!t || t === "stabil") return "";
      const map = { yeni: ["🆕","#8b5cf6"], artiyor: ["↑","#ef4444"], azaliyor: ["↓","#10b981"] };
      const [ic, clr] = map[t] || ["","#6b7280"];
      return `<span style="font-size:9px;font-weight:700;color:${clr};margin-left:5px">${ic}</span>`;
    };
    const siklikRenk = s => s === "yüksek" ? "#ef4444" : s === "orta" ? "#f59e0b" : "#6b7280";

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
          ${json.kör_noktalar.map(k => `
          <div style="margin-bottom:6px">
            <div style="font-size:12px;font-weight:600;color:#78350f">${esc(k.konu)}</div>
            <div style="font-size:12px;color:#92400e;margin-top:1px">${esc(k.detay)}</div>
          </div>`).join("")}
        </div>` : ""}

        ${json.riskli_musteriler?.length ? `
        <div style="background:#fef2f2;border:1px solid #fecaca;border-radius:10px;padding:12px;margin-bottom:12px">
          <div style="font-size:11px;font-weight:700;color:#ef4444;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.4px">⚠ Riskli Müşteriler</div>
          ${json.riskli_musteriler.map(r => `
          <div style="margin-bottom:6px"><span style="font-size:12px;font-weight:700;color:#7f1d1d">${esc(r.musteri)}</span><span style="font-size:12px;color:#b91c1c"> — ${esc(r.neden)}</span></div>`).join("")}
        </div>` : ""}

        ${json.firsatlar?.length ? `
        <div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:10px;padding:12px;margin-bottom:12px">
          <div style="font-size:11px;font-weight:700;color:#16a34a;margin-bottom:8px;text-transform:uppercase;letter-spacing:0.4px">✨ Fırsatlar</div>
          ${json.firsatlar.map(f => `
          <div style="margin-bottom:6px">
            <div style="font-size:12px;font-weight:700;color:#14532d">${esc(f.firsat)}</div>
            <div style="font-size:12px;color:#15803d;margin-top:1px">${esc(f.detay)}</div>
          </div>`).join("")}
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
        `${not_sayisi} not analiz edildi${karsilastirma ? ` (önceki dönem: ${prior_sayisi} not)` : ""}`,
        json.ozet_cumlesi ? `\n"${json.ozet_cumlesi}"` : "",
        nabizText        ? `\n${nabizText}` : "",
        json.kritik_konular?.length  ? `\nKRİTİK KONULAR:\n${json.kritik_konular.map(k=>`• ${k.konu} (${k.siklik}${k.trend&&k.trend!=="stabil"?", "+k.trend:""}${k.kaynak?", "+k.kaynak:""}): ${k.detay}`).join("\n")}` : "",
        json.kör_noktalar?.length    ? `\nKÖR NOKTALAR:\n${json.kör_noktalar.map(k=>`• ${k.konu}: ${k.detay}`).join("\n")}` : "",
        json.riskli_musteriler?.length ? `\nRİSKLİ MÜŞTERİLER:\n${json.riskli_musteriler.map(r=>`• ${r.musteri}: ${r.neden}`).join("\n")}` : "",
        json.firsatlar?.length       ? `\nFIRSATLAR:\n${json.firsatlar.map(f=>`• ${f.firsat}: ${f.detay}`).join("\n")}` : "",
        json.temsilci_gozlem         ? `\nTEMSİLCİ GÖZLEMİ:\n${json.temsilci_gozlem}` : "",
        json.aksiyonlar?.length      ? `\nÖNERİLEN AKSİYONLAR:\n${json.aksiyonlar.map((a,i)=>`${i+1}. ${a}`).join("\n")}` : ""
      ].filter(Boolean).join("\n");
      navigator.clipboard?.writeText(text).then(() => uyari("✓ Analiz panoya kopyalandı", true)).catch(()=>{});
    });
  }

  // ── Analiz Et ──────────────────────────────────────────────────────────────
  document.getElementById("ss-analiz-btn")?.addEventListener("click", async () => {
    const btn   = document.getElementById("ss-analiz-btn");
    const sonuc = document.getElementById("ss-sonuc");
    if (!btn || !sonuc) return;

    if (!ssKapsam) { uyari("Haritadan bir şehir seçin veya kapsam butonlarından birini tıklayın."); return; }

    const params = new URLSearchParams({ kapsam: ssKapsam });
    if (ssKapsam === "sehir") {
      if (!ssSehir) { uyari("Haritadan bir şehir seçin."); return; }
      params.set("sehir", ssSehir);
    }
    if (ssKapsam === "durum") params.set("durum", "PASIF,RISKLI");
    if (ssKapsam === "temsilci") {
      const v = document.getElementById("ss-rep")?.value;
      if (!v) { uyari("Lütfen bir temsilci seçin."); return; }
      params.set("rep_id", v);
    }
    if (ssKapsam === "musteri") {
      const v = document.getElementById("ss-musteri-id")?.value;
      if (!v) { uyari("Lütfen bir müşteri seçin."); return; }
      params.set("musteri_id", v);
    }
    if (ssDays > 0) {
      const t = new Date(), f = new Date(); f.setDate(f.getDate() - ssDays + 1);
      params.set("from", f.toISOString().slice(0, 10));
      params.set("to",   t.toISOString().slice(0, 10));
    }

    btn.textContent = "⏳ Analiz ediliyor…"; btn.disabled = true;
    sonuc.style.display = "block";
    sonuc.innerHTML = `<div style="padding:12px;font-size:12px;color:#7c3aed">Notlar toplanıyor ve karşılaştırmalı analiz yapılıyor…</div>`;

    try {
      const result = await api(`/api/saha/ai/saha-sesi?${params}`);
      renderSsJson(sonuc, result);
      btn.textContent = "🤖 Saha Sesini Analiz Et";
    } catch(e) {
      sonuc.innerHTML = `<div style="color:#ef4444;padding:10px">Hata: ${esc(e.message)}</div>`;
      btn.textContent = "🤖 Saha Sesini Analiz Et";
    }
    btn.disabled = false;
  });
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
function uyari(mesaj, basari = false) {
  const el = document.createElement("div");
  el.className = "saha-toast" + (basari ? " ok" : "");
  el.textContent = mesaj;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3500);
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

function hata(e) { return `<div class="saha-bos">⚠ ${esc(e.message || String(e))}</div>`; }
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
  .saha-toast{position:fixed;bottom:92px;left:50%;transform:translateX(-50%);background:#0f172a;color:#fff;padding:11px 17px;border-radius:11px;font-size:13px;z-index:20000;max-width:88vw;box-shadow:0 6px 18px rgba(0,0,0,.25)}
  .saha-toast.ok{background:#10b981}
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
