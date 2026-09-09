// shells/bi.js — Derive Intelligence Virtual Management Office
// Export: initBiSurface(container, me, sub, callbacks)

export function initBiSurface(container, me, sub, callbacks) {
  const { apiFetch, streamChat, logout } = callbacks;
  const permissions  = sub?.permissions || me?.permissions || {};
  const _depts = permissions.departments || ["sales","pricing","warehouse","it","orders"];

  // ── Mobile height fix ─────────────────────────────────────────────────────
  // vmo-shell uses height:100vh which ignores the app topbar above it.
  // On mobile we explicitly size the container to fill the remaining viewport.
  function _fixMobileHeight() {
    if (window.innerWidth > 768) return;
    var appTopbar = document.querySelector('.topbar');
    // Mobile fix v11: hide topbar so VMO fills full screen
    if (appTopbar) {
      appTopbar.style.setProperty('display', 'none', 'important');
      appTopbar.style.setProperty('height', '0', 'important');
      appTopbar.style.setProperty('min-height', '0', 'important');
      appTopbar.style.setProperty('overflow', 'hidden', 'important');
      appTopbar.style.setProperty('padding', '0', 'important');
      appTopbar.style.setProperty('margin', '0', 'important');
    }
    var usedH = 0; // topbar hidden — panel gets full viewport
    var remaining = window.innerHeight - usedH;
    container.style.height = Math.max(remaining, 400) + 'px';
    container.style.overflow = 'hidden';
    var shell = container.querySelector('.vmo-shell');
    if (shell) { shell.style.height = '100%'; shell.style.minHeight = 'unset'; }
    // Restore vmo-office to flex:1 (not height:auto which breaks layout)
    var office = container.querySelector('.vmo-office');
    if (office) { office.style.flex = '1'; office.style.height = 'unset'; office.style.overflowY = 'auto'; }
  }
  // Delay call so container.innerHTML has been set before we query it
  setTimeout(_fixMobileHeight, 50);
  window.addEventListener('resize', _fixMobileHeight, { passive: true });
  // YETKI_MATRIS_V1: eskiden "rakip","brand-analysis","price-list" HERKESE zorla eklenirdi
  // -> departman yetkisi anlamsizdi. Artik permissions.departments NE DIYORSA O.
  const allowedDepts = _depts;

  const OFFICERS = [
    { id: "sales",     label: "Satış",          name: "Satış Direktörü",       emoji: "👩‍💼", color: "#2563eb", bg: "linear-gradient(160deg,#0f1f4a 0%,#0a0a1e 100%)" },
    { id: "pricing",   label: "Fiyatlandırma",  name: "Fiyat Analisti",        emoji: "📊",  color: "#7c3aed", bg: "linear-gradient(160deg,#1a0a3a 0%,#0a0a1e 100%)" },
    { id: "warehouse", label: "Depo",            name: "Lojistik Direktörü",    emoji: "📦",  color: "#059669", bg: "linear-gradient(160deg,#062a1a 0%,#0a0a1e 100%)" },
    { id: "it",        label: "Sistem",          name: "IT Direktörü",          emoji: "💻",  color: "#d97706", bg: "linear-gradient(160deg,#2a1a00 0%,#0a0a1e 100%)" },
    { id: "orders",    label: "Sipariş",         name: "Satın Alma Direktörü",  emoji: "🛒",  color: "#0891b2", bg: "linear-gradient(160deg,#012a3a 0%,#0a0a1e 100%)" }
    ,{ id: "brand-analysis", label: "Marka",  name: "Marka Fırsatları",      emoji: "🔍",  color: "#be185d", bg: "linear-gradient(160deg,#2a0516 0%,#0a0a1e 100%)" }
    ,{ id: "price-list",     label: "Fiyat", name: "Fiyat Listeleri",       emoji: "📋",  color: "#059669", bg: "linear-gradient(160deg,#012a1a 0%,#0a0a1e 100%)" }
    ,{ id: "rakip",   label: "Rakip Fiyatlar",  name: "Rakip Analisti",    emoji: "🏷", color: "#dc2626", bg: "linear-gradient(160deg,#3a0505 0%,#0a0a1e 100%)" }
  ].filter(d => allowedDepts.includes(d.id));

  let activeDept = 'bugun';  /* ANA_UI_V1 */




  // Order Management state
  let ordersSection = "winter";   // winter | summer | daily
  let ordersSegment = "all";      // all | binek | ticari | mevsimsel
  let ordersMode    = "priority"; // priority | budget
  let ordersBudget  = 500000;
  let ordersItems   = [];       // last fetch result — reused for sort/export
  let ordersSortKey = null;     // currently sorted column key (null = server order)
  let ordersSortDir = 1;        // 1 = ascending, -1 = descending

  // ── Shell skeleton ────────────────────────────────────────────────────────
  container.innerHTML = `
    <div class="vmo-shell">

      <!-- Header -->
      <header class="vmo-header">
        <div class="vmo-brand">
          <svg width="26" height="26" viewBox="0 0 32 32" fill="none">
            <rect width="32" height="32" rx="8" fill="#1a1a2e"/>
            <path d="M8 16h4l3-8 4 16 3-8h4" stroke="#e2b04a" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
          <div class="vmo-brand-text">Derive <strong>Intelligence</strong> <span class="vmo-brand-sub">Virtual Management Office</span></div>
        </div>
        <nav class="vmo-tabs">
          ${OFFICERS.map(o => `
            <button class="vmo-tab ${o.id===activeDept?"active":""}" data-dept="${o.id}" style="--c:${o.color}">
              <span>${o.emoji}</span> ${o.label}
            </button>`).join("")}
          <button class="vmo-tab active" data-dept="bugun" style="--c:#8A8A8F">Bugün</button>
          <button class="vmo-tab" data-dept="brain" style="--c:#e11d48">
            <span>🧠</span> CEO Assistant
          </button>
        </nav>
        <div class="vmo-header-right">
          <span class="vmo-tenant">${esc(me.tenantName || "")}</span>
          <div id="vmo-macro-ticker" class="vmo-macro-ticker" title="Piyasa verileri — 30 sn'de bir yenilenir">
            <span class="vmo-mt-item">TCMB <span id="vmt-tcmb">—</span></span>
            <span class="vmo-mt-sep">·</span>
            <span class="vmo-mt-item">USD <span id="vmt-usd">—</span></span>
            <span class="vmo-mt-sep">·</span>
            <span class="vmo-mt-item">EUR <span id="vmt-eur">—</span></span>
            <span class="vmo-mt-date" id="vmt-date"></span>
          </div>
          <button class="vmo-feedback-btn" onclick="window._openFeedback()" title="Not bırak / Geri bildirim gönder">📝 Not</button>
          <button class="vmo-logout" id="vmo-logout" title="Çıkış Yap">
            <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9"/></svg>
            <span class="vmo-logout-label">Çıkış</span>
          </button>
        </div>
      </header>

      <!-- Office rooms -->
      <div class="vmo-office">
        ${OFFICERS.map(o => `
          <div class="vmo-room ${o.id===activeDept?"":"vmo-room-hidden"}" id="vmo-room-${o.id}" data-dept="${o.id}" style="--c:${o.color};--bg:${o.bg}">

            <!-- Left: Officer presence + chat -->
            <aside class="vmo-officer-panel">
              <div class="vmo-officer-stage">
                <div class="vmo-avatar-wrap">
                  <div class="vmo-pulse-ring"></div>
                  <div class="vmo-pulse-ring vmo-pulse-ring-2"></div>
                  <div class="vmo-avatar-circle">${o.emoji}</div>
                </div>
                <div class="vmo-officer-info">
                  <div class="vmo-officer-name">${esc(o.name)}</div>
                  <div class="vmo-officer-dept">${esc(o.label)} Departmanı</div>
                  <div class="vmo-live-badge">
                    <span class="vmo-live-dot"></span> Çevrimiçi · Hazır
                  </div>
                </div>
              </div>

              <div class="vmo-chat-area">
                <div class="vmo-chat-messages" id="vmo-chat-${o.id}">
                  <div class="vmo-chat-welcome">
                    <div class="vmo-welcome-text">Merhaba! Ben <strong>${esc(o.name)}</strong>.<br>${esc(o.label)} hakkında ne sorarsınız?</div>
                    <div class="vmo-quick-btns">
                      ${quickPrompts(o.id).map(p => `<button class="vmo-qbtn" data-dept="${o.id}" data-prompt="${esc(p)}">${esc(p)}</button>`).join("")}
                    </div>
                  </div>
                </div>
                <form class="vmo-chat-form" id="vmo-form-${o.id}" autocomplete="off">
                  <input class="vmo-chat-input" type="text" placeholder="Sorunuzu yazın…" autocomplete="off">
                  <button type="submit" class="vmo-send-btn" title="Gönder">
                    <svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.2" viewBox="0 0 24 24"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
                  </button>
                </form>
              </div>
            </aside>

            <!-- Right: Data wall -->
            ${o.id === "orders" ? `
            <div class="vmo-data-wall vmo-orders-wall">

              <!-- Section tabs: Kış / Yaz / Günlük -->
              <div class="vmo-section-tabs">
                <button class="vmo-stab-section active" data-section="winter">❄️ Kış Ön Sipariş</button>
                <button class="vmo-stab-section" data-section="summer">☀️ Yaz Ön Sipariş</button>
                <button class="vmo-stab-section" data-section="daily">🔄 Günlük Öneriler</button>
                <button class="vmo-stab-section" data-section="size-opp">📐 Ebat Fırsatları</button>
                <button class="vmo-stab-section" data-section="season-price">💲 Yaz/Kış Fiyat</button>
              </div>

              <!-- Segment tabs: Tümü / Binek / Ticari / Mevsimsel -->
              <div class="vmo-segment-tabs">
                <button class="vmo-stab-seg active" data-seg="all">Tümü</button>
                <button class="vmo-stab-seg" data-seg="binek">Binek</button>
                <button class="vmo-stab-seg" data-seg="ticari">Ticari</button>
                <button class="vmo-stab-seg" data-seg="mevsimsel">Mevsimsel</button>
              </div>

              <!-- Size / product search -->
              <div class="vmo-size-search" id="vmo-size-search">
                <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" style="flex-shrink:0;opacity:0.4"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
                <input type="text" id="vmo-search-input" class="vmo-search-input" placeholder="Ebat, marka veya ürün ara… (örn: 205/55R16, Bridgestone)" autocomplete="off" spellcheck="false" oninput="(function(v){var tb=document.getElementById('vmo-orders-tbody')||document.querySelector('#vmo-orders-results tbody');if(!tb)return;var q=v.trim().toLowerCase();var cb=document.getElementById('vmo-search-clear');if(cb)cb.style.display=q?'inline':'none';[].forEach.call(tb.querySelectorAll('tr'),function(r){r.style.display=!q||r.textContent.toLowerCase().indexOf(q)>=0?'':'none';})})(this.value)">
                <button id="vmo-search-clear" class="vmo-search-clear" title="Temizle" style="display:none">✕</button>
              </div>

              <!-- Output mode tabs: Öncelikli / Bütçe -->
              <div class="vmo-mode-tabs">
                <button class="vmo-stab-mode active" data-mode="priority">📋 Öncelikli Liste</button>
                <button class="vmo-stab-mode" data-mode="budget">💰 Bütçe Planı</button>
                <div class="vmo-budget-input" id="vmo-budget-input" style="display:none">
                  <span>Bütçe:</span>
                  <input type="number" id="vmo-budget-val" value="500000" step="50000" min="0">
                  <span>₺</span>
                  <button class="vmo-budget-apply">Uygula</button>
                </div>
                <button id="vmo-export-btn" title="Tüm listeyi Excel olarak indir" style="display:none;align-items:center;gap:5px;padding:6px 12px;background:rgba(16,185,129,0.12);border:1px solid rgba(16,185,129,0.3);border-radius:6px;color:#34d399;font-size:12px;font-weight:600;cursor:pointer;white-space:nowrap">📥 Excel</button>
              </div>

              <!-- Results area -->
              <div class="vmo-orders-summary" id="vmo-orders-summary"></div>
              <div class="vmo-orders-results" id="vmo-orders-results">
                <div class="vmo-kpi-loading">Sipariş verileri yükleniyor…</div>
              </div>
            </div>
            ` : `
            <div class="vmo-data-wall">
              <div class="vmo-briefing-bar" id="vmo-briefing-${o.id}" style="display:none"></div>
              ${o.id === 'sales' ? '<div class="vmo-section-tabs" id="vmo-sales-stabs" style="margin-bottom:10px"><button class="vmo-stab-section active" data-stab="kpi" onclick="window._salesTabSwitch(this.dataset.stab)" style="font-size:12px">📊 KPI</button><button class="vmo-stab-section" data-stab="health" onclick="window._salesTabSwitch(this.dataset.stab)" style="font-size:12px">🚛 Ticari Müşteri Sağlığı</button></div>' : ''}
              <div class="vmo-kpi-grid" id="vmo-kpis-${o.id}">
                <div class="vmo-kpi-loading">Veriler yükleniyor…</div>
              </div>
              <div class="vmo-chart-panel" id="vmo-chart-${o.id}">
                <div class="vmo-chart-placeholder">Grafik hazırlanıyor…</div>
              </div>
              ${o.id === 'sales' ? '<div id="vmo-health-tab" style="display:none;padding:4px 0;width:100%"></div>' : ''}
            </div>
            `}

          </div>`).join("")}
      </div>
    </div>
    <style>${vmoStyles()}</style>
  `;

  // ── Events ────────────────────────────────────────────────────────────────



  // ── ANA_UI_V1 — 'Bugün' odasi ────────────────────────────────────────────
  {
    const _off2 = container.querySelector('.vmo-office');
    if (_off2 && !document.getElementById('vmo-room-bugun')) {
      const _br = document.createElement('div');
      _br.id = 'vmo-room-bugun';
      _br.dataset.dept = 'bugun';
      _br.className = 'vmo-room';
      document.documentElement.setAttribute('data-tema','koyu');  /* BI koyu — tum odalar donusene kadar */
      _br.style.cssText = 'background:var(--zemin-0);color:var(--tx-0);overflow-y:auto;padding:0';  /* ANA_UI_FIX: display satir ici OLMAZ — .vmo-room-hidden'i ezer */
      _br.innerHTML = '<div id="bugun-govde" style="max-width:1080px;margin:0 auto;padding:26px 28px 0"><div style="color:var(--tx-2);font-size:13px">Yükleniyor…</div></div>';
      _off2.appendChild(_br);
    }
  }

  const _tl = n => (n==null ? '—' : new Intl.NumberFormat('tr-TR').format(Math.round(n)));
  const _M  = n => (n==null ? '—' : (n/1e6).toLocaleString('tr-TR',{minimumFractionDigits:1,maximumFractionDigits:1}) + 'M');

  async function ciz_bugun() {
    const g = document.getElementById('bugun-govde');
    if (!g) return;
    let d;
    try {
      const r = await fetch('/api/bi/ana', { credentials: 'same-origin' });
      const _txt = await r.text();
      // ⚠ HATA MESAJINI ATMA. Onceki halim 'HTTP 500' deyip govdeyi cope atiyordu.
      try { d = JSON.parse(_txt); } catch (_) { throw new Error('HTTP ' + r.status + ' — ' + _txt.slice(0,200)); }
      if (!r.ok || d.error) throw new Error(d.error || ('HTTP ' + r.status));
      if (d.error) throw new Error(d.error);
    } catch (e) {
      // ⚠ HATA GIZLENMIYOR. Bos ekran, "bir seyler ters gitti"den beterdir.
      g.innerHTML = '<div class="kart kart-dikkat" style="margin-top:20px">'
        + '<div style="font-size:15px;margin-bottom:6px">Ana sayfa verisi gelmedi</div>'
        + '<div class="satir"><span>hata</span><span class="n d-sari">' + esc(String(e.message)) + '</span></div>'
        + '<div style="font-size:13px;color:var(--tx-2);margin-top:8px">Veri Sağlığı odasında ayrıntı var.</div></div>';
      return;
    }

    const s = d.sermaye || {}, k = d.karlilik || {}, bilgi = d.bilgi || {};
    let h = '';

    // ── SERMAYE OMURGASI ──────────────────────────────────────────────────
    h += '<div class="etiket" style="margin-bottom:12px">BAĞLI SERMAYE</div>';
    h += '<div style="display:grid;grid-template-columns:1.3fr 1fr 1fr 1fr;gap:10px;margin-bottom:8px">';
    h += '<div class="kart dn" data-sor="' + esc('507M bağlı sermayenin kırılımını ver ve nasıl azaltırız?') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Bağlı sermaye</div>'
       +   '<div class="n n-buyuk" style="margin:6px 0">' + _M(s.bagli) + '</div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">stok ' + _M(s.stok) + ' · alacak ' + _M(s.alacak) + '</div>'
       + '</div>';
    h += '<div class="kart dn" data-sor="' + esc('Yıllık sermaye yükü 203M. Faaliyet kârımla kıyasla — değer yaratıyor muyuz?') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Yıllık sermaye yükü</div>'
       +   '<div class="n n-buyuk d-kirmizi" style="margin:6px 0">' + _M(s.yillik_yuk) + '</div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">%40 / yıl</div>'
       + '</div>';
    h += '<div class="kart dn" data-sor="' + esc('Stok 131 günden 90 güne inerse ne kadar sermaye serbest kalır? Hangi ürünler?') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Stok devri</div>'
       +   '<div class="n n-buyuk d-sari" style="margin:6px 0">' + _tl(s.stok_gun) + '<span style="font-size:14px;color:var(--tx-2)"> gün</span></div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">serbest ' + _M(s.stok_serbest) + '</div>'
       + '</div>';
    // ⚠ DSO: ekranda 26,9 gorunuyordu. YALANDI.
    h += '<div class="kart dn" data-sor="' + esc('Gerçek DSO 116 gün. Neden tahsilat tablosu 26,9 gösteriyor? Gecikmiş alacağı müşteri bazında sırala.') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Tahsilat süresi</div>'
       +   '<div class="n n-buyuk d-kirmizi" style="margin:6px 0">' + _tl(s.dso_gun) + '<span style="font-size:14px;color:var(--tx-2)"> gün</span></div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">gecikmiş ' + _M(s.gecikmis) + ' · ' + _tl(s.gecikmis_musteri) + ' müşteri</div>'
       + '</div>';
    h += '</div>';
    h += '<div style="font-size:12px;color:var(--tx-3);margin-bottom:24px;line-height:1.6">'
       + 'Tahsilat süresi ödemeyenleri de içerir. Sistemin daha önce gösterdiği 26,9 gün yalnızca ödeyenleri ölçüyordu.</div>';

    // ── ⚠ KARLILIK: BOS DEGIL, DOLU BIR BOSLUK ────────────────────────────
    if (!k.hesaplanabilir) {
      h += '<div class="kart kart-dikkat" style="margin-bottom:24px">';
      h += '<div style="font-size:15px;margin-bottom:8px">Kârlılığını gösteremiyorum</div>';
      h += '<div style="font-size:13px;color:var(--tx-1);line-height:1.6;margin-bottom:12px">'
         + 'Bayilik markalarının cirosunun <span class="n d-sari">%' + (k.kor_pct||0) + '</span>’inde '
         + '(<span class="n">' + _M(k.kor_ciro) + '</span>) maliyet hesaplanamıyor. '
         + 'Marj uydurmuyorum — eksik olan şu:</div>';
      (k.eksik||[]).forEach(function(e){
        h += '<div class="satir"><span>' + esc(e.kategori) + ' — ' + esc(e.neEksik) + ' eksik</span>'
           + '<span class="n d-sari">' + _M(e.ciro) + '</span></div>';
      });
      h += '<div style="display:flex;gap:8px;margin-top:14px">'
         + '<button class="dg" onclick="document.querySelector(\'[data-dept=\\\'price-list\\\']\')?.click()">Dosyaları yükle</button>'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc('Eksik iskonto kademelerini KRB’den nasıl isteyelim? Brisa’dan hangi belgeyi almalıyız?') + '">Nasıl toplarım?</button>'
         + '</div>';
      h += '</div>';
    }

    // ── KARAR KUYRUGU ─────────────────────────────────────────────────────
    h += '<div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:11px">'
       + '<div class="etiket">KARAR GEREKİYOR</div>'
       + '<div style="font-size:12px;color:var(--tx-3)">' + (d.kararlar||[]).length + ' açık'
       + (d.sinyal_yasi != null ? ' · ' + d.sinyal_yasi + ' saat önce hesaplandı' : '') + '</div></div>';

    (d.kararlar||[]).forEach(function(c){
      const acil = Number(c.puan) >= 50;
      const pd = c.puan_detay || {};
      h += '<div class="kart ' + (acil ? 'kart-karar' : 'kart-dikkat') + '" style="margin-bottom:8px">';
      h += '<div style="display:flex;justify-content:space-between;gap:14px;align-items:flex-start">';
      h += '<div style="flex:1"><div style="font-size:15px;margin-bottom:4px">' + esc(c.baslik) + '</div>'
         + '<div style="font-size:12px;color:var(--tx-2)">' + esc(c.ozet || '') + '</div></div>';
      // ⚠ PUAN + BILESENLERI. Kullanici siralamaya ITIRAZ EDEBILMELI.
      h += '<div style="text-align:right;white-space:nowrap">'
         + '<div class="n ' + (acil?'d-kirmizi':'d-sari') + '" style="font-size:15px">' + c.puan + '</div>'
         + '<div style="font-size:11px;color:var(--tx-3);font-family:var(--mono)">para ' + (pd.para||'—') + ' · acil ' + (pd.aciliyet||'—') + '</div>'
         + '</div></div>';
      h += '<div style="display:flex;gap:7px;margin-top:11px">'
         + '<button class="dg sor" data-sor="' + esc(c.baslik + ' — aç: ne oldu, ne yapmalıyım, yapmazsam ne olur?') + '" style="min-height:36px;font-size:13px">Aç</button>'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc(c.baslik + ' — sustur. Tutar %25 artarsa veya son tarih 14 güne inerse geri gel.') + '" style="min-height:36px;font-size:13px">Sustur</button>'
         + '</div>';
      h += '</div>';
    });

    // ── BILGI (karar degil) ───────────────────────────────────────────────
    // ⚠ Planli odemeler karar kuyrugunun ICINDEYDI, ilk 6'nin 4'unu doldurup
    //   gercek kararlari asagi itiyorlardi. Artik BURADA, sessiz.
    if (Number(bilgi.adet) > 0) {
      h += '<div class="kart" style="margin:16px 0 24px;opacity:.75">'
         + '<div class="satir"><span>Brisa ödeme takvimi — ' + bilgi.adet + ' planlı ödeme</span>'
         + '<span class="n">' + _M(bilgi.toplam) + '</span></div>'
         + '<div style="font-size:12px;color:var(--tx-3);margin-top:4px">İlki ' + (bilgi.en_yakin ? new Date(bilgi.en_yakin).toLocaleDateString('tr-TR') : '—')
         + ' — karar gerektirmiyor, takvim.</div></div>';
    }

    // ── VARDIYA DEFTERI ───────────────────────────────────────────────────
    if ((d.vardiya||[]).length) {
      h += '<div class="etiket" style="margin-bottom:11px">SİSTEM NE BULDU</div>';
      h += '<div style="font-family:var(--mono);font-size:12px;color:var(--tx-2);line-height:2;margin-bottom:26px">';
      (d.vardiya||[]).forEach(function(v){
        const t = new Date(v.zaman);
        const c = v.durum === 'dikkat' ? 'var(--sari)' : 'var(--tx-2)';
        h += '<div><span style="color:var(--tx-3)">' + t.toLocaleDateString('tr-TR',{day:'2-digit',month:'2-digit'})
           + ' ' + t.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'})
           + '</span>  <span style="color:' + c + '">' + esc(v.metin) + '</span></div>';
      });
      h += '</div>';
    }

    // ── ASISTAN SERIDI ────────────────────────────────────────────────────
    h += '<div class="as" style="margin:0 -28px;padding-left:28px;padding-right:28px">'
       + '<div class="as-kutu"><span style="color:var(--tx-3);font-family:var(--mono)">›</span>'
       + '<input id="bugun-sor" placeholder="Neyi merak ediyorsun?">'
       + '</div></div>';

    g.innerHTML = h;

    // dokunma noktalari + butonlar -> asistana git
    g.querySelectorAll('.dn, .sor').forEach(function(el){
      el.addEventListener('click', function(){
        const q = el.dataset.sor;
        if (q) _bugun_sor(q);
      });
    });
    const inp = document.getElementById('bugun-sor');
    if (inp) inp.addEventListener('keydown', function(e){
      if (e.key === 'Enter' && inp.value.trim()) { _bugun_sor(inp.value.trim()); inp.value=''; }
    });
  }

  // Asistan odasina gecip soruyu sor
  function _bugun_sor(q) {
    const t = document.querySelector('[data-dept="brain"]');
    if (t) t.click();
    setTimeout(function(){
      const i = document.querySelector('#vmo-room-brain input, #vmo-brain-input, .vmo-chat-input');
      if (i) { i.value = q; i.focus();
        const f = i.closest('form'); if (f) f.dispatchEvent(new Event('submit', {cancelable:true, bubbles:true}));
      }
    }, 260);
  }

  // ⚠ ANA_UI_FIX — ACILIS SENKRONU
  // Eski 'home' odasi createElement ile kuruluyor ve gizle sinifi ALMIYOR.
  // OFFICERS.map ile uretilenler aliyor, sonradan eklenenler ALMIYOR.
  // Mevcut mekanizmayi (satir ~1072) acilista BIR KEZ calistir.
  setTimeout(function(){
    container.querySelectorAll('.vmo-room').forEach(function(r){
      r.classList.toggle('vmo-room-hidden', r.dataset.dept !== activeDept);
    });
    container.querySelectorAll('.vmo-tab').forEach(function(t){
      t.classList.toggle('active', t.dataset.dept === activeDept);
    });
  }, 0);

  ciz_bugun();

  // ── Brain Room (created outside OFFICERS map) ────────────────────────────
  {
    const _off = container.querySelector('.vmo-office');
    if (_off && !document.getElementById('vmo-room-home')) {
      const _hr = document.createElement('div');
      _hr.id = 'vmo-room-home';
      _hr.dataset.dept = 'home';
      _hr.className = 'vmo-room';
      _hr.style.cssText = 'background:#080818;overflow:hidden';
      _hr.innerHTML =
        '<div class="vmo-hub-wrap" id="vmo-hub-wrap">' +
          '<div class="vmo-hub-glow"></div>' +
          '<canvas id="vmo-hub-canvas"></canvas>' +
          '<div class="vmo-hub-center" id="vmo-hub-center">' +
            '<div class="vmo-hub-ring r1"></div>' +
            '<div class="vmo-hub-ring r2"></div>' +
            '<div class="vmo-hub-ring r3"></div>' +
            '<div class="vmo-hub-brain-circle">&#x1F9E0;</div>' +
            '<div class="vmo-hub-center-name">CEO Assistant</div>' +
            '<div class="vmo-hub-center-sub">Tüm sistemler aktif</div>' +
          '</div>' +
          '<div class="vmo-hub-nodes" id="vmo-hub-nodes"></div>' +
          '<div class="vmo-hub-cmd-bar">' +
            '<form id="vmo-hub-form">' +
              '<input id="vmo-hub-inp" type="text" placeholder="Komut ver veya bir ajana tıkla…" autocomplete="off">' +
              '<button type="submit"><svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.2" viewBox="0 0 24 24"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg></button>' +
            '</form>' +
          '</div>' +
        '</div>';
      _off.prepend(_hr);
    }
    if (_off && !document.getElementById('vmo-room-brain')) {
      const _br = document.createElement('div');
      _br.id = 'vmo-room-brain';
      _br.className = 'vmo-room vmo-room-hidden';
      _br.dataset.dept = 'brain';
      _br.style.cssText = '--c:#e11d48;background:linear-gradient(160deg,#1a0010 0%,#0a0a1e 100%)';
      _br.innerHTML = "<aside class=\"vmo-officer-panel\" style=\"display:flex;flex-direction:column;min-width:0;flex:3;width:auto\"><div class=\"vmo-officer-stage\"><div class=\"vmo-avatar-wrap\"><div class=\"vmo-pulse-ring\"></div><div class=\"vmo-pulse-ring vmo-pulse-ring-2\"></div><div class=\"vmo-avatar-circle\" style=\"font-size:26px\">🧠</div></div><div class=\"vmo-officer-info\"><div class=\"vmo-officer-name\">CEO Assistant</div><div class=\"vmo-officer-dept\">CEO Assistant · All Departments</div><div class=\"vmo-live-badge\"><span class=\"vmo-live-dot\"></span> Çevrimici · Öğreniyor</div></div></div><div id=\"vmo-brain-ctx\" style=\"display:flex;gap:10px;align-items:center;flex-wrap:wrap;font-size:12px;color:#a78bfa;padding:8px 16px;border-bottom:1px solid rgba(225,29,72,0.2);background:rgba(0,0,0,0.2);flex-shrink:0\"><span id=\"vmo-brain-greeting\">Yükleniyor…</span><span id=\"vmo-brain-weather\" style=\"margin-left:auto\"></span><span id=\"vmo-brain-tasks-count\"></span></div><div class=\"vmo-chat-area\"><div class=\"vmo-chat-messages\" id=\"vmo-brain-msgs\"></div><form class=\"vmo-chat-form\" id=\"vmo-brain-form\" autocomplete=\"off\"><input class=\"vmo-chat-input\" type=\"text\" id=\"vmo-brain-inp\" placeholder=\"Asistanınıza yazın…\" autocomplete=\"off\"><button type=\"button\" class=\"vmo-send-btn\" id=\"vmo-brain-mic\" title=\"Sesli komut (tr)\" style=\"background:rgba(124,58,237,0.25)\">🎤</button><button type=\"button\" class=\"vmo-send-btn\" id=\"vmo-brain-tts\" title=\"Yanıtları sesli oku\" style=\"background:rgba(255,255,255,0.08)\">🔊</button><button type=\"submit\" class=\"vmo-send-btn\" id=\"vmo-brain-send\" title=\"Gönder\"><svg width=\"16\" height=\"16\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2.2\" viewBox=\"0 0 24 24\"><line x1=\"22\" y1=\"2\" x2=\"11\" y2=\"13\"/><polygon points=\"22 2 15 22 11 13 2 9 22 2\"/></svg></button></form></div></aside><div class=\"vmo-data-wall\" style=\"display:flex;flex-direction:column;padding:0;gap:0;overflow:hidden;flex:1;max-width:380px\"><div style=\"padding:14px 16px 10px;border-bottom:1px solid rgba(225,29,72,0.2);display:flex;align-items:center;justify-content:space-between;flex-shrink:0\"><span style=\"font-weight:700;color:#f1f5f9;font-size:14px\">📋 Görev Takibi</span><div style=\"display:flex;gap:6px;align-items:center\"><button onclick=\"window._brainNewTask()\" style=\"background:#e11d48;color:#fff;border:none;border-radius:6px;padding:5px 10px;font-size:12px;cursor:pointer;font-weight:600\">+ Yeni</button><select id=\"vmo-brain-task-filter\" onchange=\"window._brainFilter(this.value)\" style=\"background:#1a0a2a;color:#a78bfa;border:1px solid rgba(225,29,72,0.3);border-radius:6px;padding:4px 8px;font-size:12px;cursor:pointer\"><option value=\"open\">Açık</option><option value=\"in_progress\">Devam</option><option value=\"done\">Bitti</option><option value=\"all\">Tümü</option></select></div></div><div id=\"vmo-brain-task-list\" style=\"flex:1;overflow-y:auto;padding:10px 16px;min-height:0\"><div style=\"color:#64748b;font-size:12px;text-align:center;padding:40px 0\">Yükleniyor…</div></div><details style=\"font-size:12px;flex-shrink:0;border-top:1px solid rgba(225,29,72,0.2);padding:10px 16px;background:rgba(0,0,0,0.2)\"><summary style=\"cursor:pointer;color:#7c3aed;font-weight:600;padding:4px 0;list-style:none\">⚙️ Sahip Ayarları</summary><div style=\"margin-top:8px;display:flex;flex-direction:column;gap:6px\"><input id=\"vmo-bp-name\" placeholder=\"Adınız\" style=\"background:#1a0a2a;border:1px solid rgba(255,255,255,0.1);border-radius:6px;padding:6px 10px;font-size:12px;color:#f1f5f9;outline:none\"><input id=\"vmo-bp-title\" placeholder=\"Unvanınız (CEO, Kurucu...)\" style=\"background:#1a0a2a;border:1px solid rgba(255,255,255,0.1);border-radius:6px;padding:6px 10px;font-size:12px;color:#f1f5f9;outline:none\"><input id=\"vmo-bp-company\" placeholder=\"Şirket adı\" style=\"background:#1a0a2a;border:1px solid rgba(255,255,255,0.1);border-radius:6px;padding:6px 10px;font-size:12px;color:#f1f5f9;outline:none\"><input id=\"vmo-bp-city\" placeholder=\"Şehir (İstanbul)\" style=\"background:#1a0a2a;border:1px solid rgba(255,255,255,0.1);border-radius:6px;padding:6px 10px;font-size:12px;color:#f1f5f9;outline:none\"><button onclick=\"window._brainSavePrefs()\" style=\"background:#7c3aed;color:#fff;border:none;border-radius:6px;padding:7px 12px;font-size:12px;cursor:pointer;font-weight:600\">Kaydet</button></div></details></div>";
      _off.appendChild(_br);
    }
  }

  function _renderBrainTasks(tasks, el) {
    if (!el) return;
    if (!tasks || !tasks.length) {
      el.innerHTML = '<div style="color:#64748b;font-size:12px;text-align:center;padding:40px 0">A\u00e7\u0131k g\u00f6rev yok \ud83c\udf89</div>';
      return;
    }
    const PRI_COLOR = { urgent: '#ef4444', high: '#f97316', normal: '#eab308', low: '#22c55e' };
    const PRI_ICON = { urgent: '\ud83d\udd34', high: '\ud83d\udfe0', normal: '\ud83d\udfe1', low: '\ud83d\udfe2' };
    const STA_LABEL = { open: 'A\u00e7\u0131k', in_progress: 'Devam', done: 'Bitti', cancelled: '\u0130ptal' };
    el.innerHTML = tasks.map(function(t) {
      return '<div style="display:flex;align-items:flex-start;gap:8px;padding:9px 0;border-bottom:1px solid rgba(255,255,255,0.06)">' +
        '<button onclick="window._brainMarkDone(' + t.id + ')" title="Tamamland\u0131" style="flex-shrink:0;width:18px;height:18px;border:1.5px solid ' + (PRI_COLOR[t.priority] || '#64748b') + ';border-radius:4px;background:none;cursor:pointer;margin-top:1px"></button>' +
        '<div style="flex:1;min-width:0">' +
        '<div style="font-size:12.5px;color:#f1f5f9;line-height:1.4">' + (PRI_ICON[t.priority] || '\u00b7') + ' ' + t.title + '</div>' +
        (t.assigned_to ? '<div style="font-size:11px;color:#a78bfa;margin-top:2px">\u2192 ' + t.assigned_to + '</div>' : '') +
        (t.due_date ? '<div style="font-size:11px;color:#94a3b8;margin-top:1px">\ud83d\udcc5 ' + t.due_date + '</div>' : '') +
        '</div>' +
        '<span style="font-size:10px;padding:2px 6px;border-radius:10px;background:rgba(255,255,255,0.08);color:#94a3b8;flex-shrink:0">' + (STA_LABEL[t.status] || t.status) + '</span>' +
        '</div>';
    }).join('');
  }

  async function loadBrainRoom() {
    const ctxEl = container.querySelector('#vmo-brain-ctx');
    if (!ctxEl || ctxEl._inited) return;
    ctxEl._inited = true;

    async function refreshCtx() {
      try {
        const [pr, tr] = await Promise.all([
          fetch('/api/brain/preferences', { credentials: 'include' }),
          fetch('/api/brain/tasks?status=open', { credentials: 'include' })
        ]);
        const prefs = pr.ok ? await pr.json() : {};
        const tasks = tr.ok ? await tr.json() : [];
        const tz = prefs.timezone || 'Europe/Istanbul';
        const now = new Date();
        const h = parseInt(new Intl.DateTimeFormat('en-US', { hour: 'numeric', hour12: false, timeZone: tz }).format(now));
        const t = new Intl.DateTimeFormat('tr-TR', { hour: '2-digit', minute: '2-digit', timeZone: tz }).format(now);
        const gr = h < 5 ? '\u0130yi geceler' : h < 12 ? 'G\u00fcnayd\u0131n' : h < 17 ? '\u0130yi \u00f6\u011fleden sonralar' : h < 21 ? '\u0130yi ak\u015famlar' : '\u0130yi geceler';
        const name = prefs.owner_name || 'Patron';
        const gEl = container.querySelector('#vmo-brain-greeting');
        if (gEl) gEl.textContent = gr + ', ' + name + ' \u00b7 ' + t;
        const wEl = container.querySelector('#vmo-brain-weather');
        if (wEl) wEl.textContent = prefs.location_city ? '\ud83d\udccd ' + prefs.location_city : '';
        const cEl = container.querySelector('#vmo-brain-tasks-count');
        const urgent = tasks.filter(function(t){ return t.priority === 'urgent'; }).length;
        if (cEl) {
          cEl.textContent = '\ud83d\udccb ' + tasks.length + ' g\u00f6rev' + (urgent ? ' \u00b7 ' + urgent + ' AC\u0130L' : '');
          cEl.style.color = urgent ? '#ef4444' : '';
        }
        const pn = container.querySelector('#vmo-bp-name'); if (pn && prefs.owner_name) pn.value = prefs.owner_name;
        const po = container.querySelector('#vmo-bp-title'); if (po && prefs.owner_title) po.value = prefs.owner_title;
        const pc = container.querySelector('#vmo-bp-company'); if (pc && prefs.company_name) pc.value = prefs.company_name;
        const py = container.querySelector('#vmo-bp-city'); if (py && prefs.location_city) py.value = prefs.location_city;
        _renderBrainTasks(tasks, container.querySelector('#vmo-brain-task-list'));
      } catch(e) { console.error('[Brain ctx]', e); }
    }

    await refreshCtx();

    const msgsEl = container.querySelector('#vmo-brain-msgs');
    const inp = container.querySelector('#vmo-brain-inp');
    const form = container.querySelector('#vmo-brain-form');

    async function sendBrainMsg(msg, isGreeting) {
      if (!msg || !msg.trim()) return;
      inp.disabled = true;
      const ub = document.createElement('div');
      ub.style.cssText = 'text-align:right;margin:7px 0';
      ub.innerHTML = '<span style="background:#e11d48;color:#fff;padding:9px 14px;border-radius:16px 16px 3px 16px;font-size:13.5px;display:inline-block;max-width:85%;text-align:left;line-height:1.5">' + msg + '</span>';
      msgsEl.appendChild(ub); msgsEl.scrollTop = msgsEl.scrollHeight;
      const th = document.createElement('div');
      th.id = 'vmo-brain-thinking';
      th.style.cssText = 'margin:7px 0;padding:10px 14px;background:rgba(167,139,250,0.1);border-left:3px solid #7c3aed;border-radius:0 12px 12px 0;font-size:13px;color:#a78bfa;font-style:italic';
      th.textContent = '\ud83d\udcad D\u00fc\u015f\u00fcn\u00fcyor\u2026';
      msgsEl.appendChild(th); msgsEl.scrollTop = msgsEl.scrollHeight;
      try {
        const res = await fetch('/api/brain/chat', {
          method: 'POST', credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: msg, is_greeting: !!isGreeting })
        });
        const thEl = document.getElementById('vmo-brain-thinking');
        if (thEl) thEl.remove();
        if (!res.ok) {
          const err = document.createElement('div');
          err.style.cssText = 'color:#ef4444;font-size:12px;margin:7px 0';
          err.textContent = 'Hata: HTTP ' + res.status;
          msgsEl.appendChild(err); return;
        }
        const bubble = document.createElement('div');
        bubble.style.cssText = 'margin:7px 0;padding:12px 14px;background:rgba(225,29,72,0.08);border-left:3px solid #e11d48;border-radius:0 12px 12px 0;font-size:13.5px;line-height:1.6;color:#f1f5f9;white-space:pre-wrap;max-width:92%';
        msgsEl.appendChild(bubble); msgsEl.scrollTop = msgsEl.scrollHeight;
        const reader = res.body.getReader(); const dec = new TextDecoder(); let buf = ''; let txt = '';
        while (true) {
          const { done, value } = await reader.read(); if (done) break;
          buf += dec.decode(value, { stream: true });
          const lines = buf.split('\n'); buf = lines.pop();
          for (let i = 0; i < lines.length; i++) {
            const ln = lines[i];
            if (!ln.startsWith('data: ')) continue;
            try {
              const d = JSON.parse(ln.slice(6));
              if (d.text) { txt += d.text; bubble.textContent = txt; msgsEl.scrollTop = msgsEl.scrollHeight; }
              if (d.tool && (d.tool === 'create_task' || d.tool === 'update_task')) {
                setTimeout(function() {
                  fetch('/api/brain/tasks?status=open', { credentials: 'include' })
                    .then(function(r){ return r.json(); })
                    .then(function(t){ _renderBrainTasks(t, container.querySelector('#vmo-brain-task-list')); })
                    .catch(function(){});
                }, 800);
              }
            } catch(pe) {}
          }
        }
        if (window._brainTTS && txt && txt.trim()) { try { _brainSpeak(txt); } catch(_){} }
      } catch(e) {
        const thEl2 = document.getElementById('vmo-brain-thinking');
        if (thEl2) thEl2.remove();
        const err = document.createElement('div');
        err.style.cssText = 'color:#ef4444;font-size:12px;margin:7px 0';
        err.textContent = 'Ba\u011flant\u0131 hatas\u0131: ' + e.message;
        msgsEl.appendChild(err);
      } finally {
        inp.disabled = false;
        inp.focus();
      }
    }

    if (form) {
      form.addEventListener('submit', function(e) {
        e.preventDefault();
        const v = inp.value.trim();
        if (v) { inp.value = ''; sendBrainMsg(v); }
      });
    }

    // Voice I/O (Türkçe) — VOICE_IO_V1
    (function(){
      var micBtn = container.querySelector('#vmo-brain-mic');
      var ttsBtn = container.querySelector('#vmo-brain-tts');
      window._brainTTS = false;
      window._brainSpeak = function(text){
        try {
          if (!('speechSynthesis' in window)) return;
          window.speechSynthesis.cancel();
          var clean = String(text).replace(/[*_`#>|]/g,'').replace(/\s+/g,' ').trim();
          if (!clean) return;
          var u = new SpeechSynthesisUtterance(clean);
          u.lang = 'tr-TR'; u.rate = 1.05;
          var vs = window.speechSynthesis.getVoices();
          var tv = vs.find(function(v){ return /tr(-|_)?TR/i.test(v.lang) || /türk|turk/i.test(v.name); });
          if (tv) u.voice = tv;
          window.speechSynthesis.speak(u);
        } catch(_){}
      };
      if (ttsBtn) {
        ttsBtn.addEventListener('click', function(){
          window._brainTTS = !window._brainTTS;
          ttsBtn.style.background = window._brainTTS ? '#7c3aed' : 'rgba(255,255,255,0.08)';
          ttsBtn.title = window._brainTTS ? 'Sesli okuma açık' : 'Yanıtları sesli oku';
          if (!window._brainTTS && ('speechSynthesis' in window)) window.speechSynthesis.cancel();
        });
      }
      var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SR) { if (micBtn) { micBtn.style.opacity = '0.4'; micBtn.title = 'Tarayıcı sesli komutu desteklemiyor'; } return; }
      var rec = new SR();
      rec.lang = 'tr-TR'; rec.interimResults = true; rec.continuous = false;
      var listening = false;
      rec.onresult = function(ev){
        var interim = '', fin = '';
        for (var i = ev.resultIndex; i < ev.results.length; i++) {
          var r = ev.results[i];
          if (r.isFinal) fin += r[0].transcript; else interim += r[0].transcript;
        }
        inp.value = (fin || interim);
      };
      rec.onend = function(){
        listening = false;
        if (micBtn) micBtn.style.background = 'rgba(124,58,237,0.25)';
        var v = inp.value.trim();
        if (v) { inp.value = ''; sendBrainMsg(v); }
      };
      rec.onerror = function(){ listening = false; if (micBtn) micBtn.style.background = 'rgba(124,58,237,0.25)'; };
      if (micBtn) {
        micBtn.addEventListener('click', function(){
          if (listening) { try { rec.stop(); } catch(_){} return; }
          try { inp.value = ''; rec.start(); listening = true; micBtn.style.background = '#e11d48'; } catch(_){}
        });
      }
    })();

    window._brainMarkDone = async function(id) {
      try {
        await fetch('/api/brain/tasks/' + id, {
          method: 'PATCH', credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'done' })
        });
        const tasks = await fetch('/api/brain/tasks?status=open', { credentials: 'include' }).then(function(r){ return r.json(); });
        _renderBrainTasks(tasks, container.querySelector('#vmo-brain-task-list'));
        const cEl = container.querySelector('#vmo-brain-tasks-count');
        const urgent = tasks.filter(function(t){ return t.priority === 'urgent'; }).length;
        if (cEl) {
          cEl.textContent = '\ud83d\udccb ' + tasks.length + ' g\u00f6rev' + (urgent ? ' \u00b7 ' + urgent + ' AC\u0130L' : '');
          cEl.style.color = urgent ? '#ef4444' : '';
        }
      } catch(e) { console.error('[Brain markDone]', e); }
    };

    window._brainNewTask = function() {
      const title = prompt('G\u00f6rev ba\u015fl\u0131\u011f\u0131:');
      if (!title || !title.trim()) return;
      const pri = prompt('Aciliyet? urgent / high / normal / low', 'normal') || 'normal';
      const asgn = prompt('Kim yapacak? (bo\u015f b\u0131rakabilirsiniz)', '') || null;
      fetch('/api/brain/tasks', {
        method: 'POST', credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: title.trim(), priority: pri, assigned_to: asgn })
      })
        .then(function(){ return fetch('/api/brain/tasks?status=open', { credentials: 'include' }); })
        .then(function(r){ return r.json(); })
        .then(function(t){ _renderBrainTasks(t, container.querySelector('#vmo-brain-task-list')); })
        .catch(function(e){ alert('Hata: ' + e.message); });
    };

    window._brainFilter = function(status) {
      fetch('/api/brain/tasks?status=' + status, { credentials: 'include' })
        .then(function(r){ return r.json(); })
        .then(function(t){ _renderBrainTasks(t, container.querySelector('#vmo-brain-task-list')); })
        .catch(function(){});
    };

    window._brainSavePrefs = async function() {
      try {
        const nm = container.querySelector('#vmo-bp-name');
        const ti = container.querySelector('#vmo-bp-title');
        const co = container.querySelector('#vmo-bp-company');
        const ci = container.querySelector('#vmo-bp-city');
        await fetch('/api/brain/preferences', {
          method: 'POST', credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            owner_name: nm ? nm.value || null : null,
            owner_title: ti ? ti.value || null : null,
            company_name: co ? co.value || null : null,
            location_city: ci ? ci.value || null : null
          })
        });
        await refreshCtx();
        alert('Kaydedildi!');
      } catch(e) { alert('Hata: ' + e.message); }
    };

    if (!msgsEl.children.length) {
      setTimeout(function() { sendBrainMsg('Merhaba! Bug\u00fcnk\u00fc genel durumu \u00f6zetle.', true); }, 700);
    }
  }

  function _initHub() {
    var wrap = container.querySelector('#vmo-hub-wrap');
    if (!wrap || wrap.dataset.hubInit) return;
    wrap.dataset.hubInit = '1';
    var nodesEl = document.getElementById('vmo-hub-nodes');
    if (!nodesEl) return;
    // Build agent node cards from OFFICERS
    nodesEl.innerHTML = OFFICERS.map(function(o) {
      return '<div class="vmo-hub-node" data-dept="' + o.id + '">' +
        '<div class="vmo-hub-node-icon" style="background:' + o.color + '1a;border-color:' + o.color + ';box-shadow:0 0 12px ' + o.color + '33">' + o.emoji + '</div>' +
        '<div><div class="vmo-hub-node-label">' + o.label + '</div>' +
        '<div class="vmo-hub-node-name">' + o.name + '</div></div>' +
      '</div>';
    }).join('') +
    // Saha modülü canlı düğümü — rozetler /api/saha/canli-ozet ile beslenir
    '<div class="vmo-hub-node" data-saha="1" id="vmo-saha-node">' +
      '<div class="vmo-hub-node-icon" style="background:#0ea5e91a;border-color:#0ea5e9;box-shadow:0 0 12px #0ea5e933;position:relative">📍' +
        '<span id="vmo-saha-badge" style="display:none;position:absolute;top:-6px;right:-6px;min-width:18px;height:18px;border-radius:9px;background:#e11d48;color:#fff;font-size:11px;font-weight:700;align-items:center;justify-content:center;padding:0 4px;box-shadow:0 0 8px #e11d48aa"></span>' +
      '</div>' +
      '<div><div class="vmo-hub-node-label">Saha</div>' +
      '<div class="vmo-hub-node-name">Saha Ekibi</div>' +
      '<div id="vmo-saha-mini" style="font-size:10px;color:#38bdf8;margin-top:2px"></div></div>' +
    '</div>';
    // ── Saha canlı veri: rozetler + nabız + olay paneli ──────────────────────
    var _sahaSonOlay = null, _sahaData = null;
    if (!document.getElementById('vmo-saha-css')) {
      var _scss = document.createElement('style');
      _scss.id = 'vmo-saha-css';
      _scss.textContent =
        '@keyframes vmoSahaPulse{0%{box-shadow:0 0 12px #0ea5e933}50%{box-shadow:0 0 34px #0ea5e9ee,0 0 60px #0ea5e955}100%{box-shadow:0 0 12px #0ea5e933}}' +
        '.vmo-saha-pulse{animation:vmoSahaPulse 1s ease-in-out 4}' +
        '#vmo-saha-panel{display:none;position:fixed;top:64px;right:14px;bottom:14px;width:360px;max-width:min(360px,calc(100vw - 60px));z-index:9990;background:linear-gradient(160deg,#07182a 0%,#0a0a1e 100%);border:1px solid #0ea5e955;border-radius:16px;box-shadow:0 12px 50px rgba(0,0,0,.6);overflow:hidden;flex-direction:column;font-family:inherit;color:#e2e8f0}' +
        '#vmo-saha-panel .sp-head{padding:14px 16px;border-bottom:1px solid #0ea5e933;display:flex;align-items:center;gap:8px}' +
        '#vmo-saha-panel .sp-sayilar{display:flex;gap:8px;padding:10px 16px;border-bottom:1px solid #0ea5e922;flex-wrap:wrap}' +
        '#vmo-saha-panel .sp-kut{background:#0ea5e912;border:1px solid #0ea5e930;border-radius:9px;padding:6px 10px;font-size:11px;color:#7dd3fc}' +
        '#vmo-saha-panel .sp-kut b{display:block;font-size:16px;color:#e0f2fe}' +
        '#vmo-saha-panel .sp-akis{flex:1;overflow-y:auto;padding:8px 12px}' +
        '#vmo-saha-panel .sp-olay{background:rgba(255,255,255,.03);border:1px solid rgba(14,165,233,.15);border-radius:10px;padding:9px 11px;margin-bottom:8px;font-size:12px}' +
        '#vmo-saha-panel .sp-olay small{color:#64748b}' +
        '#vmo-saha-panel .sp-aksiyon{display:flex;gap:6px;margin-top:6px}' +
        '#vmo-saha-panel .sp-aksiyon a{background:#0ea5e922;border:1px solid #0ea5e94d;color:#7dd3fc;border-radius:7px;padding:3px 9px;font-size:11px;text-decoration:none}' +
        '#vmo-saha-panel .sp-aksiyon a:hover{background:#0ea5e944}' +
        '#vmo-saha-panel .sp-alt{padding:10px 16px;border-top:1px solid #0ea5e933;display:flex;gap:8px}';
      document.head.appendChild(_scss);
    }
    function _sahaEsc(s) {
      return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
      });
    }
    function _sahaZaman(ts) {
      var f = (Date.now() - new Date(ts).getTime()) / 60000;
      if (f < 1) return 'şimdi';
      if (f < 60) return Math.round(f) + ' dk önce';
      if (f < 1440) return Math.round(f / 60) + ' sa önce';
      return new Date(ts).toLocaleDateString('tr-TR');
    }
    function _sahaPoll() {
      if (!document.getElementById('vmo-saha-node')) return;
      apiFetch('/api/saha/canli-ozet').then(function(d) {
        _sahaData = d;
        var bekleyen = (d.bekleyen_gm || 0) + (d.bekleyen_mudur || 0);
        var badge = document.getElementById('vmo-saha-badge');
        if (badge) {
          badge.style.display = bekleyen > 0 ? 'flex' : 'none';
          badge.textContent = bekleyen;
        }
        var mini = document.getElementById('vmo-saha-mini');
        if (mini) mini.textContent = '🟢 ' + (d.bugun_ziyaret || 0) + ' ziyaret · 🟠 ' + (d.acik_teklif || 0) + ' teklif';
        var enYeni = d.olaylar && d.olaylar[0] ? d.olaylar[0].created_at : null;
        if (_sahaSonOlay && enYeni && enYeni !== _sahaSonOlay) {
          var ic = document.querySelector('#vmo-saha-node .vmo-hub-node-icon');
          if (ic) { ic.classList.add('vmo-saha-pulse'); setTimeout(function() { ic.classList.remove('vmo-saha-pulse'); }, 4500); }
        }
        if (enYeni) _sahaSonOlay = enYeni;
        var panel = document.getElementById('vmo-saha-panel');
        // Detay görünümü açıkken poll listeyi ezmesin
        if (panel && panel.style.display === 'flex' && !panel.dataset.detay) _sahaPanelRender();
      }).catch(function() {
        // API hatası: düğümü gizleme, sadece canlı veri gösterme
        var mini = document.getElementById('vmo-saha-mini');
        if (mini) mini.textContent = '';
      });
    }
    function _sahaPanelRender() {
      var p = document.getElementById('vmo-saha-panel');
      if (!p || !_sahaData) return;
      p.dataset.detay = '';
      var d = _sahaData;
      var TIP_IKON   = { ZIYARET: '📋', TEKLIF: '📄', ISKONTO: '💰' };
      var TIP_ETIKET = { ZIYARET: 'Ziyaret', TEKLIF: 'Teklif', ISKONTO: 'İskonto Talebi' };
      var TIP_RENK   = { ZIYARET: '#0ea5e9', TEKLIF: '#8b5cf6', ISKONTO: '#f59e0b' };
      p.innerHTML =
        '<div class="sp-head"><span style="font-size:18px">📍</span><b>Saha — Canlı Akış</b>' +
        '<button id="sp-kapat" style="margin-left:auto;background:none;border:0;color:#64748b;font-size:18px;cursor:pointer">✕</button></div>' +
        '<div class="sp-sayilar">' +
          '<div class="sp-kut sp-kut-nav" data-nav="ISKONTO" style="cursor:pointer" title="Bekleyen onayları görüntüle"><b style="color:' + ((d.bekleyen_gm + d.bekleyen_mudur) > 0 ? '#f87171' : '#e0f2fe') + '">' + (d.bekleyen_gm + d.bekleyen_mudur) + '</b>Bekleyen Onay</div>' +
          '<div class="sp-kut sp-kut-nav" data-nav="TEKLIF"  style="cursor:pointer" title="Açık teklifleri görüntüle"><b>' + d.acik_teklif + '</b>Açık Teklif</div>' +
          '<div class="sp-kut sp-kut-nav" data-nav="ZIYARET" data-filtre="bugun" style="cursor:pointer" title="Bugünkü ziyaretleri görüntüle"><b>' + d.bugun_ziyaret + '</b>Bugün Ziyaret</div>' +
          '<div class="sp-kut sp-kut-nav" data-nav="ZIYARET" style="cursor:pointer" title="Planlanmış ziyaretleri görüntüle"><b>' + d.bugun_planli + '</b>Bugün Planlı</div>' +
        '</div>' +
        '<div style="font-size:11px;color:#64748b;font-weight:600;letter-spacing:.05em;text-transform:uppercase;padding:8px 16px 4px">Son 30 Gün Aktivite</div>' +
        '<div class="sp-akis">' +
        ((d.olaylar || []).map(function(o) {
          var tel = (o.telefon || '').replace(/\D/g, '');
          var waMsg = encodeURIComponent('Merhaba ' + (o.rep || '') + ', ' + (o.firma || '') + ' için girdiğin kaydı gördüm. ');
          var zamanLabel = o.olay_tarihi ? o.olay_tarihi : _sahaZaman(o.created_at);
          return '<div class="sp-olay" data-olay-tip="' + _sahaEsc(o.tip) + '" data-olay-id="' + _sahaEsc(o.kayit_id || '') + '" style="cursor:pointer" title="Detay için tıkla">' +
            '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:3px">' +
              '<span style="font-size:10px;font-weight:700;color:' + (TIP_RENK[o.tip] || '#94a3b8') + ';text-transform:uppercase;letter-spacing:.06em">' + (TIP_IKON[o.tip] || '•') + ' ' + (TIP_ETIKET[o.tip] || o.tip) + '</span>' +
              '<small style="color:#64748b">' + zamanLabel + '</small>' +
            '</div>' +
            '<div><b>' + _sahaEsc(o.firma) + '</b></div>' +
            '<div style="color:#94a3b8;margin-top:2px;font-size:12px">' + _sahaEsc(o.detay || '') + '</div>' +
            '<div style="color:#64748b;font-size:11px;margin-top:2px">👤 ' + _sahaEsc(o.rep || '—') + '</div>' +
            '<div class="sp-aksiyon">' +
              (tel ? '<a href="https://wa.me/' + tel + '?text=' + waMsg + '" target="_blank">📱 WhatsApp</a>' : '') +
              (o.email ? '<a href="mailto:' + _sahaEsc(o.email) + '?subject=' + encodeURIComponent('Saha: ' + (o.firma || '')) + '">✉️ E-posta</a>' : '') +
            '</div></div>';
        }).join('') || '<div style="color:#64748b;text-align:center;padding:30px 0;font-size:12px">Henüz olay yok.</div>') +
        '</div>' +
        '<div class="sp-alt">' +
          '<button id="sp-ac" style="flex:1;background:#0ea5e9;border:0;color:#fff;border-radius:9px;padding:10px;font-weight:700;cursor:pointer">Saha Modülünü Aç</button>' +
        '</div>';
      p.querySelector('#sp-kapat').addEventListener('click', function() { p.style.display = 'none'; });
      // KPI tile tıklama → Saha modülünü aç ve ilgili görünüme git
      p.querySelectorAll('.sp-kut-nav').forEach(function(el) {
        el.addEventListener('click', function() {
          var nav = el.dataset.nav; // ISKONTO | TEKLIF | ZIYARET
          var t = document.getElementById('saha-module-toggle');
          if (!t) { alert('Saha modülü yüklenemedi — sayfayı yenileyin.'); return; }
          p.style.display = 'none';
          if (el.dataset.filtre === 'bugun') window.__sahaGunFiltre = true;
          if (typeof window.__sahaGit === 'function') {
            // Module already loaded — open it then navigate
            t.click();
            setTimeout(function() { window.__sahaGit(nav, null); }, 150);
          } else {
            // Module not yet initialized — queue nav, then open
            window.__sahaPendingNav = nav;
            t.click();
          }
        });
      });
      // Olay kartına tıklama → panel İÇİNDE tam detay görünümü (modül değişmez)
      p.querySelectorAll('.sp-olay').forEach(function(el) {
        el.addEventListener('click', function(ev) {
          if (ev.target.closest('a')) return; // WhatsApp/E-posta linkleri kendi işini yapsın
          _sahaOlayDetay(el.dataset.olayTip, el.dataset.olayId);
        });
      });
      p.querySelector('#sp-ac').addEventListener('click', function() {
        var t = document.getElementById('saha-module-toggle');
        if (t) { p.style.display = 'none'; t.click(); }
        else alert('Saha modülü yüklenemedi — sayfayı yenileyin.');
      });
    }
    function _sahaOlayDetay(tip, id) {
      var p = document.getElementById('vmo-saha-panel');
      if (!p || !id) return;
      var akis = p.querySelector('.sp-akis');
      if (akis) akis.innerHTML = '<div style="color:#64748b;text-align:center;padding:30px 0;font-size:12px">Yükleniyor…</div>';
      apiFetch('/api/saha/olay-detay?tip=' + encodeURIComponent(tip) + '&id=' + encodeURIComponent(id))
        .then(function(d) { _sahaDetayRender(d); })
        .catch(function(e) {
          if (akis) akis.innerHTML = '<div style="color:#f87171;text-align:center;padding:30px 0;font-size:12px">⚠ ' + _sahaEsc(e.message) + '</div>';
        });
    }
    function _sahaDetayRender(d) {
      var p = document.getElementById('vmo-saha-panel');
      if (!p) return;
      p.dataset.detay = '1';
      var k = d.kayit || {};
      var det = k.detay || {};
      function satir(l, v) {
        if (v == null || v === '' || v === false) return '';
        return '<div style="display:flex;justify-content:space-between;gap:10px;padding:6px 0;border-bottom:1px solid rgba(14,165,233,.12);font-size:12px">' +
          '<span style="color:#64748b;flex-shrink:0">' + l + '</span><b style="color:#e0f2fe;text-align:right">' + _sahaEsc(String(v)) + '</b></div>';
      }
      function dizi(l, a) { return Array.isArray(a) && a.length ? satir(l, a.join(', ')) : ''; }
      var trh = function(t) { return t ? new Date(t).toLocaleDateString('tr-TR') : null; };
      var para = function(v) { return v != null ? Number(v).toLocaleString('tr-TR') + '₺' : null; };
      var baslikIkon = { ZIYARET: '📋 Ziyaret', TEKLIF: '📄 Teklif', ISKONTO: '💰 İskonto Talebi' }[d.tip] || 'Detay';
      var icerik = '';
      if (d.tip === 'ZIYARET') {
        var ap = det.arac_parki || {};
        var apStr = Object.keys(ap).filter(function(x){ return ap[x]; }).map(function(x){ return ap[x] + ' ' + x; }).join(', ');
        icerik = satir('Durum', { PLANLANDI: 'Planlandı', TAMAMLANDI: 'Tamamlandı ✓', IPTAL: 'İptal' }[k.durum] || k.durum) +
          satir('Tarih', trh(k.ziyaret_tarihi) || trh(k.planlanan_tarih)) +
          satir('Tip', k.tip === 'TUKETICI' ? 'Tüketici' : 'Ticari') +
          satir('Konum', [k.il, k.ilce].filter(Boolean).join(' / ')) +
          satir('Görüşülen kişi', k.katilimci) +
          (k.checkin_at ? satir('Check-in', new Date(k.checkin_at).toLocaleString('tr-TR') + ' 📍') : '') +
          dizi('Raf markaları', det.raf_markalari) + dizi('Bayilikler', det.bayilikler) +
          dizi('Rakipler', det.rakipler) + dizi('Kullanılan markalar', det.kullanilan_markalar) +
          satir('Kış stok', det.kis_stok) + satir('Yaz stok', det.yaz_stok) +
          satir('Sektör', det.sektor) + satir('Araç parkı', apStr || null) +
          satir('Tedarikçi', det.tedarikci) + satir('Yıllık potansiyel', det.yillik_potansiyel) +
          (k.notlar ? '<div style="background:rgba(255,255,255,.04);border-radius:9px;padding:10px;font-size:12px;color:#cbd5e1;margin-top:10px;white-space:pre-wrap">' + _sahaEsc(k.notlar) + '</div>' : '') +
          ((d.fotolar || []).length ? '<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:10px">' +
            d.fotolar.map(function(f) { return '<img src="' + f + '" style="width:76px;height:76px;object-fit:cover;border-radius:8px;border:1px solid rgba(14,165,233,.3)">'; }).join('') + '</div>' : '');
      } else if (d.tip === 'TEKLIF') {
        icerik = satir('Durum', { BEKLEMEDE: 'Beklemede', KAZANILDI: 'Kazanıldı ✓', KAYBEDILDI: 'Kaybedildi ✕', IPTAL: 'İptal' }[k.durum] || k.durum) +
          satir('Ürün', [k.marka, k.model].filter(Boolean).join(' ')) +
          satir('Ebat', k.ebat) + satir('Adet', k.adet) +
          satir('Birim fiyat', para(k.birim_fiyat)) + satir('Toplam', para(k.toplam_tutar)) +
          satir('Uyg. iskonto', k.iskonto_orani != null ? '%' + Number(k.iskonto_orani) : null) +
          satir('Sonuç tarihi', trh(k.sonuc_tarihi)) +
          (k.durum === 'KAYBEDILDI' ?
            '<div style="border-left:3px solid #ef4444;padding:8px 10px;margin-top:8px;font-size:12px;background:rgba(239,68,68,.08);border-radius:0 8px 8px 0">' +
            'Kaybedildi → <b>' + _sahaEsc([k.rakip_marka, k.rakip_model].filter(Boolean).join(' ') || '?') + '</b>' +
            (k.rakip_fiyat ? ' · ' + para(k.rakip_fiyat) : '') +
            (k.kayip_nedeni ? ' · Neden: ' + _sahaEsc(k.kayip_nedeni) : '') + '</div>' : '') +
          (k.notlar ? '<div style="background:rgba(255,255,255,.04);border-radius:9px;padding:10px;font-size:12px;color:#cbd5e1;margin-top:10px">' + _sahaEsc(k.notlar) + '</div>' : '');
      } else {
        icerik = satir('Durum', { ONAYLANDI: 'Onaylandı ✓', REDDEDILDI: 'Reddedildi ✕', BEKLIYOR_MUDUR: 'Müdür onayı bekliyor', BEKLIYOR_GM: 'GM onayı bekliyor' }[k.durum] || k.durum) +
          satir('İstenen oran', '%' + Number(k.istenen_oran)) +
          satir('Onaylanan oran', k.onaylanan_oran != null ? '%' + Number(k.onaylanan_oran) : null) +
          satir('Ürün', [k.marka, k.ebat, k.urun_grubu].filter(Boolean).join(' · ')) +
          satir('Liste fiyat', para(k.liste_fiyat)) +
          satir('Müşteri bakiye', para(k.bakiye)) +
          (Number(k.vadesi_gecmis_tutar) > 0 ? satir('⚠ Vadesi geçmiş', para(k.vadesi_gecmis_tutar)) : '') +
          satir('Karar veren', k.karar_veren_adi) + satir('Karar notu', k.karar_notu) +
          (k.gerekce ? '<div style="background:rgba(255,255,255,.04);border-radius:9px;padding:10px;font-size:12px;color:#cbd5e1;margin-top:10px">' + _sahaEsc(k.gerekce) + '</div>' : '');
      }
      var tel = (k.rep_telefon || '').replace(/\D/g, '');
      var waMsg = encodeURIComponent('Merhaba ' + (k.rep_full_name || '') + ', ' + (k.firma || '') + ' kaydınla ilgili. ');
      p.innerHTML =
        '<div class="sp-head"><button id="sp-geri" style="background:none;border:0;color:#38bdf8;font-size:14px;cursor:pointer;font-weight:700">← Geri</button>' +
        '<b style="margin-left:4px">' + baslikIkon + '</b>' +
        '<button id="sp-kapat" style="margin-left:auto;background:none;border:0;color:#64748b;font-size:18px;cursor:pointer">✕</button></div>' +
        '<div class="sp-akis">' +
          '<div style="font-size:15px;font-weight:700;color:#e0f2fe;margin-bottom:2px">' + _sahaEsc(k.firma || '') + '</div>' +
          '<div style="font-size:11px;color:#64748b;margin-bottom:10px">👤 ' + _sahaEsc(k.rep_full_name || k.rep_adi || '—') +
          ' · ' + _sahaZaman(k.created_at) + (k.musteri_kodu ? ' · ' + _sahaEsc(k.musteri_kodu) : '') + '</div>' +
          icerik +
        '</div>' +
        '<div class="sp-alt">' +
          (tel ? '<a href="https://wa.me/' + tel + '?text=' + waMsg + '" target="_blank" style="flex:1;text-align:center;background:#0ea5e922;border:1px solid #0ea5e94d;color:#7dd3fc;border-radius:9px;padding:10px;font-weight:700;text-decoration:none;font-size:13px">📱 WhatsApp</a>' : '') +
          (k.rep_email ? '<a href="mailto:' + _sahaEsc(k.rep_email) + '?subject=' + encodeURIComponent('Saha: ' + (k.firma || '')) + '" style="flex:1;text-align:center;background:#0ea5e922;border:1px solid #0ea5e94d;color:#7dd3fc;border-radius:9px;padding:10px;font-weight:700;text-decoration:none;font-size:13px">✉️ E-posta</a>' : '') +
        '</div>';
      p.querySelector('#sp-geri').addEventListener('click', function() { _sahaPanelRender(); });
      p.querySelector('#sp-kapat').addEventListener('click', function() { p.style.display = 'none'; });
    }
    function _sahaPanelToggle() {
      var p = document.getElementById('vmo-saha-panel');
      if (!p) { p = document.createElement('div'); p.id = 'vmo-saha-panel'; document.body.appendChild(p); }
      if (p.style.display === 'flex') { p.style.display = 'none'; return; }
      p.style.display = 'flex';
      _sahaPanelRender();
      _sahaPoll();
    }
    _sahaPoll();
    var _sahaTimer = setInterval(function() {
      if (!document.getElementById('vmo-saha-node')) { clearInterval(_sahaTimer); return; }
      _sahaPoll();
    }, 30000);

    // Position nodes in circle (desktop)
    var _raf = null;
    function _layout() {
      var canvas = document.getElementById('vmo-hub-canvas');
      if (!canvas) return;
      var W = wrap.offsetWidth || 900, H = wrap.offsetHeight || 650;
      canvas.width = W; canvas.height = H;
      var cx = W / 2, cy = H / 2;
      var R = Math.min(W * 0.32, H * 0.34, 245);
      var nodes = nodesEl.querySelectorAll('.vmo-hub-node');
      var n = nodes.length;
      // Position agent nodes + build connection data
      var conns = [];
      nodes.forEach(function(node, i) {
        if (window.innerWidth < 700) return;
        var angle = (2 * Math.PI * i / n) - Math.PI / 2;
        var x = cx + R * Math.cos(angle), y = cy + R * Math.sin(angle);
        node.style.left = x + 'px'; node.style.top = y + 'px';
        var col = node.dataset.saha ? '#0ea5e9' : (OFFICERS[i] ? OFFICERS[i].color : '#7c3aed');
        var pts = [];
        for (var p = 0; p < 5; p++) {
          pts.push({ t: p / 5, speed: 0.0022 + Math.random() * 0.0018,
                     size: 1.6 + Math.random() * 1.4,
                     dir: p % 2 === 0 ? 1 : -1 });
        }
        conns.push({ x: x, y: y, col: col, particles: pts, phase: i * 0.72 });
      });
      // Stop previous loop
      if (_raf) { cancelAnimationFrame(_raf); _raf = null; }
      if (window.innerWidth < 700) return;
      var ctx = canvas.getContext('2d');
      var t0 = Date.now();
      function _frame() {
        if (!document.getElementById('vmo-hub-canvas')) return;
        var t = (Date.now() - t0) / 1000;
        ctx.clearRect(0, 0, W, H);
        conns.forEach(function(c) {
          // Breathing bezier control point
          var osc = Math.sin(t * 0.35 + c.phase) * 0.14;
          var cpX = (c.x + cx) / 2 + (cy - c.y) * osc;
          var cpY = (c.y + cy) / 2 + (c.x - cx) * osc;
          // Glow layers on line
          [[8, '10'], [3, '28'], [1, '50']].forEach(function(lw) {
            ctx.beginPath(); ctx.moveTo(c.x, c.y);
            ctx.quadraticCurveTo(cpX, cpY, cx, cy);
            ctx.strokeStyle = c.col + lw[1]; ctx.lineWidth = lw[0];
            ctx.lineCap = 'round'; ctx.stroke();
          });
          // Animated particles along bezier
          c.particles.forEach(function(p) {
            p.t += p.speed * p.dir;
            if (p.t > 1.08) p.t = -0.08;
            if (p.t < -0.08) p.t = 1.08;
            var pt = Math.max(0, Math.min(1, p.t));
            var bx = (1-pt)*(1-pt)*c.x + 2*(1-pt)*pt*cpX + pt*pt*cx;
            var by = (1-pt)*(1-pt)*c.y + 2*(1-pt)*pt*cpY + pt*pt*cy;
            var alpha = Math.sin(pt * Math.PI) * 0.92;
            var gr = ctx.createRadialGradient(bx, by, 0, bx, by, p.size * 5);
            gr.addColorStop(0, c.col + 'ff');
            gr.addColorStop(0.35, c.col + 'bb');
            gr.addColorStop(1, c.col + '00');
            ctx.globalAlpha = alpha;
            ctx.beginPath(); ctx.arc(bx, by, p.size * 5, 0, Math.PI * 2);
            ctx.fillStyle = gr; ctx.fill();
            ctx.globalAlpha = 1;
          });
        });
        // Brain pulse rings
        [0, 0.38, 0.76].forEach(function(offset, i) {
          var wave = ((t * 0.45 + offset) % 1);
          var wR = 36 + wave * 100;
          var wA = (1 - wave) * 0.18;
          ctx.beginPath(); ctx.arc(cx, cy, wR, 0, Math.PI * 2);
          ctx.strokeStyle = 'rgba(225,29,72,' + wA.toFixed(3) + ')';
          ctx.lineWidth = 1.5; ctx.stroke();
        });
        // Subtle ambient glow at center
        var ag = ctx.createRadialGradient(cx, cy, 0, cx, cy, R * 0.6);
        ag.addColorStop(0, 'rgba(225,29,72,0.04)');
        ag.addColorStop(1, 'transparent');
        ctx.fillStyle = ag; ctx.fillRect(0, 0, W, H);
        _raf = requestAnimationFrame(_frame);
      }
      _frame();
    }
    // ResizeObserver guarantees layout runs after container has real painted dimensions
    var _rt;
    if (typeof ResizeObserver !== 'undefined') {
      var _ro = new ResizeObserver(function() { clearTimeout(_rt); _rt = setTimeout(_layout, 60); });
      _ro.observe(wrap);
    } else {
      requestAnimationFrame(function() { requestAnimationFrame(_layout); });
    }
    window.addEventListener('resize', function() { clearTimeout(_rt); _rt = setTimeout(_layout, 200); });
    // Node click → navigate to agent room
    nodesEl.addEventListener('click', function(e) {
      var node = e.target.closest('.vmo-hub-node');
      if (!node) return;
      if (node.dataset.saha) { _sahaPanelToggle(); return; }
      var tab = container.querySelector('.vmo-tab[data-dept="' + node.dataset.dept + '"]');
      if (tab) tab.click();
    });
    // Command input → route to Brain agent
    var form = document.getElementById('vmo-hub-form');
    var inp  = document.getElementById('vmo-hub-inp');
    if (form && inp) {
      form.addEventListener('submit', function(e) {
        e.preventDefault();
        var q = inp.value.trim(); if (!q) return; inp.value = '';
        var bt = container.querySelector('.vmo-tab[data-dept="brain"]');
        if (bt) bt.click();
        setTimeout(function() {
          var bi = document.getElementById('vmo-brain-inp');
          var bf = document.getElementById('vmo-brain-form');
          if (bi) { bi.value = q; bi.focus(); }
          if (bf) bf.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
        }, 180);
      });
    }
  }

  container.querySelectorAll(".vmo-tab").forEach(tab => {
    tab.addEventListener("click", () => {
      activeDept = tab.dataset.dept;
      container.querySelectorAll(".vmo-tab").forEach(t => t.classList.remove("active"));
      tab.classList.add("active");
      container.querySelectorAll(".vmo-room").forEach(r => {
        r.classList.toggle("vmo-room-hidden", r.dataset.dept !== activeDept);
      });
      loadDeptData(activeDept);
      if (activeDept === 'home') setTimeout(_initHub, 60);
    });
  });

  // Init hub on first load (default is home)
  setTimeout(_initHub, 120);

  container.querySelector("#vmo-logout").addEventListener("click", logout);

  // ── Feedback modal (simple global approach) ───────────────────────────────
  (function setupFeedback() {
    // Inject modal HTML into body
    const modal = document.createElement('div');
    modal.id = 'vmo-fb-modal';
    modal.style.cssText = 'display:none;position:fixed;inset:0;z-index:9999;background:rgba(0,0,0,0.65);backdrop-filter:blur(4px);align-items:center;justify-content:center';
    modal.innerHTML = '<div style="background:#0f172a;border:1px solid rgba(255,255,255,0.12);border-radius:14px;padding:24px;width:min(480px,90vw);box-shadow:0 20px 60px rgba(0,0,0,0.5)">' +
      '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:16px">' +
        '<span style="font-size:15px;font-weight:700;color:#f1f5f9">📝 Not / Geri Bildirim</span>' +
        '<button onclick="window._closeFeedback()" style="background:none;border:none;color:#94a3b8;font-size:20px;cursor:pointer;line-height:1">✕</button>' +
      '</div>' +
      '<p style="font-size:12px;color:#64748b;margin:0 0 12px">Notunuz veya talebiniz geliştiricilere iletilecektir.</p>' +
      '<textarea id="vmo-fb-text" rows="5" placeholder="Sorunuzu, talebinizi veya notunuzu yazın…" style="width:100%;box-sizing:border-box;background:#1e293b;border:1px solid rgba(255,255,255,0.12);border-radius:8px;padding:10px 12px;font-size:13px;color:#f1f5f9;resize:vertical;outline:none;font-family:inherit;line-height:1.5"></textarea>' +
      '<div style="display:flex;align-items:center;justify-content:flex-end;gap:10px;margin-top:12px">' +
        '<span id="vmo-fb-status" style="font-size:12px;color:#94a3b8;flex:1"></span>' +
        '<button onclick="window._closeFeedback()" style="background:none;border:1px solid rgba(255,255,255,0.15);color:#94a3b8;border-radius:8px;padding:8px 16px;font-size:13px;cursor:pointer">İptal</button>' +
        '<button id="vmo-fb-send" onclick="window._sendFeedback()" style="background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;border:none;border-radius:8px;padding:8px 18px;font-size:13px;font-weight:600;cursor:pointer">Gönder →</button>' +
      '</div>' +
    '</div>';
    document.body.appendChild(modal);

    window._openFeedback = function() {
      document.getElementById('vmo-fb-modal').style.display = 'flex';
      setTimeout(function() { var t = document.getElementById('vmo-fb-text'); if (t) t.focus(); }, 50);
    };
    window._closeFeedback = function() {
      document.getElementById('vmo-fb-modal').style.display = 'none';
      var t = document.getElementById('vmo-fb-text'); if (t) t.value = '';
      var s = document.getElementById('vmo-fb-status'); if (s) { s.textContent = ''; s.style.color = '#94a3b8'; }
    };
    window._sendFeedback = async function() {
      var txt = document.getElementById('vmo-fb-text');
      var status = document.getElementById('vmo-fb-status');
      var btn = document.getElementById('vmo-fb-send');
      var message = txt && txt.value && txt.value.trim();
      if (!message) { status.textContent = 'Lütfen bir mesaj yazın.'; status.style.color = '#f87171'; return; }
      btn.disabled = true; btn.textContent = 'Gönderiliyor…';
      status.textContent = ''; status.style.color = '#94a3b8';
      try {
        var data = await apiFetch('/api/platform/feedback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: message })
        });
        status.textContent = '✓ Gönderildi! Teşekkürler.'; status.style.color = '#4ade80';
        btn.textContent = '✓ Gönderildi'; btn.disabled = true;
        setTimeout(function() { window._closeFeedback(); btn.textContent = 'Gönder →'; btn.disabled = false; }, 2000);
      } catch(e) {
        console.error('Feedback error:', e);
        status.textContent = 'Hata: ' + e.message; status.style.color = '#f87171';
        btn.disabled = false; btn.textContent = 'Gönder →';
      }
    };

    // Close on backdrop click
    modal.addEventListener('click', function(e) { if (e.target === modal) window._closeFeedback(); });
  })();

  // ── Macro ticker: TCMB policy rate + live USD/EUR ──────────────────────────
  async function loadMacroTicker(forceRefresh) {
    try {
      const d = await apiFetch('/api/bi/market/rates' + (forceRefresh ? '?refresh=1' : ''));
      if (!d) return;
      const tcmb = container.querySelector('#vmt-tcmb');
      const usd  = container.querySelector('#vmt-usd');
      const eur  = container.querySelector('#vmt-eur');
      const dt   = container.querySelector('#vmt-date');
      if (tcmb) tcmb.textContent = d.tcmb_faiz != null ? '%' + d.tcmb_faiz : '—';
      if (usd)  usd.textContent  = d.usd_try   != null ? '\u20ba' + parseFloat(d.usd_try).toFixed(2) : '—';
      if (eur)  eur.textContent  = d.eur_try   != null ? '\u20ba' + parseFloat(d.eur_try).toFixed(2) : '—';
      if (dt) {
        const src   = d.kaynak === 'TCMB-LIVE' ? 'canlı' : 'kayıtlı';
        const tarih = d.gecerli_tarih
          ? new Date(d.gecerli_tarih + 'T12:00:00').toLocaleDateString('tr-TR', { day:'numeric', month:'short' })
          : '';
        dt.textContent = tarih ? '· ' + tarih + ' (' + src + ')' : '';
      }
    } catch(e) { /* silent */ }
  }
  loadMacroTicker(true);
  setInterval(() => loadMacroTicker(true), 30000);

  OFFICERS.forEach(o => {
    const form = container.querySelector(`#vmo-form-${o.id}`);
    if (!form) return;
    form.addEventListener("submit", e => {
      e.preventDefault();
      const inp = form.querySelector(".vmo-chat-input");
      const msg = inp.value.trim();
      if (!msg) return;
      inp.value = "";
      sendChat(o.id, msg);
    });
  });

  // Order Management tab clicks
  container.addEventListener("click", e => {

    // Section tabs (Kış / Yaz / Günlük)
    const secBtn = e.target.closest(".vmo-stab-section");
    if (secBtn) {
      ordersSection = secBtn.dataset.section;
      // Never change activeDept for sub-sections like size-opp
      container.querySelectorAll(".vmo-stab-section").forEach(t => t.classList.remove("active"));
      secBtn.classList.add("active");
      if (ordersSection === 'size-opp') { loadSizeOpportunities(); } else if (ordersSection === 'season-price') { loadSeasonPriceCompare(); } else { loadOrderResults(); }
      return;
    }

    // Segment tabs (all / binek / ticari / mevsimsel)
    const segBtn = e.target.closest(".vmo-stab-seg");
    if (segBtn) {
      ordersSegment = segBtn.dataset.seg;
      container.querySelectorAll(".vmo-stab-seg").forEach(t => t.classList.remove("active"));
      segBtn.classList.add("active");
      if (ordersSection === 'size-opp') { loadSizeOpportunities(); } else if (ordersSection === 'season-price') { loadSeasonPriceCompare(); } else { loadOrderResults(); }
      return;
    }

    // Mode tabs (priority / budget)
    const modeBtn = e.target.closest(".vmo-stab-mode");
    if (modeBtn) {
      ordersMode = modeBtn.dataset.mode;
      container.querySelectorAll(".vmo-stab-mode").forEach(t => t.classList.remove("active"));
      modeBtn.classList.add("active");
      const budgetInp = container.querySelector("#vmo-budget-input");
      if (budgetInp) budgetInp.style.display = ordersMode === "budget" ? "flex" : "none";
      loadOrderResults();
      return;
    }

    // Budget apply button
    if (e.target.closest(".vmo-budget-apply")) {
      const val = parseInt(container.querySelector("#vmo-budget-val")?.value || "500000", 10);
      ordersBudget = isNaN(val) ? 500000 : val;
      loadOrderResults();
      return;
    }

    // Quick prompt buttons
    const btn = e.target.closest(".vmo-qbtn");
    if (btn) sendChat(btn.dataset.dept, btn.dataset.prompt);
  });

  // ── Orders search / filter ─────────────────────────────────────────────────
  function filterOrders() {
    const inp = document.querySelector('#vmo-search-input');
    const q   = (inp ? inp.value : '').trim().toLowerCase();
    const clearBtn = document.querySelector('#vmo-search-clear');
    if (clearBtn) clearBtn.style.display = q ? 'inline' : 'none';
    // Search rendered cell text — works regardless of API field names
    const tbody = document.querySelector('#vmo-orders-tbody');
    if (!tbody) return;
    const rows = tbody.querySelectorAll('tr');
    rows.forEach(function(tr) {
      if (!q) { tr.style.display = ''; return; }
      tr.style.display = tr.textContent.toLowerCase().includes(q) ? '' : 'none';
    });
  }
  // Expose so oninput attribute can call it directly
  window.__vmoFilter = filterOrders;

  // Clear button via delegation
  container.addEventListener('click', e => {
    if (e.target.id === 'vmo-search-clear') {
      const inp = container.querySelector('#vmo-search-input');
      if (inp) { inp.value = ''; filterOrders(); }
    }
  });

  // ── Boot ──────────────────────────────────────────────────────────────────
  loadBriefing();
  loadDeptData(activeDept);

  // Search box — document-level fallback (fires even if oninput above is blocked)
  document.addEventListener('input', function __vmoSearchDoc(e) {
    if (e.target.id !== 'vmo-search-input') return;
    var q  = e.target.value.trim().toLowerCase();
    var cb = document.getElementById('vmo-search-clear');
    if (cb) cb.style.display = q ? 'inline' : 'none';
    var tb = document.getElementById('vmo-orders-tbody') || document.querySelector('#vmo-orders-results tbody');
    if (!tb) return;
    [].forEach.call(tb.querySelectorAll('tr'), function(r) {
      r.style.display = !q || r.textContent.toLowerCase().indexOf(q) >= 0 ? '' : 'none';
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Data loading
  // ═════════════════════════════════════════════════════════════════════════


  // ══════════════════════════════════════════════════════════════════════════════
  // FINANCIAL INTELLIGENCE LAYER  (injected into bi.js before loadBriefing)
  // ══════════════════════════════════════════════════════════════════════════════

  // ── Ebat Fırsatları  (Orders room > 📐 Ebat Fırsatları tab) ────────────────
  
  async function loadSeasonPriceCompare() {
    const resultsEl = container.querySelector('#vmo-orders-results');
    if (!resultsEl) return;
    let _mode = 'sale';
    let _selBrand = '';
    let _expBrand  = '';   // compare mode: which brand row is expanded
    let _sortCol = 'marka';
    let _sortAsc = true;
    let _minFark = 0;

    async function fetchAndRender() {
      resultsEl.innerHTML = '<div class="vmo-kpi-loading">Fiyat verileri yükleniyor…</div>';
      try {
        const data = await apiFetch('/api/bi/pricing/season-compare?mode=' + _mode);
        const years = (data.years || []).map(Number).sort(function(a,b){ return a-b; });
        const yKeys = years.map(String);

        // ── COMPARE MODE ──────────────────────────────────────────
        if (_mode === 'compare') {
          const rows = data.rows || [];
          if (!rows.length) {
            resultsEl.innerHTML = '<div class="vmo-kpi-empty">Karşılaştırılabilir maliyet+satış verisi bulunamadı.</div>';
            return;
          }
          // brandMap[marka][yKey] = { spSum, spW }
          // sizeMap[marka][ebat][yKey] = { mf, sf, sp, vol }
          const brandMap = {};
          const sizeMap  = {};
          rows.forEach(function(r) {
            const marka = r.marka, ebat = r.ebat;
            const mf = parseFloat(r.maliyet_fark), sf = parseFloat(r.satis_fark), sp = parseFloat(r.spread);
            if (!marka || !ebat || isNaN(sp)) return;
            const yKey = String(r.yil);
            const vol  = ((+r.yaz_adet_s || 0) + (+r.kis_adet_s || 0)) || 1;
            if (!brandMap[marka]) brandMap[marka] = {};
            if (!brandMap[marka][yKey]) brandMap[marka][yKey] = { spSum: 0, spW: 0 };
            brandMap[marka][yKey].spSum += sp * vol;
            brandMap[marka][yKey].spW   += vol;
            if (!sizeMap[marka]) sizeMap[marka] = {};
            if (!sizeMap[marka][ebat]) sizeMap[marka][ebat] = {};
            sizeMap[marka][ebat][yKey] = { mf: mf, sf: sf, sp: sp, vol: vol };
          });

          const allBrands = Object.keys(brandMap);

          function bsp(marka, yk) {
            const d = brandMap[marka] && brandMap[marka][yk];
            return d && d.spW ? d.spSum / d.spW : null;
          }
          function avgSp(marka) {
            const vals = yKeys.map(function(yk){ return bsp(marka, yk); }).filter(function(v){ return v !== null; });
            return vals.length ? vals.reduce(function(a,b){ return a+b; }, 0) / vals.length : null;
          }
          function spTrend(marka) {
            const vals = yKeys.map(function(yk){ return bsp(marka, yk); }).filter(function(v){ return v !== null; });
            if (vals.length < 2) return '';
            const delta = vals[vals.length-1] - vals[0];
            return delta > 1 ? '↑' : delta < -1 ? '↓' : '→';
          }

          function renderCompare() {
            const fmtPct  = function(v) { return (v === null || isNaN(v)) ? '—' : (v >= 0 ? '+' : '') + v.toFixed(1) + '%'; };
            const spColor = function(v) { return (v === null || isNaN(v)) ? 'var(--text-muted,#888)' : v > 1 ? '#22c55e' : v < -1 ? '#ef4444' : 'var(--text,#e0e0e0)'; };
            const thS  = 'cursor:pointer;padding:7px 8px;text-align:right;border-bottom:1px solid var(--border,#333);font-size:11px;color:var(--text-muted,#999);white-space:nowrap;user-select:none;';
            const thSL = 'cursor:pointer;padding:7px 8px;text-align:left;border-bottom:1px solid var(--border,#333);font-size:11px;color:var(--text-muted,#999);white-space:nowrap;user-select:none;';
            const thArr = function(col) { return _sortCol === col ? (_sortAsc ? ' ▲' : ' ▼') : ''; };
            const btnS  = function(active) {
              return 'padding:5px 14px;border-radius:20px;cursor:pointer;font-size:12px;transition:all .15s;border:1px solid var(--accent,#3b82f6);'
                + (active ? 'background:var(--accent,#3b82f6);color:#fff;' : 'background:transparent;color:var(--text,#e0e0e0);');
            };

            let html = '<div style="display:flex;gap:8px;margin-bottom:12px;align-items:center;flex-wrap:wrap;">'
              + '<span style="font-size:12px;color:var(--text-muted,#999);">Fiyat Türü:</span>'
              + '<button id="vmo-sp-m-sale" style="' + btnS(false) + '">📈 Satış Fiyatı</button>'
              + '<button id="vmo-sp-m-cost" style="' + btnS(false) + '">💰 Maliyet Fiyatı</button>'
              + '<button id="vmo-sp-m-cmp"  style="' + btnS(true)  + '">🔀 Karşılaştırma</button>'
              + '</div>';

            html += '<div style="display:flex;gap:16px;margin-bottom:12px;font-size:11px;color:var(--text-muted,#888);flex-wrap:wrap;">'
              + '<span>Spread = Satış Fark% − Maliyet Fark%</span>'
              + '<span style="color:#22c55e;">● Pozitif: satışta fazladan kazanç var</span>'
              + '<span style="color:#ef4444;">● Negatif: maliyet baskısı emilmekte</span>'
              + '</div>';

            html += '<div style="display:flex;gap:10px;margin-bottom:12px;align-items:center;flex-wrap:wrap;">'
              + '<label style="font-size:12px;color:var(--text-muted,#999);">Min |Spread|:</label>'
              + '<input id="vmo-sp-minfark" type="number" min="0" max="100" value="' + _minFark + '" step="1" '
              + 'style="width:56px;padding:3px 6px;border-radius:4px;border:1px solid var(--border,#333);background:var(--bg2,#1e1e1e);color:var(--text,#e0e0e0);font-size:12px;"> %'
              + '<button id="vmo-sp-ai-btn" style="margin-left:auto;padding:5px 14px;border-radius:4px;border:none;background:var(--accent,#3b82f6);color:#fff;font-size:12px;cursor:pointer;">🤖 AI Analizi</button>'
              + '<button id="vmo-sp-xl-btn" style="padding:5px 14px;border-radius:4px;border:none;background:#27ae60;color:#fff;font-size:12px;cursor:pointer;">⬇️ Excel</button>'
              + '</div>';

            // Filter brands
            let shownBrands = allBrands.filter(function(m) {
              return yKeys.some(function(yk) { const v = bsp(m, yk); return v !== null && Math.abs(v) >= _minFark; });
            });

            // Sort
            shownBrands.sort(function(a, b) {
              if (_sortCol === 'marka') return _sortAsc ? a.localeCompare(b) : b.localeCompare(a);
              if (_sortCol === 'trend') { const ta = spTrend(a), tb = spTrend(b); return _sortAsc ? ta.localeCompare(tb) : tb.localeCompare(ta); }
              if (_sortCol === 'avg')   { const va = avgSp(a) || 0, vb = avgSp(b) || 0; return _sortAsc ? va - vb : vb - va; }
              const va = bsp(a, _sortCol) || 0, vb = bsp(b, _sortCol) || 0;
              return _sortAsc ? va - vb : vb - va;
            });

            // Brand table
            const colSpan = yKeys.length + 3;
            html += '<div style="overflow-x:auto;">';
            html += '<table id="vmo-sp-tbl" style="width:100%;border-collapse:collapse;font-size:12px;min-width:500px;">';
            html += '<thead><tr>';
            html += '<th data-col="marka" style="' + thSL + '">Marka' + thArr('marka') + '</th>';
            yKeys.forEach(function(yk, i) {
              html += '<th data-col="' + yk + '" style="' + thS + '">' + years[i] + ' Spread' + thArr(yk) + '</th>';
            });
            html += '<th data-col="trend" style="' + thS + '">Trend' + thArr('trend') + '</th>';
            html += '<th data-col="avg"   style="' + thS + '">Ort. Spread' + thArr('avg') + '</th>';
            html += '</tr></thead><tbody>';

            shownBrands.forEach(function(marka) {
              const isExp = marka === _expBrand;
              const tr    = spTrend(marka);
              const trCol = tr === '↑' ? '#22c55e' : tr === '↓' ? '#ef4444' : 'var(--text-muted,#888)';
              const rowBg = isExp ? 'background:var(--bg-hover,#1e293b);' : '';
              const av    = avgSp(marka);

              html += '<tr class="vmo-sp-brow" data-brand="' + marka + '" style="cursor:pointer;border-bottom:1px solid var(--border-light,#2a2a2a);' + rowBg + '">';
              html += '<td style="padding:6px 8px;font-weight:500;">' + (isExp ? '▾ ' : '▸ ') + marka + '</td>';
              yKeys.forEach(function(yk) {
                const v = bsp(marka, yk);
                html += '<td style="padding:6px 8px;text-align:right;color:' + spColor(v) + ';font-weight:' + (v !== null ? '600' : '400') + ';">' + fmtPct(v) + '</td>';
              });
              html += '<td style="padding:6px 8px;text-align:right;color:' + trCol + ';font-weight:600;font-size:14px;">' + (tr || '—') + '</td>';
              html += '<td style="padding:6px 8px;text-align:right;color:' + spColor(av) + ';font-weight:700;">' + fmtPct(av) + '</td>';
              html += '</tr>';

              // ── Inline expand: ebat detail sorted worst → best avg spread ──
              if (isExp) {
                const sizes = Object.keys(sizeMap[marka] || {});
                const sizeAvg = sizes.map(function(ebat) {
                  const vals = yKeys.map(function(yk) {
                    const d = sizeMap[marka][ebat][yk];
                    return d ? d.sp : null;
                  }).filter(function(v){ return v !== null; });
                  return { ebat: ebat, avg: vals.length ? vals.reduce(function(a,b){return a+b;},0)/vals.length : null };
                }).filter(function(s){ return s.avg !== null; });
                sizeAvg.sort(function(a,b){ return a.avg - b.avg; }); // worst first

                html += '<tr><td colspan="' + colSpan + '" style="padding:0;">';
                html += '<div style="overflow-x:auto;border-top:2px solid var(--accent,#3b82f6);border-bottom:2px solid var(--border,#333);">';
                html += '<table style="width:100%;border-collapse:collapse;font-size:11px;background:var(--bg,#0d0d0d);">';
                html += '<thead>';
                html += '<tr style="background:var(--bg2,#1a1a1a);">';
                html += '<th style="padding:5px 10px;text-align:left;font-family:monospace;color:var(--text-muted,#777);border-bottom:1px solid var(--border,#333);font-size:10px;">EBAT</th>';
                yKeys.forEach(function(yk, i) {
                  html += '<th style="padding:5px 8px;text-align:center;color:var(--text-muted,#777);border-bottom:1px solid var(--border,#333);min-width:100px;font-size:10px;">' + years[i] + '</th>';
                });
                html += '<th style="padding:5px 8px;text-align:right;color:var(--text-muted,#777);border-bottom:1px solid var(--border,#333);font-size:10px;">ORT. SPREAD</th>';
                html += '</tr>';
                html += '<tr style="background:var(--bg3,#111);">';
                html += '<td style="padding:2px 10px;font-size:9px;color:var(--text-muted,#555);">sıralama: en kötü → en iyi</td>';
                yKeys.forEach(function() {
                  html += '<td style="padding:2px 8px;text-align:center;font-size:9px;color:var(--text-muted,#555);">Maliyet% · Satış% · Spread</td>';
                });
                html += '<td></td></tr>';
                html += '</thead><tbody>';

                sizeAvg.forEach(function(s, idx) {
                  const ebat = s.ebat;
                  const rowStripe = idx % 2 === 0 ? '' : 'background:var(--bg2,#111);';
                  html += '<tr style="border-bottom:1px solid var(--border-light,#1a1a1a);' + rowStripe + '">';
                  html += '<td style="padding:6px 10px;font-family:monospace;font-size:10px;color:var(--text,#ccc);">' + ebat + '</td>';
                  yKeys.forEach(function(yk) {
                    const d = sizeMap[marka][ebat] && sizeMap[marka][ebat][yk];
                    if (!d) {
                      html += '<td style="padding:6px 8px;text-align:center;color:var(--text-muted,#444);">—</td>';
                      return;
                    }
                    const volTip = d.vol ? '<div style="font-size:9px;color:var(--text-muted,#555);margin-top:1px;">' + d.vol + 'u</div>' : '';
                    html += '<td style="padding:5px 6px;text-align:center;">'
                      + '<div style="font-size:10px;color:var(--text-muted,#777);">M:' + fmtPct(d.mf) + '</div>'
                      + '<div style="font-size:10px;color:var(--text-muted,#888);">S:' + fmtPct(d.sf) + '</div>'
                      + '<div style="font-size:12px;font-weight:700;color:' + spColor(d.sp) + ';">' + fmtPct(d.sp) + '</div>'
                      + volTip
                      + '</td>';
                  });
                  html += '<td style="padding:6px 10px;text-align:right;font-weight:700;font-size:12px;color:' + spColor(s.avg) + ';">' + fmtPct(s.avg) + '</td>';
                  html += '</tr>';
                });

                if (!sizeAvg.length) {
                  html += '<tr><td colspan="' + colSpan + '" style="padding:10px;text-align:center;color:var(--text-muted,#555);">Bu marka için eşleşen ebat verisi yok.</td></tr>';
                }

                html += '</tbody></table></div></td></tr>';
              }
            });

            html += '</tbody></table></div>';
            html += '<div id="vmo-sp-ai-out" style="margin-top:16px;"></div>';
            resultsEl.innerHTML = html;

            // Wire mode buttons
            resultsEl.querySelector('#vmo-sp-m-sale').addEventListener('click', function() { _mode = 'sale'; fetchAndRender(); });
            resultsEl.querySelector('#vmo-sp-m-cost').addEventListener('click', function() { _mode = 'cost'; fetchAndRender(); });
            resultsEl.querySelector('#vmo-sp-m-cmp' ).addEventListener('click', function() { /* already active */ });

            // Sort headers
            resultsEl.querySelector('#vmo-sp-tbl').querySelectorAll('th[data-col]').forEach(function(th) {
              th.addEventListener('click', function() {
                const col = th.dataset.col;
                if (_sortCol === col) _sortAsc = !_sortAsc; else { _sortCol = col; _sortAsc = col === 'marka'; }
                renderCompare();
              });
            });

            // Min filter
            resultsEl.querySelector('#vmo-sp-minfark').addEventListener('input', function(e) {
              _minFark = parseFloat(e.target.value) || 0;
              renderCompare();
            });

            // Brand row click → inline expand/collapse
            resultsEl.querySelectorAll('.vmo-sp-brow').forEach(function(row) {
              row.addEventListener('click', function() {
                _expBrand = (row.dataset.brand === _expBrand) ? '' : row.dataset.brand;
                renderCompare();
              });
            });

            // Excel export
            resultsEl.querySelector('#vmo-sp-xl-btn').addEventListener('click', function() {
              let tsv = ['Marka','Ebat','Yıl','Maliyet Fark%','Satış Fark%','Spread%','Satış Hacmi'].join('\t') + '\n';
              rows.forEach(function(r) {
                tsv += [r.marka, r.ebat, r.yil, r.maliyet_fark, r.satis_fark, r.spread,
                  ((+r.yaz_adet_s||0)+(+r.kis_adet_s||0))].join('\t') + '\n';
              });
              const a = document.createElement('a');
              a.href = URL.createObjectURL(new Blob([tsv], { type: 'text/tab-separated-values' }));
              a.download = 'yaz_kis_karsilastirma.tsv'; a.click();
            });

            // AI analysis
            resultsEl.querySelector('#vmo-sp-ai-btn').addEventListener('click', async function() {
              const aiOut = resultsEl.querySelector('#vmo-sp-ai-out');
              aiOut.innerHTML = '<div class="vmo-kpi-loading">AI analizi yapılıyor…</div>';
              try {
                const top = shownBrands.slice(0, 6).map(function(marka) {
                  const yearStr = yKeys.map(function(yk, i) {
                    const v = bsp(marka, yk);
                    return v !== null ? years[i] + ':' + fmtPct(v) : null;
                  }).filter(Boolean).join(', ');
                  return marka + ' [' + yearStr + '] trend:' + spTrend(marka);
                }).join(' | ');
                const prompt = 'KRB lastik firması — kış/yaz maliyet-satış spread analizi. '
                  + 'Spread = satış fark% − maliyet fark%. Pozitif spread iyidir (satışta fazladan kazanç var). Negatif spread kötüdür (tedarik maliyeti emiliyor, kar marjı baskı altında). '
                  + 'Markalar ve yıllık spread verileri: ' + top + '. '
                  + 'Hangi markalarda ciddi marj baskısı var? Hangileri giderek kötüleşiyor? Fiyat politikasında ne yapılmalı? Türkçe 4-5 cümle, doğrudan ve net.';
                const resp = await apiFetch('/api/brain/ask', { method: 'POST', body: JSON.stringify({ message: prompt }) });
                aiOut.innerHTML = '<div style="background:var(--bg2,#1e1e1e);border-left:3px solid var(--accent,#3b82f6);padding:12px 16px;border-radius:4px;font-size:13px;line-height:1.6;">'
                  + '🤖 ' + (resp && (resp.reply || resp.message) || 'Yanıt alınamadı.') + '</div>';
              } catch(e2) {
                resultsEl.querySelector('#vmo-sp-ai-out').innerHTML = '<div class="vmo-kpi-err">AI analizi başarısız: ' + e2.message + '</div>';
              }
            });
          }

          renderCompare();
          return;
        }

        // ── SALE / COST MODE ──────────────────────────────────────
        const isCost    = _mode === 'cost';
        const modeLabel = isCost ? 'Maliyet Fiyatı' : 'Satış Fiyatı';
        const srcNote   = isCost ? '📦 Tedarikçi alış maliyeti (fatura verisi — tüm yıllar)'
                                 : '🛒 Müşteriye satış fiyatı — tüm yıllar fatura verisi';

        if (!data || !Array.isArray(data.brands) || !data.brands.length) {
          resultsEl.innerHTML = '<div class="vmo-kpi-empty">Karşılaştırılabilir yaz+kış verisi bulunamadı.</div>';
          return;
        }

        const brandMap = {};
        const sizeMap  = {};

        data.brands.forEach(function(row) {
          const marka = row.marka, ebat = row.ebat;
          const yf = parseFloat(row.yaz_fiyat), kf = parseFloat(row.kis_fiyat);
          if (!marka || !ebat || !yf || !kf) return;
          const fark = (kf - yf) / yf * 100;
          const w    = ((row.yaz_adet || 0) + (row.kis_adet || 0)) || 1;
          const yKey = row.yil != null ? String(row.yil) : 'all';
          if (!brandMap[marka]) brandMap[marka] = {};
          if (!brandMap[marka][yKey]) brandMap[marka][yKey] = { farkSum: 0, farkW: 0 };
          brandMap[marka][yKey].farkSum += fark * w;
          brandMap[marka][yKey].farkW   += w;
          if (!sizeMap[marka]) sizeMap[marka] = {};
          if (!sizeMap[marka][ebat]) sizeMap[marka][ebat] = {};
          if (!sizeMap[marka][ebat][yKey]) sizeMap[marka][ebat][yKey] = { fark: 0, yf: 0, kf: 0, ya: 0, ka: 0, cnt: 0 };
          const se = sizeMap[marka][ebat][yKey];
          se.fark = (se.fark * se.cnt + fark) / (se.cnt + 1);
          se.yf   = (se.yf   * se.cnt + yf)   / (se.cnt + 1);
          se.kf   = (se.kf   * se.cnt + kf)   / (se.cnt + 1);
          se.ya  += (row.yaz_adet || 0);
          se.ka  += (row.kis_adet || 0);
          se.cnt++;
        });

        const allBrands = Object.keys(brandMap);
        if (!_selBrand || !brandMap[_selBrand]) _selBrand = allBrands[0] || '';

        function bfark(marka, yKey) {
          const d = brandMap[marka] && brandMap[marka][yKey];
          return d && d.farkW ? d.farkSum / d.farkW : null;
        }
        function trend(marka) {
          if (!years.length) return '';
          const vals = years.map(function(y){ return bfark(marka, String(y)); }).filter(function(v){ return v !== null; });
          if (vals.length < 2) return '';
          const delta = vals[vals.length-1] - vals[0];
          return delta > 1.5 ? '↑' : delta < -1.5 ? '↓' : '→';
        }

        function renderAll() {
          const yLabels = years.length ? years : [isCost ? 'Mevcut' : 'Tümü'];
          const fmtPct  = function(v) { return v === null ? '—' : (v >= 0 ? '+' : '') + v.toFixed(1) + '%'; };
          const fColor  = function(v) { return v === null ? 'var(--text-muted,#888)' : v > 2 ? '#ef4444' : v < -2 ? '#22c55e' : 'var(--text,#e0e0e0)'; };
          const thS     = 'cursor:pointer;padding:7px 8px;text-align:right;border-bottom:1px solid var(--border,#333);font-size:11px;color:var(--text-muted,#999);white-space:nowrap;user-select:none;';
          const thSL    = 'cursor:pointer;padding:7px 8px;text-align:left;border-bottom:1px solid var(--border,#333);font-size:11px;color:var(--text-muted,#999);white-space:nowrap;user-select:none;';
          const thArr   = function(col) { return _sortCol === col ? (_sortAsc ? ' ▲' : ' ▼') : ''; };
          const btnS    = function(active) {
            return 'padding:5px 14px;border-radius:20px;cursor:pointer;font-size:12px;transition:all .15s;border:1px solid var(--accent,#3b82f6);'
              + (active ? 'background:var(--accent,#3b82f6);color:#fff;' : 'background:transparent;color:var(--text,#e0e0e0);');
          };

          let html = '<div style="display:flex;gap:8px;margin-bottom:12px;align-items:center;flex-wrap:wrap;">'
            + '<span style="font-size:12px;color:var(--text-muted,#999);">Fiyat Türü:</span>'
            + '<button id="vmo-sp-m-sale" style="' + btnS(!isCost) + '">📈 Satış Fiyatı</button>'
            + '<button id="vmo-sp-m-cost" style="' + btnS(isCost)  + '">💰 Maliyet Fiyatı</button>'
            + '<button id="vmo-sp-m-cmp"  style="' + btnS(false)   + '">🔀 Karşılaştırma</button>'
            + '<span style="font-size:11px;color:var(--text-muted,#888);margin-left:4px;">' + srcNote + '</span>'
            + '</div>';

          html += '<div style="display:flex;gap:10px;margin-bottom:12px;align-items:center;flex-wrap:wrap;">'
            + '<label style="font-size:12px;color:var(--text-muted,#999);">Min Ort. Fark:</label>'
            + '<input id="vmo-sp-minfark" type="number" min="0" max="100" value="' + _minFark + '" step="1" '
            + 'style="width:56px;padding:3px 6px;border-radius:4px;border:1px solid var(--border,#333);background:var(--bg2,#1e1e1e);color:var(--text,#e0e0e0);font-size:12px;"> %'
            + '<span style="font-size:11px;color:var(--text-muted,#777);">(herhangi bir yılda)</span>'
            + '<button id="vmo-sp-ai-btn" style="margin-left:auto;padding:5px 14px;border-radius:4px;border:none;background:var(--accent,#3b82f6);color:#fff;font-size:12px;cursor:pointer;">🤖 AI Analizi</button>'
            + '<button id="vmo-sp-xl-btn" style="padding:5px 14px;border-radius:4px;border:none;background:#27ae60;color:#fff;font-size:12px;cursor:pointer;">⬇️ Excel</button>'
            + '</div>';

          let shownBrands = allBrands.filter(function(marka) {
            return yKeys.some(function(yk) { const v = bfark(marka, yk); return v !== null && Math.abs(v) >= _minFark; });
          });

          shownBrands.sort(function(a, b) {
            if (_sortCol === 'marka') return _sortAsc ? a.localeCompare(b) : b.localeCompare(a);
            if (_sortCol === 'trend') { const ta = trend(a), tb = trend(b); return _sortAsc ? ta.localeCompare(tb) : tb.localeCompare(ta); }
            if (_sortCol === 'cnt')   { const ca = Object.keys(sizeMap[a]||{}).length, cb = Object.keys(sizeMap[b]||{}).length; return _sortAsc ? ca-cb : cb-ca; }
            const va = bfark(a, _sortCol) || 0, vb = bfark(b, _sortCol) || 0;
            return _sortAsc ? va - vb : vb - va;
          });

          html += '<div style="overflow-x:auto;">';
          html += '<table id="vmo-sp-tbl" style="width:100%;border-collapse:collapse;font-size:12px;min-width:500px;">';
          html += '<thead><tr>';
          html += '<th data-col="marka" style="' + thSL + 'text-align:left;">Marka' + thArr('marka') + '</th>';
          yKeys.forEach(function(yk, i) { html += '<th data-col="' + yk + '" style="' + thS + '">' + yLabels[i] + thArr(yk) + '</th>'; });
          html += '<th data-col="trend" style="' + thS + '">Trend' + thArr('trend') + '</th>';
          html += '<th data-col="cnt"   style="' + thS + '"># Ebat' + thArr('cnt') + '</th>';
          html += '</tr></thead><tbody>';

          shownBrands.forEach(function(marka) {
            const sel  = marka === _selBrand ? 'background:var(--bg-hover,#252525);' : '';
            const tr   = trend(marka);
            const trC  = tr === '↑' ? '#ef4444' : tr === '↓' ? '#22c55e' : 'var(--text-muted,#888)';
            const ebatCnt = Object.keys(sizeMap[marka] || {}).length;
            html += '<tr class="vmo-sp-brow" data-brand="' + marka + '" style="cursor:pointer;border-bottom:1px solid var(--border-light,#2a2a2a);' + sel + '">';
            html += '<td style="padding:6px 8px;font-weight:500;">' + marka + '</td>';
            yKeys.forEach(function(yk) {
              const v = bfark(marka, yk);
              html += '<td style="padding:6px 8px;text-align:right;color:' + fColor(v) + ';font-weight:' + (v !== null ? '600' : '400') + ';">' + fmtPct(v) + '</td>';
            });
            html += '<td style="padding:6px 8px;text-align:right;color:' + trC + ';font-weight:600;font-size:14px;">' + (tr || '—') + '</td>';
            html += '<td style="padding:6px 8px;text-align:right;color:var(--text-muted,#999);">' + ebatCnt + '</td>';
            html += '</tr>';
          });
          html += '</tbody></table></div>';

          const selOpts = shownBrands.map(function(m) {
            return '<option value="' + m + '"' + (m === _selBrand ? ' selected' : '') + '>' + m + '</option>';
          }).join('');
          html += '<div style="margin-top:20px;display:flex;align-items:center;gap:10px;flex-wrap:wrap;">'
            + '<select id="vmo-sp-sel" style="padding:6px 10px;border-radius:4px;border:1px solid var(--border,#333);background:var(--bg2,#1e1e1e);color:var(--text,#e0e0e0);font-size:13px;">' + selOpts + '</select>'
            + '<span style="font-size:12px;color:var(--text-muted,#999);">Kış/Yaz % fark — ebat & yıl bazında</span>'
            + '</div>';

          const selSizes = _selBrand ? Object.keys(sizeMap[_selBrand] || {}).sort() : [];
          if (selSizes.length) {
            html += '<div style="overflow-x:auto;margin-top:10px;">';
            html += '<table id="vmo-sp-dtbl" style="width:100%;border-collapse:collapse;font-size:12px;min-width:400px;">';
            html += '<thead><tr><th style="' + thSL + 'text-align:left;font-family:monospace;">Ebat</th>';
            yKeys.forEach(function(yk, i) { html += '<th style="' + thS + '">' + yLabels[i] + '</th>'; });
            html += '</tr></thead><tbody>';
            selSizes.forEach(function(ebat) {
              html += '<tr style="border-bottom:1px solid var(--border-light,#2a2a2a);">';
              html += '<td style="padding:5px 8px;font-family:monospace;font-size:11px;">' + ebat + '</td>';
              yKeys.forEach(function(yk) {
                const d = sizeMap[_selBrand][ebat][yk];
                const v = d ? d.fark : null;
                const units = d ? (d.ya + d.ka) : 0;
                const unitTip = units ? '<div style="font-size:10px;color:var(--text-muted,#777);font-weight:400;">' + units + 'u</div>' : '';
                html += '<td style="padding:5px 8px;text-align:right;color:' + fColor(v) + ';font-weight:' + (v !== null ? '600' : '400') + ';">' + fmtPct(v) + unitTip + '</td>';
              });
              html += '</tr>';
            });
            html += '</tbody></table></div>';
          }

          html += '<div id="vmo-sp-ai-out" style="margin-top:16px;"></div>';
          resultsEl.innerHTML = html;

          // Wire mode buttons
          resultsEl.querySelector('#vmo-sp-m-sale').addEventListener('click', function() { if (isCost) { _mode='sale'; fetchAndRender(); } });
          resultsEl.querySelector('#vmo-sp-m-cost').addEventListener('click', function() { if (!isCost) { _mode='cost'; fetchAndRender(); } });
          resultsEl.querySelector('#vmo-sp-m-cmp' ).addEventListener('click', function() { _mode='compare'; fetchAndRender(); });

          // Sort
          resultsEl.querySelector('#vmo-sp-tbl').querySelectorAll('th[data-col]').forEach(function(th) {
            th.addEventListener('click', function() {
              const col = th.dataset.col;
              if (_sortCol === col) _sortAsc = !_sortAsc; else { _sortCol = col; _sortAsc = col === 'marka'; }
              renderAll();
            });
          });

          // Min fark
          resultsEl.querySelector('#vmo-sp-minfark').addEventListener('input', function(e) {
            _minFark = parseFloat(e.target.value) || 0; renderAll();
          });

          // Brand row click
          resultsEl.querySelectorAll('.vmo-sp-brow').forEach(function(row) {
            row.addEventListener('click', function() { _selBrand = row.dataset.brand; renderAll(); });
          });

          // Brand combobox
          resultsEl.querySelector('#vmo-sp-sel').addEventListener('change', function(e) {
            _selBrand = e.target.value; renderAll();
          });

          // Excel export
          resultsEl.querySelector('#vmo-sp-xl-btn').addEventListener('click', function() {
            let tsv = ['Marka','Ebat'].concat(yLabels.map(String)).concat(['Trend']).join('\t') + '\n';
            allBrands.forEach(function(marka) {
              Object.keys(sizeMap[marka] || {}).sort().forEach(function(ebat) {
                const vals = yKeys.map(function(yk) { const d = sizeMap[marka][ebat][yk]; return d ? d.fark.toFixed(1)+'%' : ''; });
                tsv += [marka, ebat].concat(vals).concat([trend(marka)]).join('\t') + '\n';
              });
            });
            const a = document.createElement('a');
            a.href = URL.createObjectURL(new Blob([tsv], { type: 'text/tab-separated-values' }));
            a.download = 'yaz_kis_yillik_' + _mode + '.tsv'; a.click();
          });

          // AI analysis
          resultsEl.querySelector('#vmo-sp-ai-btn').addEventListener('click', async function() {
            const aiOut = resultsEl.querySelector('#vmo-sp-ai-out');
            aiOut.innerHTML = '<div class="vmo-kpi-loading">AI analizi yapılıyor…</div>';
            try {
              const top = shownBrands.slice(0, 6).map(function(marka) {
                const yearStr = yKeys.map(function(yk, i) {
                  const v = bfark(marka, yk);
                  return v !== null ? yLabels[i] + ':' + (v>=0?'+':'') + v.toFixed(1) + '%' : null;
                }).filter(Boolean).join(', ');
                return marka + ' [' + yearStr + '] trend:' + trend(marka);
              }).join(' | ');
              const prompt = 'KRB lastik firması — kış lastiği ' + modeLabel + ' / yaz lastiği fark analizi, yıl bazında. '
                + 'Markalar ve yıllık kış/yaz fark yüzdeleri: ' + top + '. '
                + 'Hangi markalar kış lastiklerini yıllar içinde giderek pahalandırıyor veya ucuzlatıyor? '
                + 'KRB bu trendlere karşı nasıl konumlanmalı? Kısa ve net, Türkçe 4-5 cümle.';
              const resp = await apiFetch('/api/brain/ask', { method: 'POST', body: JSON.stringify({ message: prompt }) });
              aiOut.innerHTML = '<div style="background:var(--bg2,#1e1e1e);border-left:3px solid var(--accent,#3b82f6);padding:12px 16px;border-radius:4px;font-size:13px;line-height:1.6;">'
                + '🤖 ' + (resp && (resp.reply || resp.message) || 'Yanıt alınamadı.') + '</div>';
            } catch(e2) {
              resultsEl.querySelector('#vmo-sp-ai-out').innerHTML = '<div class="vmo-kpi-err">AI analizi başarısız: ' + e2.message + '</div>';
            }
          });
        }

        renderAll();
      } catch(e) {
        resultsEl.innerHTML = '<div class="vmo-kpi-err">Fiyat karşılaştırması yüklenemedi: ' + e.message + '</div>';
      }
    }

    await fetchAndRender();
  }

    async function loadSizeOpportunities() {
    const resultsEl = container.querySelector('#vmo-orders-results');
    const summaryEl = container.querySelector('#vmo-orders-summary');
    const exportBtn = container.querySelector('#vmo-export-btn');
    if (!resultsEl) return;
    if (summaryEl) summaryEl.innerHTML = '';
    if (exportBtn) exportBtn.style.display = 'none';
    resultsEl.innerHTML = '<div class="vmo-kpi-loading">📐 Ebat fırsatları hesaplanıyor…</div>';

    const segMap = { all: 'all', binek: 'tuketici', ticari: 'ticari', mevsimsel: 'kis' };
    const apiSeg = segMap[ordersSegment] || 'all';

    try {
      const data  = await apiFetch('/api/bi/orders/size-opportunities?segment=' + apiSeg);
      const items = data.items || [];

      if (!items.length) {
        resultsEl.innerHTML = '<div class="vmo-no-data">Bu segment için veri bulunamadı.</div>';
        return;
      }

      var cols = [
        { label: 'Ebat',             key: 'ebat' },
        { label: 'Marka',            key: 'marka' },
        { label: 'Devir (x/yıl)',    key: 'devir_hizi' },
        { label: 'Adet/Yıl',         key: 'toplam_adet' },
        { label: 'Ciro (₺)',         key: 'toplam_ciro' },
        { label: 'Stok',             key: 'eldeki_miktar' },
        { label: 'DIO (gün)',        key: 'dio_gun' },
        { label: 'DSO (gün)',        key: 'dso_gun' },
        { label: 'DPO (gün)',        key: 'dpo_gun' },
        { label: 'Fin. Gap',         key: 'finansal_gap' },
        { label: 'Eski Alış ₺',     key: 'eski_alis_fiyati' },
        { label: 'Yeni Alış ₺',     key: 'yeni_alis_fiyati' },
        { label: 'Yerine Koyma %',   key: 'yerine_koyma_pct' },
        { label: 'Enfl. Etkisi/Ad.', key: 'enflasyon_etkisi_birim' },
        { label: 'Fin. Mal./Ad.',    key: 'finansman_maliyeti_birim' },
      ];

      function sN(v) { return v == null ? '—' : Number(v).toLocaleString('tr-TR', { maximumFractionDigits: 0 }); }
      function sTL(v) { return v == null ? '—' : '₺' + sN(v); }

      function fmtCell(v, key) {
        if (v == null) return '—';
        if (['toplam_ciro','eski_alis_fiyati','yeni_alis_fiyati','enflasyon_etkisi_birim','finansman_maliyeti_birim'].indexOf(key) !== -1) return sTL(v);
        if (key === 'yerine_koyma_pct') {
          var c = v > 20 ? '#dc2626' : v > 10 ? '#d97706' : '#059669';
          return '<span style="color:' + c + ';font-weight:700">%' + (v > 0 ? '+' : '') + v + '</span>';
        }
        if (key === 'finansal_gap') {
          var c2 = v > 15 ? '#dc2626' : v > 0 ? '#d97706' : '#059669';
          return '<span style="color:' + c2 + '">' + (v > 0 ? '+' : '') + v + '</span>';
        }
        return typeof v === 'number' ? sN(v) : String(v);
      }

      // ── Ebat Fırsatları: sort + tooltip ─────────────────────────────────
      var __thS = 'padding:7px 10px;background:#1e293b;color:#e2e8f0;text-align:left;border-bottom:2px solid #334155;white-space:nowrap;font-weight:600;cursor:pointer;user-select:none';
      var __tdS = 'padding:6px 10px;border-bottom:1px solid #1e293b;white-space:nowrap';
      var __tips = {
        ebat:                    'Lastik ebat kodu (ornek: 205/55R16)',
        marka:                   'Lastik markasi',
        devir_hizi:              'Yillik stok devir hizi: yilda kac kez satilip yenilendi. Yuksek = verimli.',
        toplam_adet:             'Son 12 ayda satilan toplam adet',
        toplam_ciro:             'Son 12 ayda gerceklesen toplam satis tutari (TL)',
        eldeki_miktar:           'Mevcut stok adedi',
        dio_gun:                 'DIO (Days Inventory Outstanding): stok kac gunde satiliyor. Dusuk = iyi.',
        dso_gun:                 'DSO (Days Sales Outstanding): musteri faturayi kac gunde oduyor. Dusuk = iyi.',
        dpo_gun:                 'DPO (Days Payable Outstanding): tedarikci faturasini kac gunde oduyorsunuz. Yuksek = nakit avantaji.',
        finansal_gap:            'Finansal Bosluk = DSO - DPO. Pozitif = musteriden tahsil etmeden tedarikçiye oduyorsunuz (kotu nakit akisi). Negatif = avantajli.',
        eski_alis_fiyati:        'Mevcut stoktaki urunun ortalama alis fiyati (TL/adet)',
        yeni_alis_fiyati:        'Bugun siparis verseniz gecerli alis fiyati (TL/adet)',
        yerine_koyma_pct:        'Yerine Koyma (%): eski vs yeni alis fiyati farki. Yuksek pozitif = stok deger kazandi (enflasyon etkisi).',
        enflasyon_etkisi_birim:  'TUFE bazli gunluk stok tutma maliyeti (TL/adet/gun). Ne kadar yuksek DIO, o kadar bu maliyet birikir.',
        finansman_maliyeti_birim:'Sermaye baglanma maliyeti: TCMB faiz orani bazli hesaplanan birim finansman maliyeti (TL/adet)'
      };
      if (!document.getElementById('ebat-tip')) {
        var __tt = document.createElement('div');
        __tt.id = 'ebat-tip';
        __tt.style.cssText = 'position:fixed;z-index:9999;background:#1e293b;color:#e2e8f0;'
          + 'font-size:12px;padding:8px 12px;border-radius:7px;border:1px solid #334155;'
          + 'max-width:300px;line-height:1.55;pointer-events:none;display:none;'
          + 'box-shadow:0 6px 18px rgba(0,0,0,0.7)';
        document.body.appendChild(__tt);
      }
      window.__ebatShowTip = function(el, evt) {
        var txt = el.getAttribute('data-tip');
        if (!txt) return;
        var t = document.getElementById('ebat-tip');
        if (!t) return;
        t.textContent = txt;
        t.style.display = 'block';
        var x = Math.min(evt.clientX + 14, window.innerWidth - 310);
        t.style.left = x + 'px';
        t.style.top  = (evt.clientY + 16) + 'px';
      };
      window.__ebatHideTip = function() {
        var t = document.getElementById('ebat-tip');
        if (t) t.style.display = 'none';
      };
      window.__ebatState = { items: items, cols: cols, fmtCell: fmtCell, tdS: __tdS, sortKey: null, sortDir: 1 };
      window.__ebatSort = function(key) {
        var st = window.__ebatState;
        st.sortDir = (st.sortKey === key) ? st.sortDir * -1 : 1;
        st.sortKey = key;
        var sorted = st.items.slice().sort(function(a, bb) {
          var va = a[key], vb = bb[key];
          if (va == null && vb == null) return 0;
          if (va == null) return 1;
          if (vb == null) return -1;
          if (typeof va === 'string') return va.localeCompare(vb, 'tr') * st.sortDir;
          return (va - vb) * st.sortDir;
        });
        var tbEl = document.querySelector('#ebat-tbl tbody');
        if (tbEl) tbEl.innerHTML = sorted.map(function(r, i) {
          return '<tr style="background:' + (i % 2 ? '#0f172a' : '#1a2535') + '">'
            + st.cols.map(function(c) { return '<td style="' + st.tdS + '">' + st.fmtCell(r[c.key], c.key) + '</td>'; }).join('')
            + '</tr>';
        }).join('');
        document.querySelectorAll('#ebat-tbl th[data-sk]').forEach(function(th) {
          var ar = th.querySelector('.sa');
          if (ar) ar.textContent = (th.getAttribute('data-sk') === key) ? (st.sortDir === 1 ? ' ↑' : ' ↓') : ' ⇅';
        });
      };
      var __html = '<div style="padding:10px 0 6px;font-size:11.5px;color:#94a3b8;display:flex;gap:16px;flex-wrap:wrap">'
        + '<span>🔴 <b>Fin. Gap</b>: müşteri vade − tedarikçi vade (+ = kötü nakit akışı)</span>'
        + '<span>📈 <b>Yerine Koyma</b>: mevcut stoğu bugün alsaydınız fark</span>'
        + '<span>🌡 <b>Enflasyon</b>: stok tutmanın günlük enflasyon maliyeti/birim</span>'
        + '</div>'
        + '<div style="overflow-x:auto;margin-top:8px">'
        + '<table id="ebat-tbl" style="width:100%;font-size:12.5px;border-collapse:collapse">'
        + '<thead><tr>'
        + cols.map(function(c) {
            var tip = __tips[c.key] || '';
            return '<th style="' + __thS + '" data-sk="' + c.key + '" onclick="window.__ebatSort(\'' + c.key + '\')">'
              + '<span style="color:#fff;font-weight:700">' + c.label + '</span> <span class="sa" style="color:#6366f1;font-size:9px">⇅</span>'
              + (tip ? ' <span data-tip="' + tip + '" style="color:#6366f1;font-size:11px;cursor:help;font-weight:700" onclick="event.stopPropagation()" onmouseover="window.__ebatShowTip(this,event)" onmouseout="window.__ebatHideTip()">ⓘ</span>' : '')
              + '</th>';
          }).join('')
        + '</tr></thead><tbody>'
        + items.map(function(r, i) {
            return '<tr style="background:' + (i % 2 ? '#0f172a' : '#1a2535') + '">'
              + cols.map(function(c) { return '<td style="' + __tdS + '">' + fmtCell(r[c.key], c.key) + '</td>'; }).join('')
              + '</tr>';
          }).join('')
        + '</tbody></table></div>';
      resultsEl.innerHTML = __html + '<div id="vmo-bm-sect" style="margin-top:24px"></div>';
      (async function() {
        try {
          const bmData  = await apiFetch('/api/bi/orders/brand-mix?segment=' + apiSeg);
          const bmEl    = resultsEl.querySelector('#vmo-bm-sect');
          if (!bmEl) return;
          const bmItems = (bmData && bmData.items) || [];
          if (!bmItems.length) { bmEl.remove(); return; }
          var _tl  = function(n){ return (Math.round(n)||0).toLocaleString('tr-TR') + ' ₺'; };
          var _pct = function(n){ return (n||0).toFixed(1) + '%'; };
          var _h = '<div style="border-top:2px solid #334155;padding-top:20px">'
            + '<div style="font-size:15px;font-weight:700;color:#e2e8f0;margin-bottom:16px">'
            + '📊 Marka Optimizasyonu'
            + '<span style="font-size:11px;font-weight:400;color:#64748b;margin-left:10px">— aynı ebatta marka karmasını optimize ederek elde edilebilecek ek kar</span></div>';
          bmItems.forEach(function(item) {
            var net = item.oneri.net_kazanc_tl;
            var netCol = net >= 0 ? '#22c55e' : '#ef4444';
            _h += '<div style="background:#0f172a;border:1px solid #1e293b;border-radius:10px;padding:14px 16px;margin-bottom:12px">';
            _h += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">'
              + '<span style="font-size:14px;font-weight:700;color:#f1f5f9">' + esc(item.ebat) + '</span>'
              + '<span style="font-size:13px;font-weight:700;color:' + netCol + '">'
              + (net>0?'+':'') + _tl(net) + ' / yıl net fırsat</span></div>';
            _h += '<table style="width:100%;border-collapse:collapse;font-size:12px">'
              + '<thead><tr style="color:#64748b;border-bottom:1px solid #1e293b">'
              + '<th style="text-align:left;padding:4px 8px">Marka</th>'
              + '<th style="text-align:right;padding:4px 8px">Satış/Yıl</th>'
              + '<th style="text-align:right;padding:4px 8px">Brüt Marj</th>'
              + '<th style="text-align:right;padding:4px 8px">Teşvik</th>'
              + '<th style="text-align:right;padding:4px 8px">Efektif Marj</th>'
              + '<th style="text-align:right;padding:4px 8px">Fin. Maliyeti/Yıl</th>'
              + '</tr></thead><tbody>';
            item.markalar.forEach(function(m, mi) {
              var isBest = mi === 0;
              var rc  = isBest ? 'rgba(34,197,94,0.07)' : 'transparent';
              var mc  = isBest ? '#4ade80' : '#94a3b8';
              var emc = m.efektif_marj_pct != null ? _pct(m.efektif_marj_pct) : '—';
              _h += '<tr style="background:' + rc + '">'
                + '<td style="padding:5px 8px;color:' + mc + ';font-weight:' + (isBest?'700':'400') + '">'
                + (isBest ? '⭐ ' : '') + esc(m.marka) + '</td>'
                + '<td style="padding:5px 8px;text-align:right;color:#cbd5e1">' + (m.satis_adet||0) + ' adet</td>'
                + '<td style="padding:5px 8px;text-align:right;color:#cbd5e1">' + (m.marj_pct!=null?_pct(m.marj_pct):'—') + '</td>'
                + '<td style="padding:5px 8px;text-align:right;color:#60a5fa">' + (m.tesvik_pct>0?'+'+_pct(m.tesvik_pct):'—') + '</td>'
                + '<td style="padding:5px 8px;text-align:right;font-weight:700;color:' + mc + '">' + emc + '</td>'
                + '<td style="padding:5px 8px;text-align:right;color:#f87171">' + (m.yillik_finansman_tl>0?_tl(m.yillik_finansman_tl):'—') + '</td>'
                + '</tr>';
            });
            _h += '</tbody></table>';
            var losers = item.oneri.kaybeden_markalar || [];
            if (losers.length) {
              var ln = losers.map(function(l){ return esc(l.marka) + ' (efektif %' + (l.efektif_marj_pct||0).toFixed(1) + ')'; }).join(', ');
              _h += '<div style="margin-top:10px;padding:8px 12px;background:rgba(34,197,94,0.06);border-left:3px solid #22c55e;border-radius:4px;font-size:12px;color:#94a3b8">'
                + '💡 <strong style="color:#e2e8f0">' + esc(item.oneri.favori_marka) + '</strong> yerine '
                + ln + ' alımlarını yönlendirin'
                + ' → <strong style="color:#22c55e">+' + _tl(item.oneri.yillik_kazanc_tl) + ' ek kar potansiyeli</strong>'
                + (item.oneri.finansman_baskisi_tl > 0
                    ? ' · Düşük marjlı stok finansman baskısı: <strong style="color:#f87171">' + _tl(item.oneri.finansman_baskisi_tl) + '/yıl</strong>'
                    : '')
                + '</div>';
            }
            _h += '</div>';
          });
          _h += '</div>';
          bmEl.innerHTML = _h;
        } catch(e2) {
          var bmEl2 = resultsEl.querySelector('#vmo-bm-sect');
          if (bmEl2) bmEl2.remove();
        }
      })();

    } catch(e) {
      resultsEl.innerHTML = '<div class="vmo-kpi-err">Ebat fırsatları yüklenemedi: ' + e.message + '</div>';
    }

  }


  // ── Pricing room extras: Rates bar + Finansal Analiz section ───────────────
  function renderPricingExtras() {

    // 1. Market rates bar in #vmo-briefing-pricing
    var briefEl = container.querySelector('#vmo-briefing-pricing');
    if (briefEl) {
      briefEl.setAttribute('style', 'display:flex;align-items:center;gap:12px;padding:10px 16px;'
        + 'background:rgba(15,23,42,0.9);border-radius:8px;margin-bottom:16px;'
        + 'border:1px solid #1e293b;flex-wrap:wrap;font-size:13px');
      briefEl.innerHTML = '<span style="color:#64748b;font-size:12px">📡 Piyasa verileri yükleniyor…</span>';

      apiFetch('/api/bi/market/rates').then(function(d) {
        function badge(label, val, color) {
          return '<span style="display:inline-flex;align-items:center;gap:6px;'
            + 'background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.08);'
            + 'border-radius:6px;padding:4px 10px">'
            + '<span style="color:#64748b;font-size:11px">' + label + '</span>'
            + '<span style="color:' + color + ';font-weight:700;font-size:14px">' + val + '</span>'
            + '</span>';
        }
        function f2(v) {
          return v != null ? Number(v).toLocaleString('tr-TR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '—';
        }
        function pct(v) { return v != null ? '%' + v : '—'; }

        var age = '';
        if (d.gecerli_tarih) {
          var h = (Date.now() - new Date(d.gecerli_tarih).getTime()) / 3600000;
          age = h < 2 ? 'Bugün' : h < 48 ? Math.round(h) + ' saat önce' : Math.round(h / 24) + ' gün önce';
        }

        briefEl.innerHTML = ''
          + '<span style="color:#64748b;font-size:11px;white-space:nowrap">📡 Piyasa' + (age ? ' · ' + age : '') + '</span>'
          + badge('USD/TRY',       f2(d.usd_try),      '#f59e0b')
          + badge('EUR/TRY',       f2(d.eur_try),      '#8b5cf6')
          + badge('TCMB Faiz',     pct(d.tcmb_faiz),   '#06b6d4')
          + badge('TÜFE yıllık',   pct(d.tufe_yillik), '#ec4899')
          + badge('Banka Kredi',   pct(d.banka_faiz),  '#f97316')
          + '<button id="vmo-rates-refresh-btn" style="margin-left:auto;background:none;border:1px solid #334155;'
          + 'border-radius:4px;color:#64748b;font-size:11px;padding:3px 8px;cursor:pointer">↻ Yenile</button>';

        var refreshBtn = briefEl.querySelector('#vmo-rates-refresh-btn');
        if (refreshBtn) {
          refreshBtn.addEventListener('click', function() {
            briefEl.innerHTML = '<span style="color:#64748b;font-size:12px">Güncelleniyor…</span>';
            apiFetch('/api/bi/market/rates?refresh=1').then(function() { renderPricingExtras(); });
          });
        }
      }).catch(function() {
        briefEl.innerHTML = '<span style="color:#ef4444;font-size:12px">Piyasa verileri alınamadı</span>';
      });
    }

    // 2. Financial analysis section (inject once below #vmo-chart-pricing)
    var chartEl = container.querySelector('#vmo-chart-pricing');
    if (!chartEl) return;
    if (container.querySelector('#vmo-pricing-financial')) return; // already mounted

    var finEl = document.createElement('div');
    finEl.id = 'vmo-pricing-financial';
    finEl.style.marginTop = '24px';
    chartEl.insertAdjacentElement('afterend', finEl);

    // Closure state
    var pfTab    = 'fp';
    var fpDim    = 'ebat';
    var fpDays   = 90;
    var siSeg    = 'all';
    var siYear   = 2023;
    var cccMonths = 3;

    var thS = 'padding:7px 10px;background:#1e293b;color:#94a3b8;text-align:left;border-bottom:2px solid #334155;white-space:nowrap;font-weight:600';
    var tdS = 'padding:6px 10px;border-bottom:1px solid #1e293b;white-space:nowrap';
    function rowBg(i) { return i % 2 ? '#0f172a' : '#1a2535'; }
    function nFmt(v) { return v == null ? '—' : Number(v).toLocaleString('tr-TR', { maximumFractionDigits: 0 }); }

    // ── Finansal Perspektif ──────────────────────────────────────────────────
    function loadFP() {
      var contentEl = finEl.querySelector('#vmo-pfin-content');
      if (!contentEl) return;
      contentEl.innerHTML = '<div class="vmo-kpi-loading">Yükleniyor…</div>';
      apiFetch('/api/bi/analytics/financial-perspective?dimension=' + fpDim + '&days=' + fpDays + '&segment=all')
        .then(function(data) {
          var rows = data.items || [];
          if (!rows.length) { contentEl.innerHTML = '<div class="vmo-no-data">Veri bulunamadı.</div>'; return; }

          var dimLabel = { ebat: 'Ebat', marka: 'Marka', musteri: 'Müşteri', urun: 'Ürün' }[fpDim] || fpDim;
          var cols = [
            { l: dimLabel,          k: 'dim_key' },
            { l: 'Satış (₺)',       k: 'toplam_ciro' },
            { l: 'Ciro Değişim %',  k: 'ciro_degisim_pct' },
            { l: 'Adet',            k: 'toplam_adet' },
            { l: 'Müşteri',         k: 'musteri_sayisi' },
            { l: 'Fatura',          k: 'fatura_sayisi' },
            { l: 'Ort. Birim ₺',   k: 'avg_birim_fiyat' },
            { l: 'Ort. DSO (gün)', k: 'avg_dso' },
          ];

          function fmt(v, k) {
            if (v == null) return '—';
            if (k === 'toplam_ciro' || k === 'avg_birim_fiyat') return '₺' + nFmt(v);
            if (k === 'ciro_degisim_pct') {
              var c = v > 0 ? '#059669' : '#dc2626';
              return '<span style="color:' + c + ';font-weight:700">' + (v > 0 ? '+' : '') + Number(v).toFixed(1) + '%</span>';
            }
            if (k === 'avg_dso') {
              var c2 = v > 60 ? '#dc2626' : v > 30 ? '#d97706' : '#059669';
              return '<span style="color:' + c2 + '">' + Number(v).toFixed(0) + '</span>';
            }
            return typeof v === 'number' ? nFmt(v) : String(v);
          }

          var html = '<div style="overflow-x:auto"><table style="width:100%;font-size:12.5px;border-collapse:collapse">'
            + '<thead><tr>' + cols.map(function(c) { return '<th style="' + thS + '">' + c.l + '</th>'; }).join('') + '</tr></thead>'
            + '<tbody>';
          rows.forEach(function(r, i) {
            html += '<tr style="background:' + rowBg(i) + '">';
            cols.forEach(function(c) { html += '<td style="' + tdS + '">' + fmt(r[c.k], c.k) + '</td>'; });
            html += '</tr>';
          });
          html += '</tbody></table></div>';
          contentEl.innerHTML = html;
        })
        .catch(function(e) { contentEl.innerHTML = '<div class="vmo-kpi-err">' + e.message + '</div>'; });
    }

    // ── Ebat Endeksi ─────────────────────────────────────────────────────────
    function loadSI() {
      var contentEl = finEl.querySelector('#vmo-pfin-content');
      if (!contentEl) return;
      contentEl.innerHTML = '<div class="vmo-kpi-loading">Yükleniyor…</div>';
      apiFetch('/api/bi/analytics/size-index?segment=' + siSeg + '&year_from=' + siYear)
        .then(function(data) {
          var ebatlar = data.ebatlar || [];
          var yillar  = data.yillar  || [];
          var byData  = data.data    || {};
          if (!ebatlar.length) { contentEl.innerHTML = '<div class="vmo-no-data">Veri bulunamadı.</div>'; return; }

          // Build table: rows = ebatlar, cols = years × (adet, ciro, Δ%)
          var html = '<div style="overflow-x:auto"><table style="width:100%;font-size:12.5px;border-collapse:collapse">'
            + '<thead>'
            + '<tr><th style="' + thS + '">Ebat</th>'
            + yillar.map(function(y) { return '<th colspan="3" style="' + thS + ';text-align:center">' + y + '</th>'; }).join('')
            + '</tr>'
            + '<tr><th style="padding:4px 10px;background:#1a2535;color:#64748b;border-bottom:1px solid #334155;font-size:11px"></th>'
            + yillar.map(function() {
                return ['Adet','Ciro (₺)','Δ%'].map(function(l) {
                  return '<th style="padding:4px 8px;background:#1a2535;color:#64748b;border-bottom:1px solid #334155;font-size:11px;white-space:nowrap">' + l + '</th>';
                }).join('');
              }).join('')
            + '</tr></thead><tbody>';

          ebatlar.forEach(function(ebat, i) {
            html += '<tr style="background:' + rowBg(i) + '">';
            html += '<td style="' + tdS + ';font-weight:600">' + ebat + '</td>';
            yillar.forEach(function(y) {
              var r = byData[ebat] && byData[ebat][y];
              if (r) {
                var d = r.adet_degisim;
                var dc = d == null ? '#64748b' : d > 0 ? '#059669' : '#dc2626';
                html += '<td style="' + tdS + '">' + nFmt(r.adet) + '</td>';
                html += '<td style="' + tdS + '">₺' + nFmt(r.ciro) + '</td>';
                html += '<td style="' + tdS + ';color:' + dc + ';font-weight:600">'
                  + (d != null ? (d > 0 ? '+' : '') + Number(d).toFixed(1) + '%' : '—') + '</td>';
              } else {
                html += '<td style="' + tdS + '">—</td><td style="' + tdS + '">—</td><td style="' + tdS + '">—</td>';
              }
            });
            html += '</tr>';
          });
          html += '</tbody></table></div>';
          contentEl.innerHTML = html;
        })
        .catch(function(e) { contentEl.innerHTML = '<div class="vmo-kpi-err">' + e.message + '</div>'; });
    }

    // ── Nakit Döngüsü Geçmişi ────────────────────────────────────────────────
    function loadCCC() {
      var contentEl = finEl.querySelector('#vmo-pfin-content');
      if (!contentEl) return;
      contentEl.innerHTML = '<div class="vmo-kpi-loading">Yükleniyor…</div>';
      apiFetch('/api/bi/analytics/cash-cycle-history?months=' + cccMonths)
        .then(function(data) {
          var rows = data.months || [];
          if (!rows.length) { contentEl.innerHTML = '<div class="vmo-no-data">Veri bulunamadı.</div>'; return; }

          var maxCCC = 0;
          rows.forEach(function(r) { if (Math.abs(r.ccc || 0) > maxCCC) maxCCC = Math.abs(r.ccc || 0); });

          var heads = ['Dönem','DIO (gün)','DSO (gün)','DPO (gün)','Nakit Döngüsü (CCC)','Ciro (₺)','Stok Değeri (₺)'];
          var html = '<div style="overflow-x:auto"><table style="width:100%;font-size:12.5px;border-collapse:collapse">'
            + '<thead><tr>' + heads.map(function(h) { return '<th style="' + thS + '">' + h + '</th>'; }).join('') + '</tr></thead>'
            + '<tbody>';

          rows.forEach(function(r, i) {
            var ccc   = r.ccc;
            var cccC  = ccc == null ? '#64748b' : ccc > 30 ? '#dc2626' : ccc > 0 ? '#d97706' : '#059669';
            var barW  = (maxCCC > 0 && ccc != null) ? Math.round(Math.abs(ccc) / maxCCC * 80) : 0;
            html += '<tr style="background:' + rowBg(i) + '">'
              + '<td style="' + tdS + ';font-weight:600">' + (r.ay || '—') + '</td>'
              + '<td style="' + tdS + '">' + (r.dio != null ? nFmt(r.dio) : '—') + '</td>'
              + '<td style="' + tdS + '">' + nFmt(r.dso) + '</td>'
              + '<td style="' + tdS + '">' + nFmt(r.dpo) + '</td>'
              + '<td style="' + tdS + '">'
              +   '<div style="display:flex;align-items:center;gap:8px">'
              +     '<div style="width:' + barW + 'px;height:6px;background:' + cccC + ';border-radius:3px;min-width:4px"></div>'
              +     '<span style="color:' + cccC + ';font-weight:700">'
              +       (ccc != null ? (ccc > 0 ? '+' : '') + nFmt(ccc) + ' gün' : '—')
              +     '</span>'
              +   '</div>'
              + '</td>'
              + '<td style="' + tdS + '">₺' + nFmt(r.ciro) + '</td>'
              + '<td style="' + tdS + '">₺' + nFmt(r.stok_degeri) + '</td>'
              + '</tr>';
          });
          html += '</tbody></table></div>'
            + '<div style="margin-top:10px;font-size:11.5px;color:#64748b">'
            + 'CCC = DIO + DSO − DPO &nbsp;·&nbsp; <0 = nakit avantajlı (tedarikçiyi geç öde, müşteriyi erken tahsil et)'
            + '</div>';
          // ── Inline SVG trend chart ──────────────────────────────────────────
          var __n=rows.length,__ch='';
          if(__n>=2){
            var __av=[];
            rows.forEach(function(r){if(r.dio!=null)__av.push(r.dio);if(r.dso!=null)__av.push(r.dso);if(r.dpo!=null)__av.push(r.dpo);if(r.ccc!=null)__av.push(r.ccc);});
            var __mn=Math.min(0,Math.min.apply(null,__av)),__mx=Math.max.apply(null,__av)*1.1,__rng=__mx-__mn||1;
            var __W=680,__H=165,__PL=44,__PR=12,__PT=24,__PB=28,__iW=__W-__PL-__PR,__iH=__H-__PT-__PB;
            var __xp=function(i){return(__PL+(i/(__n-1))*__iW).toFixed(1);};
            var __yp=function(v){return(__PT+(1-(v-__mn)/__rng)*__iH).toFixed(1);};
            var __pl=function(key,col){
              var pts=rows.map(function(r,i){return r[key]!=null?(__xp(i)+','+__yp(r[key])):null;}).filter(Boolean);
              return pts.length>1?('<polyline points="'+pts.join(' ')+'" fill="none" stroke="'+col+'" stroke-width="2" stroke-linejoin="round"/>'):'';
            };
            var __g='';
            for(var __i=0;__i<=4;__i++){
              var __gv=__mn+(__rng/4)*__i,__gy=__yp(__gv);
              __g+='<line x1="'+__PL+'" y1="'+__gy+'" x2="'+(__W-__PR)+'" y2="'+__gy+'" stroke="#1e293b" stroke-width="1"/>';
              __g+='<text x="'+(__PL-5)+'" y="'+(parseFloat(__gy)+4)+'" text-anchor="end" fill="#475569" font-size="9">'+Math.round(__gv)+'</text>';
            }
            if(__mn<0){var __zy=__yp(0);__g+='<line x1="'+__PL+'" y1="'+__zy+'" x2="'+(__W-__PR)+'" y2="'+__zy+'" stroke="#475569" stroke-width="1" stroke-dasharray="4,2"/>';}
            var __xl='';
            rows.forEach(function(r,i){__xl+='<text x="'+__xp(i)+'" y="'+(__H-4)+'" text-anchor="middle" fill="#475569" font-size="9">'+(r.ay?r.ay.slice(5)+'/'+r.ay.slice(2,4):'')+'</text>';});
            __ch='<svg viewBox="0 0 '+__W+' '+__H+'" xmlns="http://www.w3.org/2000/svg" style="width:100%;max-height:165px;display:block;margin-bottom:14px">'
              +'<text x="'+__PL+'" y="14" fill="#6366f1" font-size="10">■ DIO</text>'
              +'<text x="'+(__PL+55)+'" y="14" fill="#f59e0b" font-size="10">■ DSO</text>'
              +'<text x="'+(__PL+110)+'" y="14" fill="#22c55e" font-size="10">■ DPO</text>'
              +'<text x="'+(__PL+165)+'" y="14" fill="#ef4444" font-size="10">■ CCC</text>'
              +__g
              +__pl('dio','#6366f1')+__pl('dso','#f59e0b')+__pl('dpo','#22c55e')+__pl('ccc','#ef4444')
              +__xl+'</svg>';
          }
          contentEl.innerHTML = __ch + html;

          // ── AI Ekonomik Bağlam Analizi ─────────────────────────────────
          (function() {
            var insightEl = document.createElement('div');
            insightEl.style.cssText = 'margin-top:18px;background:linear-gradient(135deg,#0f172a 0%,#1a0533 100%);border:1px solid rgba(124,58,237,0.35);border-radius:10px;padding:14px 16px';
            insightEl.innerHTML = '<div style="display:flex;align-items:center;gap:8px;margin-bottom:10px">'
              + '<span style="font-size:13px;font-weight:700;color:#a78bfa">\u{1F9E0} Ekonomik Ba\u011flam Analizi</span>'
              + '<span style="font-size:11px;color:#475569;margin-left:auto">Fiyat Analisti \u00b7 AI</span>'
              + '</div>'
              + '<div id="vmo-ccc-ai-txt" style="font-size:12.5px;color:#94a3b8;line-height:1.65;white-space:pre-wrap"></div>';
            contentEl.appendChild(insightEl);
            var txtEl = insightEl.querySelector('#vmo-ccc-ai-txt');
            txtEl.textContent = 'T\u00fcrkiye ekonomik ko\u015fullar\u0131 ba\u011flam\u0131nda analiz yap\u0131l\u0131yor\u2026';

            apiFetch('/api/bi/market/rates').then(function(eco) {
              var tcmbRate = eco && eco.tcmb_faiz   ? eco.tcmb_faiz : 42.5;
              var usdRate  = eco && eco.usd_try     ? parseFloat(eco.usd_try).toFixed(2) : '46.43';
              var eurRate  = eco && eco.eur_try     ? parseFloat(eco.eur_try).toFixed(2) : '53.18';
              var tufe     = eco && eco.tufe_yillik ? eco.tufe_yillik : 35;

              var dataStr = rows.map(function(r) {
                return r.ay
                  + ' DIO=' + (r.dio != null ? r.dio : '-') + 'g'
                  + ' DSO=' + r.dso + 'g'
                  + ' DPO=' + r.dpo + 'g'
                  + ' CCC=' + (r.ccc != null ? (r.ccc > 0 ? '+' : '') + r.ccc : '-') + 'g'
                  + ' Ciro=' + (r.ciro / 1e6).toFixed(1) + 'M TL'
                  + ' Stok=' + (r.stok_degeri / 1e6).toFixed(1) + 'M TL';
              }).join(' | ');

              var latest = rows[rows.length - 1] || {};
              var prev   = rows[rows.length - 2] || {};
              var trend  = (latest.ccc != null && prev.ccc != null)
                ? (latest.ccc > prev.ccc ? 'kotulesme ' + prev.ccc + '>' + latest.ccc + ' gun' : 'iyilesme ' + prev.ccc + '>' + latest.ccc + ' gun')
                : '?';

              var prompt = 'KRB lastik distributorunun Nakit Dongusu verileri (' + cccMonths + ' ay): '
                + dataStr + '. CCC trend: ' + trend + '.'
                + ' Ekonomik gostergeler: TCMB faiz %' + tcmbRate
                + ', USD/TRY ' + usdRate + ', EUR/TRY ' + eurRate
                + ', TUFE yillik ~%' + tufe + '.'
                + ' Lutfen 5 paragrafta Turkce yanit ver:'
                + ' 1) Mevcut CCC rakamlarini %' + tcmbRate + ' TCMB faiz ortaminda degerlendir — stok tutmanin gercek firsat maliyeti nedir?'
                + ' 2) DIO trendini yorumla — yuksek enflasyonda stok tutmak avantajli mi?'
                + ' 3) DSO ve DPO dengesini analiz et — nakit akisi nasil iyilestirilebilir?'
                + ' 4) USD ' + usdRate + ' ve EUR ' + eurRate + ' seviyesinde ithal lastik alimlarinin vadeli planlamasi?'
                + ' 5) En az 3 somut, olcumlenebilir aksiyon oner.';

              txtEl.textContent = '';
              fetch('/api/bi/department/pricing/chat', {
                method: 'POST', credentials: 'include',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message: prompt })
              }).then(function(res) {
                if (!res.ok) { txtEl.textContent = 'Analiz alinamadi (' + res.status + ').'; return; }
                var reader = res.body.getReader(), dec = new TextDecoder(), buf = '';
                function pump() {
                  return reader.read().then(function(result) {
                    if (result.done) return;
                    buf += dec.decode(result.value, { stream: true });
                    var lines = buf.split('\n'); buf = lines.pop();
                    for (var i = 0; i < lines.length; i++) {
                      if (!lines[i].startsWith('data: ')) continue;
                      try { var d = JSON.parse(lines[i].slice(6)); if (d.text) txtEl.textContent += d.text; } catch(e2) {}
                    }
                    return pump();
                  });
                }
                pump().catch(function(e) { txtEl.textContent += ' [Akis kesildi]'; });
              }).catch(function(e) { txtEl.textContent = 'Baglanti hatasi: ' + e.message; });
            }).catch(function() { txtEl.textContent = 'Ekonomik veriler alinamadi.'; });
          })();

        })
        .catch(function(e) { contentEl.innerHTML = '<div class="vmo-kpi-err">' + e.message + '</div>'; });
    }

    // ── Tab render ────────────────────────────────────────────────────────────
    function renderFin() {
      function sel(id, opts, cur) {
        var s = '<select id="' + id + '" style="background:#1e293b;border:1px solid #334155;border-radius:5px;color:#e2e8f0;padding:4px 8px;font-size:12px;cursor:pointer">';
        opts.forEach(function(o) {
          s += '<option value="' + o[0] + '"' + (String(o[0]) === String(cur) ? ' selected' : '') + '>' + o[1] + '</option>';
        });
        return s + '</select>';
      }

      var controls = '';
      if (pfTab === 'fp') {
        controls = sel('vmo-fp-dim',  [['ebat','Ebat'],['marka','Marka'],['musteri','Müşteri'],['urun','Ürün']], fpDim)
                 + sel('vmo-fp-days', [[30,'Son 30 gün'],[90,'Son 90 gün'],[180,'Son 6 ay'],[365,'Son 1 yıl']], fpDays);
      } else if (pfTab === 'si') {
        controls = sel('vmo-si-seg',  [['all','Tümü'],['tuketici','Tüketici'],['ticari','Ticari'],['yaz','Yaz'],['kis','Kış']], siSeg)
                 + sel('vmo-si-year', [[2021,"2021'den"],[2022,"2022'den"],[2023,"2023'ten"],[2024,"2024'ten"]], siYear);
      } else if (pfTab === 'ccc') {
        controls = sel('vmo-ccc-months', [[3,'Son 3 ay'],[6,'Son 6 ay'],[12,'Son 12 ay'],[24,'Son 24 ay']], cccMonths);
      }

      function tabBtn(id, icon, label) {
        var active = pfTab === id;
        return '<button data-ptab="' + id + '" style="padding:6px 14px;'
          + 'background:' + (active ? 'rgba(99,102,241,0.2)' : 'transparent') + ';'
          + 'border:1px solid ' + (active ? 'rgba(99,102,241,0.5)' : '#334155') + ';'
          + 'border-radius:6px;color:' + (active ? '#818cf8' : '#94a3b8') + ';'
          + 'font-size:12.5px;cursor:pointer;font-weight:' + (active ? '600' : '400') + '">'
          + icon + ' ' + label + '</button>';
      }

      finEl.innerHTML = '<div style="background:#0f172a;border:1px solid #1e293b;border-radius:10px;padding:16px">'
        + '<div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;flex-wrap:wrap">'
        + '<span style="font-size:13px;font-weight:600;color:#e2e8f0;margin-right:4px">📊 Finansal Analiz</span>'
        + tabBtn('fp',  '💼', 'Finansal Perspektif')
        + tabBtn('si',  '📐', 'Ebat Endeksi')
        + tabBtn('ccc', '🔄', 'Nakit Döngüsü')
        + '<div style="margin-left:auto;display:flex;gap:8px;align-items:center">' + controls + '</div>'
        + '</div>'
        + '<div id="vmo-pfin-content"><div class="vmo-kpi-loading">Yükleniyor…</div></div>'
        + '</div>';

      // Bind tab buttons
      finEl.querySelectorAll('[data-ptab]').forEach(function(btn) {
        btn.addEventListener('click', function() { pfTab = btn.dataset.ptab; renderFin(); });
      });

      // Bind control selects
      var el;
      el = finEl.querySelector('#vmo-fp-dim');
      if (el) el.addEventListener('change', function(e) { fpDim = e.target.value; loadFP(); });
      el = finEl.querySelector('#vmo-fp-days');
      if (el) el.addEventListener('change', function(e) { fpDays = +e.target.value; loadFP(); });
      el = finEl.querySelector('#vmo-si-seg');
      if (el) el.addEventListener('change', function(e) { siSeg = e.target.value; loadSI(); });
      el = finEl.querySelector('#vmo-si-year');
      if (el) el.addEventListener('change', function(e) { siYear = +e.target.value; loadSI(); });
      el = finEl.querySelector('#vmo-ccc-months');
      if (el) el.addEventListener('change', function(e) { cccMonths = +e.target.value; loadCCC(); });

      // Load initial content
      if (pfTab === 'fp')  loadFP();
      else if (pfTab === 'si')  loadSI();
      else if (pfTab === 'ccc') loadCCC();
    }

    renderFin();
  }



  async function loadBriefing() {
    try {
      const data = await apiFetch("/api/bi/morning-briefing");
      const c = data.content_json;
      if (!c?.summary) return;
      // Show briefing in the active room only, others get it when switched
      OFFICERS.forEach(o => {
        const bar = container.querySelector(`#vmo-briefing-${o.id}`);
        if (!bar) return;
        bar.style.display = "block";
        var _dmap={sales:"sales_summary",warehouse:"warehouse_summary",pricing:"pricing_summary",it:"it_summary",orders:"warehouse_summary"};
        var _dtxt=c[_dmap[o.id]]||c.summary||"";
        bar.innerHTML = `
          <div class="vmo-briefing">
            <span class="vmo-briefing-sun">☀️</span>
            <div class="vmo-briefing-body">
              <div class="vmo-briefing-text">${esc(_dtxt)}</div>
              <div class="vmo-briefing-pills">
                ${c.sales_highlight ? `<span class="vmo-pill vmo-pill-blue">📈 ${esc(c.sales_highlight)}</span>` : ""}
                ${c.stock_alert     ? `<span class="vmo-pill vmo-pill-orange">📦 ${esc(c.stock_alert)}</span>` : ""}
                ${c.pricing_note    ? `<span class="vmo-pill vmo-pill-purple">💰 ${esc(c.pricing_note)}</span>` : ""}
              </div>
            </div>
            <button class="vmo-briefing-x" onclick="this.closest('.vmo-briefing-bar').style.display='none'">✕</button>
          </div>`;
      });
    } catch { /* silent */ }
  }

  // ── Fiyat Listeleri room ──────────────────────────────────────────────────
  async function loadPriceList() {
    const el = container.querySelector('#vmo-room-price-list');
    if (!el || el._plInit) return;
    el._plInit = true;
    el.style.overflowY = 'auto';

    el.innerHTML =
      '<div style="padding:24px;max-width:1100px">' +
        '<div id="pl-action-bar" style="display:flex;align-items:center;gap:8px;margin-bottom:14px;flex-wrap:wrap">' +
          '<button id="pl-toggle-lists" style="background:rgba(255,255,255,0.05);border:0.5px solid rgba(255,255,255,0.15);border-radius:6px;padding:5px 12px;color:#94a3b8;font-size:12px;cursor:pointer;font-weight:600;white-space:nowrap">📋 Fiyat Listeleri ▾</button>' +
        '</div>' +
        '<div id="pl-lists-panel" style="display:none;margin-bottom:18px;padding:16px;background:rgba(255,255,255,0.02);border:0.5px solid rgba(255,255,255,0.07);border-radius:10px">' +
          '<div style="display:flex;gap:8px;margin-bottom:12px;align-items:center;flex-wrap:wrap">' +
            '<select id="pl-kat-filter" style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:5px 10px;color:#94a3b8;font-size:12px;outline:none">' +
              '<option value="">Tüm Kategoriler</option>' +
              '<option value="KIS">KIŞ</option><option value="YAZ">YAZ</option>' +
              '<option value="4 MEVSIM">4 Mevsim</option><option value="TİCARİ">TİCARİ</option>' +
            '</select>' +
            '<select id="pl-brand-filter" style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:5px 10px;color:#94a3b8;font-size:12px;outline:none">' +
              '<option value="">Tüm Markalar</option>' +
            '</select>' +
            '<span style="flex:1"></span>' +
            '<input id="pl-ebat-inp" type="text" placeholder="175/65R14" style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:8px;padding:7px 12px;color:#f1f5f9;font-size:13px;outline:none;width:140px">' +
            '<button id="pl-ebat-btn" style="background:#059669;border:none;border-radius:8px;padding:7px 14px;color:#fff;font-size:13px;cursor:pointer;font-weight:600">Karşılaştır</button>' +
          '</div>' +
          '<div id="pl-uploads-wrap"><div style="color:#64748b;font-size:13px">Yükleniyor...</div></div>' +
          '<div id="pl-items-wrap" style="display:none;margin-top:12px">' +
            '<div id="pl-items-header"></div>' +
            '<div id="pl-items-table" style="max-height:460px;overflow-y:auto;margin-top:10px"></div>' +
          '</div>' +
          '<div id="pl-compare-wrap" style="display:none;margin-top:12px">' +
            '<div id="pl-compare-results"></div>' +
          '</div>' +
        '</div>' +
      '</div>';

    var plTiers = null; var plTiersCache = {}; var curKdvHaric = false;
    var _VADE = {
      LASSA:       { KIS:"<div style=\"background:rgba(59,130,246,0.06);border-left:2px solid rgba(59,130,246,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px;color:#94a3b8;line-height:1.6\"><span style=\"color:#60a5fa;font-weight:700\">Ödeme Vadesi — KIŞ (2 Taksit)</span><br><span style=\"color:#64748b\">Tem/Ağu/Eyl fatural. →</span> <span style=\"color:#e2e8f0\">1. Taksit 18 Kasım &middot; 2. Taksit 16 Aralık 2026</span><br><span style=\"color:#64748b\">Eki/Kas/Ara fatural. →</span> <span style=\"color:#e2e8f0\">1. Taksit 22 Ocak &middot; 2. Taksit 22 Şubat 2027</span></div>", YAZ:"<div style=\"background:rgba(251,191,36,0.06);border-left:2px solid rgba(251,191,36,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px\"><span style=\"color:#fbbf24;font-weight:700\">Ödeme Vadesi</span><span style=\"color:#e2e8f0;margin-left:8px\">90 Gün</span></div>", "4 MEVSIM":"<div style=\"background:rgba(251,191,36,0.06);border-left:2px solid rgba(251,191,36,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px\"><span style=\"color:#fbbf24;font-weight:700\">Ödeme Vadesi</span><span style=\"color:#e2e8f0;margin-left:8px\">90 Gün</span></div>" },
      BRIDGESTONE: { KIS:"<div style=\"background:rgba(59,130,246,0.06);border-left:2px solid rgba(59,130,246,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px;color:#94a3b8;line-height:1.6\"><span style=\"color:#60a5fa;font-weight:700\">Ödeme Vadesi — KIŞ (2 Taksit)</span><br><span style=\"color:#64748b\">Tem/Ağu/Eyl fatural. →</span> <span style=\"color:#e2e8f0\">1. Taksit 18 Kasım &middot; 2. Taksit 16 Aralık 2026</span><br><span style=\"color:#64748b\">Eki/Kas/Ara fatural. →</span> <span style=\"color:#e2e8f0\">1. Taksit 22 Ocak &middot; 2. Taksit 22 Şubat 2027</span></div>", YAZ:"<div style=\"background:rgba(251,191,36,0.06);border-left:2px solid rgba(251,191,36,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px\"><span style=\"color:#fbbf24;font-weight:700\">Ödeme Vadesi</span><span style=\"color:#e2e8f0;margin-left:8px\">90 Gün</span></div>", "4 MEVSIM":"<div style=\"background:rgba(251,191,36,0.06);border-left:2px solid rgba(251,191,36,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px\"><span style=\"color:#fbbf24;font-weight:700\">Ödeme Vadesi</span><span style=\"color:#e2e8f0;margin-left:8px\">90 Gün</span></div>" },
      CONTINENTAL: { _d:"<div style=\"background:rgba(167,139,250,0.06);border-left:2px solid rgba(167,139,250,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px\"><span style=\"color:#a78bfa;font-weight:700\">Ödeme Vadesi</span><span style=\"color:#64748b;font-size:10px;margin-left:4px\">(tahmini)</span><span style=\"color:#e2e8f0;margin-left:8px\">3 Taksit — Kasım &middot; Aralık &middot; Ocak</span></div>" },
      MATADOR:     { _d:"<div style=\"background:rgba(167,139,250,0.06);border-left:2px solid rgba(167,139,250,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px\"><span style=\"color:#a78bfa;font-weight:700\">Ödeme Vadesi</span><span style=\"color:#64748b;font-size:10px;margin-left:4px\">(tahmini)</span><span style=\"color:#e2e8f0;margin-left:8px\">3 Taksit — Kasım &middot; Aralık &middot; Ocak</span></div>" },
      BARUM:       { _d:"<div style=\"background:rgba(167,139,250,0.06);border-left:2px solid rgba(167,139,250,0.5);border-radius:4px;padding:7px 10px;margin-bottom:8px;font-size:11px\"><span style=\"color:#a78bfa;font-weight:700\">Ödeme Vadesi</span><span style=\"color:#64748b;font-size:10px;margin-left:4px\">(tahmini)</span><span style=\"color:#e2e8f0;margin-left:8px\">3 Taksit — Kasım &middot; Aralık &middot; Ocak</span></div>" },
    };
    function getVadeHtml(marka, kat) {
      var vm = _VADE[marka]; if (!vm) return "";
      return vm[kat] || vm._d || "";
    }
    var _SCENARIO_BAR = '<div style="display:flex;align-items:center;gap:10px;margin-bottom:8px"><span style="color:#475569;font-size:9px;font-weight:700;letter-spacing:0.8px;text-transform:uppercase;white-space:nowrap">Zam Sen.</span><input type="range" class="pl-sc-range" min="0" max="50" value="0" step="1" style="flex:1;accent-color:#34d399;cursor:pointer;height:4px;outline:none"><span class="pl-sc-label" style="color:#34d399;font-size:12px;font-weight:700;min-width:36px;text-align:right">+0%</span><span style="margin-left:auto;font-size:9px;color:#475569;white-space:nowrap;user-select:none">⚡ <strong class="pl-rate-val" style="color:#a78bfa;cursor:pointer;border-bottom:1px dashed rgba(167,139,250,0.4)" title="TCMB faizini düzenlemek için tıkla">%46</strong> TCMB</span></div>';
    async function loadUploads() {
      var kat   = el.querySelector('#pl-kat-filter').value;
      var brand = el.querySelector('#pl-brand-filter').value;
      var wrap  = el.querySelector('#pl-uploads-wrap');
      wrap.innerHTML = '<div style="color:#64748b;font-size:13px">Yükleniyor...</div>';
      try {
        var params = new URLSearchParams();
        if (kat)   params.set('kategori', kat);
        if (brand) params.set('marka', brand);
        var data    = await apiFetch('/api/price-list/uploads?' + params.toString());
        var uploads = data.uploads || [];
        var brandSel = el.querySelector('#pl-brand-filter');
        var brands   = [...new Set(uploads.map(function(u){ return u.marka; }))].sort();
        var curBrand = brandSel.value;
        brandSel.innerHTML = '<option value="">Tüm Markalar</option>' +
          brands.map(function(b){ return '<option value="' + b + '"' + (b===curBrand?' selected':'') + '>' + b + '</option>'; }).join('');
        if (!uploads.length) {
          wrap.innerHTML = '<div style="color:#64748b;font-size:13px">Fiyat listesi bulunamadı.</div>';
          return;
        }
        // Pill-row layout: one row per brand, category pills inline
        var byBrand = {};
        uploads.forEach(function(u){ (byBrand[u.marka]=byBrand[u.marka]||[]).push(u); });
        var KS = {
          'KIS':      {bg:'rgba(59,130,246,0.1)',  bd:'rgba(59,130,246,0.3)',  c:'#60a5fa', lb:'KIŞ'},
          'YAZ':      {bg:'rgba(251,191,36,0.1)',  bd:'rgba(251,191,36,0.3)',  c:'#fbbf24', lb:'YAZ'},
          '4 MEVSIM': {bg:'rgba(167,139,250,0.1)', bd:'rgba(167,139,250,0.3)', c:'#a78bfa', lb:'4M'},
        };
        var DEF = {bg:'rgba(52,211,153,0.1)', bd:'rgba(52,211,153,0.3)', c:'#34d399', lb:null};
        var html = '<table style="width:100%;border-collapse:collapse">';
        Object.keys(byBrand).sort().forEach(function(brand) {
          var list = byBrand[brand];
          var pills = list.map(function(u) {
            var st = KS[u.kategori] || DEF;
            return '<span class="pl-pill" data-id="' + u.id + '" data-brand="' + brand + '" style="display:inline-flex;align-items:center;gap:4px;background:' + st.bg + ';border:0.5px solid ' + st.bd + ';border-radius:20px;padding:4px 11px;font-size:11px;font-weight:700;cursor:pointer;color:' + st.c + ';letter-spacing:0.3px;transition:opacity 0.15s">' +
              (st.lb || u.kategori) + ' <span style="font-weight:400;color:#64748b;font-size:10px">' + (u.kayit_sayisi||0) + '</span></span>';
          }).join('');
          html += '<tr class="pl-brand-row" data-brand="' + brand + '">' +
            '<td style="color:#64748b;font-size:10px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;padding:9px 14px 9px 0;vertical-align:middle;white-space:nowrap;width:130px;border-bottom:0.5px solid rgba(255,255,255,0.05)">' + brand + '</td>' +
            '<td style="padding:7px 0;border-bottom:0.5px solid rgba(255,255,255,0.05);vertical-align:middle"><div style="display:flex;flex-wrap:wrap;gap:6px">' + pills + '</div></td>' +
          '</tr>' +
          '<tr class="pl-expand-row" data-brand="' + brand + '" style="display:none"><td colspan="2" style="padding:0 0 10px 0"></td></tr>';
        });
        html += '</table>';
        wrap.innerHTML = html;
        el.querySelector('#pl-items-wrap').style.display = 'none';

        // Pill click → inline expand
        var activePillId = null;
        wrap.querySelectorAll('.pl-pill').forEach(function(pill) {
          pill.addEventListener('click', async function() {
            var id    = pill.dataset.id;
            var brand = pill.dataset.brand;
            var expRow = wrap.querySelector('.pl-expand-row[data-brand="' + brand + '"]');
            var expTd  = expRow ? expRow.querySelector('td') : null;
            if (!expTd) return;

            // Toggle: close if already open
            var isOpen = expRow.style.display !== 'none';
            wrap.querySelectorAll('.pl-expand-row').forEach(function(r){ r.style.display='none'; });
            wrap.querySelectorAll('.pl-pill').forEach(function(p){ p.style.outline='none'; });
            if (isOpen) return;
            pill.style.outline = '1px solid rgba(5,150,105,0.6)';
            pill.style.outlineOffset = '2px';
            expRow.style.display = '';
            var meta  = uploads.find(function(u){ return u.id === id; });
            var tarih = ((meta&&meta.liste_tarihi)||'').slice(0,10);
            expTd.innerHTML =
              '<div style="background:rgba(255,255,255,0.025);border-radius:8px;padding:12px 14px;border:0.5px solid rgba(255,255,255,0.08)">' +
                '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px">' +
                  '<div style="color:#f1f5f9;font-size:13px;font-weight:600">' + brand + ' · ' + (meta&&meta.kategori||'') + ' · ' + tarih + '</div>' +
                  '<div style="display:flex;gap:6px;align-items:center">' +
                    '<input class="pl-inline-search" type="text" placeholder="Ebat ara..." style="background:rgba(255,255,255,0.06);border:0.5px solid rgba(255,255,255,0.18);border-radius:6px;padding:4px 8px;color:#f1f5f9;font-size:11px;outline:none;width:110px">' +
                    '<button class="pl-close-inline" style="background:rgba(255,255,255,0.06);border:0.5px solid rgba(255,255,255,0.18);border-radius:6px;padding:4px 8px;color:#64748b;font-size:11px;cursor:pointer">✕</button>' +
                  '</div>' +
                '</div>' +
                getVadeHtml(brand, meta&&meta.kategori||"") + _SCENARIO_BAR + getPeriodBarHtml(brand, meta&&meta.kategori||"") + '<div class="pl-inline-table"><div style="color:#64748b;font-size:12px">Yükleniyor...</div></div>' +
              '</div>';
            expTd.querySelector('.pl-close-inline').addEventListener('click', function() {
              expRow.style.display = 'none';
              pill.style.outline = 'none';
              activePillId = null;
            });
            try {
              var data  = await apiFetch('/api/price-list/items?upload_id=' + id);
              var items = data.items || [];
              curKdvHaric = data.kdv_haric || false;
              var tbl   = expTd.querySelector('.pl-inline-table');
              // Load discount tiers from bi_fiyat_iskonto (per brand/season, cached)
              var tierKey = (meta&&meta.marka||'') + '|' + (meta&&meta.kategori||'');
              if (!plTiersCache[tierKey]) {
                try {
                  var td = await apiFetch('/api/price-list/discount-tiers?marka=' + encodeURIComponent(meta&&meta.marka||'') + '&sezon=' + encodeURIComponent(meta&&meta.kategori||''));
                  plTiersCache[tierKey] = td.tiers || [];
                } catch(_) { plTiersCache[tierKey] = []; }
              }
              plTiers = plTiersCache[tierKey];
              var curMult = 1; var curRate = 46; var curPeriod = 'A';
              renderItemsTable(tbl, items, meta, curMult, curRate, curPeriod);
              // Fetch TCMB policy rate (best-effort)
              apiFetch('/api/tcmb/policy-rate').then(function(r){
                if (r && r.rate) {
                  curRate = parseFloat(r.rate)||46;
                  var rv = expTd.querySelector('.pl-rate-val');
                  if (rv) rv.textContent = '%' + curRate;
                  var _q = expTd.querySelector('.pl-inline-search').value.trim().toLowerCase();
                  renderItemsTable(tbl, _q ? items.filter(function(i){ return (i.ebat||'').toLowerCase().includes(_q)||(i.desen||'').toLowerCase().includes(_q); }) : items, meta, curMult, curRate, curPeriod);
                }
              }).catch(function(){});
              // Rate badge click → inline edit → PUT to DB
              (function(){
                var _rv = expTd.querySelector('.pl-rate-val');
                if (!_rv) return;
                _rv.addEventListener('click', function() {
                  var inp = document.createElement('input');
                  inp.type = 'number'; inp.value = curRate; inp.step = '0.25'; inp.min = '1'; inp.max = '100';
                  inp.style.cssText = 'width:52px;background:#0f172a;border:1px solid #a78bfa;border-radius:4px;color:#a78bfa;font-size:11px;font-weight:700;padding:1px 4px;outline:none;text-align:center';
                  _rv.replaceWith(inp);
                  inp.focus(); inp.select();
                  function _applyRate() {
                    var val = parseFloat(inp.value);
                    if (!isNaN(val) && val > 0 && val < 200) {
                      curRate = val;
                      _rv.textContent = '%' + val;
                      var _si = expTd.querySelector('.pl-inline-search');
                      var _qv = _si ? _si.value.trim().toLowerCase() : '';
                      renderItemsTable(tbl, _qv ? items.filter(function(i){ return (i.ebat||'').toLowerCase().includes(_qv)||(i.desen||'').toLowerCase().includes(_qv); }) : items, meta, curMult, curRate, curPeriod);
                      // Persist to DB (fire-and-forget)
                      fetch('/api/tcmb/policy-rate', { method: 'PUT', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ rate: val }) }).catch(function(){});
                    }
                    inp.replaceWith(_rv);
                  }
                  inp.addEventListener('keydown', function(e) { if (e.key === 'Enter') { e.preventDefault(); _applyRate(); } if (e.key === 'Escape') { inp.replaceWith(_rv); } });
                  inp.addEventListener('blur', _applyRate);
                });
              })();
              var rng = expTd.querySelector('.pl-sc-range');
              var lbl = expTd.querySelector('.pl-sc-label');
              if (rng) { rng.addEventListener('input', function() {
                curMult = 1 + parseInt(rng.value)/100;
                lbl.textContent = '+' + rng.value + '%';
                lbl.style.color = parseInt(rng.value) > 0 ? '#f59e0b' : '#34d399';
                var _q = expTd.querySelector('.pl-inline-search').value.trim().toLowerCase();
                renderItemsTable(tbl, _q ? items.filter(function(i){ return (i.ebat||'').toLowerCase().includes(_q)||(i.desen||'').toLowerCase().includes(_q); }) : items, meta, curMult, curRate, curPeriod);
              }); }
              // Period switcher (shown only for LASSA/BRIDGESTONE KIŞ)
              expTd.querySelectorAll('.pl-period').forEach(function(pb) {
                pb.addEventListener('click', function() {
                  curPeriod = pb.dataset.period;
                  expTd.querySelectorAll('.pl-period').forEach(function(b){ b.style.cssText = 'background:rgba(255,255,255,0.04);border:0.5px solid rgba(255,255,255,0.1);border-radius:10px;padding:2px 10px;font-size:10px;color:#64748b;cursor:pointer'; });
                  pb.style.cssText = 'background:rgba(52,211,153,0.15);border:0.5px solid rgba(52,211,153,0.4);border-radius:10px;padding:2px 10px;font-size:10px;font-weight:700;color:#34d399;cursor:pointer';
                  var _q = expTd.querySelector('.pl-inline-search').value.trim().toLowerCase();
                  renderItemsTable(tbl, _q ? items.filter(function(i){ return (i.ebat||'').toLowerCase().includes(_q)||(i.desen||'').toLowerCase().includes(_q); }) : items, meta, curMult, curRate, curPeriod);
                });
              });
              var srch = expTd.querySelector('.pl-inline-search');
              srch.addEventListener('input', function() {
                var q = srch.value.trim().toLowerCase();
                renderItemsTable(tbl, q ? items.filter(function(i){
                  return (i.ebat||'').toLowerCase().includes(q)||(i.desen||'').toLowerCase().includes(q);
                }) : items, meta, curMult, curRate, curPeriod);
              });
                        } catch(e) {
              expTd.querySelector('.pl-inline-table').innerHTML = '<div style="color:#f87171;font-size:12px">Hata: ' + e.message + '</div>';
            }
          });
        });
      } catch(e) {
        wrap.innerHTML = '<div style="color:#f87171;font-size:13px">Hata: ' + e.message + '</div>';
      }
    }

    async function loadItems(uploadId, meta) {
      var wrap = el.querySelector('#pl-items-wrap');
      var hdr  = el.querySelector('#pl-items-header');
      var tbl  = el.querySelector('#pl-items-table');
      el.querySelector('#pl-compare-wrap').style.display = 'none';
      wrap.style.display = 'block';
      var tarih = ((meta && meta.liste_tarihi) || '').slice(0, 10);
      hdr.innerHTML =
        '<div style="display:flex;align-items:center;justify-content:space-between">' +
          '<div style="color:#f1f5f9;font-weight:700;font-size:15px">' + (meta&&meta.marka||'') + ' · ' + (meta&&meta.kategori||'') + ' · ' + tarih + '</div>' +
          '<div style="display:flex;gap:8px;align-items:center">' +
            '<input id="pl-item-search" type="text" placeholder="Ebat filtrele..." style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:5px 10px;color:#f1f5f9;font-size:12px;outline:none;width:130px">' +
            '<button onclick="this.closest(\'[id=vmo-room-price-list]\').querySelector(\'#pl-items-wrap\').style.display=\'none\'" style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:5px 10px;color:#94a3b8;font-size:12px;cursor:pointer">✕</button>' +
          '</div>' +
        '</div>';
      tbl.innerHTML = '<div style="color:#64748b;font-size:13px;padding-top:8px">Yükleniyor...</div>';
      try {
        var data  = await apiFetch('/api/price-list/items?upload_id=' + uploadId);
        var items = data.items || [];
        renderItemsTable(tbl, items);
        var searchInp = hdr.querySelector('#pl-item-search');
        searchInp.addEventListener('input', function() {
          var q = searchInp.value.trim().toLowerCase();
          var filtered = q ? items.filter(function(i){ return (i.ebat||'').toLowerCase().includes(q) || (i.desen||'').toLowerCase().includes(q); }) : items;
          renderItemsTable(tbl, filtered);
        });
      } catch(e) {
        tbl.innerHTML = '<div style="color:#f87171;font-size:13px">Hata: ' + e.message + '</div>';
      }
    }

    function pvFactor(rate, marka, kat, period) {
      var r = rate/100;
      var mu = (marka||'').toUpperCase();
      // Normalise Turkish chars for comparison
      var kn = (kat||'').toUpperCase().replace(/Ş/g,'S').replace(/İ/g,'I').replace(/Ğ/g,'G').replace(/Ü/g,'U').replace(/Ö/g,'O');
      if ((mu==='LASSA'||mu==='BRIDGESTONE') && kn.indexOf('KIS')===0) {
        // 2 taksit — Period A: Tem/Ağu/Eyl sevk → Nov 18 (d=109) + Dec 16 (d=137) from ~Aug 1
        //             Period B: Eki/Kas sevk    → Jan 22 (d=82)  + Feb 22 (d=113) from ~Nov 1
        if (period==='A') return 0.5/Math.pow(1+r,109/365)+0.5/Math.pow(1+r,137/365);
        return 0.5/Math.pow(1+r,82/365)+0.5/Math.pow(1+r,113/365);
      }
      // YAZ / 4 Mevsim: 90 gün tek ödeme
      if (kn.indexOf('YAZ')>=0||kn.indexOf('MEVSIM')>=0) return 1/Math.pow(1+r,90/365);
      // Continental grubu: 3 taksit tahmini Kas/Ara/Oca (~60/90/120 gün)
      if (mu==='CONTINENTAL'||mu==='MATADOR'||mu==='BARUM') {
        return (1/3)/Math.pow(1+r,60/365)+(1/3)/Math.pow(1+r,90/365)+(1/3)/Math.pow(1+r,120/365);
      }
      return 1;
    }
    function getPeriodBarHtml(marka, kat) {
      var mu = (marka||'').toUpperCase();
      var kn = (kat||'').toUpperCase().replace(/Ş/g,'S').replace(/İ/g,'I').replace(/Ğ/g,'G').replace(/Ü/g,'U').replace(/Ö/g,'O');
      if (!((mu==='LASSA'||mu==='BRIDGESTONE') && kn.indexOf('KIS')===0)) return '';
      var on='background:rgba(52,211,153,0.15);border:0.5px solid rgba(52,211,153,0.4);border-radius:10px;padding:2px 10px;font-size:10px;font-weight:700;color:#34d399;cursor:pointer';
      var off='background:rgba(255,255,255,0.04);border:0.5px solid rgba(255,255,255,0.1);border-radius:10px;padding:2px 10px;font-size:10px;color:#64748b;cursor:pointer';
      return '<div style="display:flex;align-items:center;gap:6px;margin-bottom:6px">' +
        '<span style="color:#475569;font-size:9px;font-weight:700;letter-spacing:0.8px;text-transform:uppercase;white-space:nowrap">Sevk Per.</span>' +
        '<span class="pl-period" data-period="A" style="'+on+'">Tem/Ağu/Eyl</span>' +
        '<span class="pl-period" data-period="B" style="'+off+'">Eki/Kas</span>' +
        '' +
        '</div>';
    }
    function renderItemsTable(tbl, items, meta, mult, rate, period) { mult=mult||1; rate=rate||46; period=period||'A';
      var kdvF = curKdvHaric ? 1.20 : 1.0; // multiply net by 1.20 when liste_fiyati is KDV Hariç
      if (!items.length) { tbl.innerHTML = '<div style="color:#64748b;font-size:13px;padding-top:8px">Sonuç yok</div>'; return; }
      var marka = (meta && meta.marka) || '';
      // Tier matching
      var findTier = function(ebat, desen, segment) {
        // plTiers already scoped to current marka+sezon (fetched from bi_fiyat_iskonto)
        if (!plTiers || !plTiers.length) return null;
        var seg = segment || 'PASSENGER';
        // 1. Match by arac_tipi (exact segment match)
        var byType = plTiers.filter(function(t){ return t.arac_tipi === seg; });
        if (byType.length === 1) return byType[0];
        if (byType.length > 1) {
          // Multiple rim tiers for this segment — pick by rim size
          var rm = (ebat||'').match(/R\s*(\d+)/i);
          var rim = rm ? parseInt(rm[1]) : 0;
          for (var i=0; i<byType.length; i++) {
            var t = byType[i];
            if (t.rim_alt !== null && rim >= parseInt(t.rim_alt||0) && (t.rim_ust === null || rim <= parseInt(t.rim_ust))) return t;
          }
          return byType[0];
        }
        // 2. Fallback: rim range across all types
        var rm2 = (ebat||'').match(/R\s*(\d+)/i);
        var rim2 = rm2 ? parseInt(rm2[1]) : 0;
        for (var j=0; j<plTiers.length; j++) {
          var tt = plTiers[j];
          if (tt.rim_alt !== null && rim2 >= parseInt(tt.rim_alt||0) && (tt.rim_ust === null || rim2 <= parseInt(tt.rim_ust))) return tt;
        }
        return plTiers[0];
      };
      var calcNet = function(t) {
        var b1=parseFloat(t.baz_iskonto1)||0, b2=parseFloat(t.baz_iskonto2)||0;
        var ds=parseFloat(t.ds)||0, sk=parseFloat(t.skala_primi)||0;
        return 1-(1-b1/100)*(1-b2/100)*(1-ds/100)*(1-sk/100);
      };
      var hasTiers = plTiers && plTiers.some(function(t){ return (parseFloat(t.baz_iskonto1)||0) > 0; });
      var html = '<table style="width:100%;border-collapse:collapse;font-size:12px"><thead><tr style="color:#475569;font-size:10px">';
      var hdrs = ['Ebat','Model','H/Y','Satış Kodu','Liste Fiyatı'];
      if (hasTiers) { hdrs.push('İndirim'); hdrs.push('Net Maliyet'); hdrs.push('Efektif'); }
      hdrs.forEach(function(h){
        var right = h==='Net Maliyet'||h==='Liste Fiyatı'||h==='Efektif';
        html += '<th style="padding:5px 8px;text-align:'+(right?'right':'left')+';border-bottom:0.5px solid rgba(255,255,255,0.08);white-space:nowrap">'+h+'</th>';
      });
      html += '</tr></thead><tbody>';
      items.forEach(function(it, i) {
        var bg = i%2===0?'rgba(255,255,255,0.02)':'transparent';
        var liste = it.liste_fiyati ? Math.round(parseFloat(it.liste_fiyati)*mult) : null;
        var listeStr = liste ? liste.toLocaleString('tr-TR',{minimumFractionDigits:0})+' ₺' : '—';
        var iskCell = '', netCell = '', efektifCell = '';
        if (hasTiers) {
          var tier = findTier(it.ebat, it.desen, it.segment);
          if (tier && (parseFloat(tier.baz_iskonto1)||0) > 0) {
            var nd = calcNet(tier);
            var net = liste ? Math.round(liste*(1-nd)*kdvF) : null;
            iskCell = '<td style="padding:5px 8px;color:#fbbf24;font-size:10px;white-space:nowrap">%'+(nd*100).toFixed(1)+'</td>';
            netCell = '<td style="padding:5px 8px;color:#4ade80;font-weight:700;text-align:right">'+(net?net.toLocaleString('tr-TR')+' ₺':'—')+'</td>';
            var pv = pvFactor(rate, marka, meta&&meta.kategori||'', period);
            var efektif = net ? Math.round(net*pv) : null;
            efektifCell = '<td style="padding:5px 8px;color:#818cf8;font-weight:700;text-align:right" title="Net maliyet x PV faktörü (@TCMB "+rate+"%)">'+(efektif?efektif.toLocaleString('tr-TR')+' ₺':'—')+'</td>';
          } else {
            iskCell = '<td style="padding:5px 8px;color:#334155;font-size:10px">—</td>';
            netCell = '<td style="padding:5px 8px;color:#334155;text-align:right">—</td>';
            efektifCell = '<td style="padding:5px 8px;color:#334155;text-align:right">—</td>';
          }
        }
        html += '<tr style="background:'+bg+'">' +
          '<td style="padding:5px 8px;color:#34d399;font-weight:600;white-space:nowrap">'+(it.ebat||'—')+'</td>' +
          '<td style="padding:5px 8px;color:#94a3b8;white-space:nowrap">'+(it.desen||'—')+'</td>' +
          '<td style="padding:5px 8px;color:#64748b">'+(it.hiz_yuk||'—')+'</td>' +
          '<td style="padding:5px 8px;color:#475569;font-size:10px">'+(it.urun_kodu||'—')+'</td>' +
          '<td style="padding:5px 8px;color:'+(mult>1?'#f59e0b':'#f1f5f9')+';font-weight:600;text-align:right">'+listeStr+'</td>' +
          iskCell + netCell + efektifCell +
        '</tr>';
      });
      html += '</tbody></table>';
      tbl.innerHTML = html;
    }

    async function runCompare() {
      var ebat = el.querySelector('#pl-ebat-inp').value.trim();
      if (!ebat) return;
      var wrap = el.querySelector('#pl-compare-wrap');
      var res  = el.querySelector('#pl-compare-results');
      el.querySelector('#pl-items-wrap').style.display = 'none';
      wrap.style.display = 'block';
      res.innerHTML = '<div style="color:#64748b;font-size:13px">Karşılaştırılıyor...</div>';
      try {
        var data = await apiFetch('/api/price-list/compare?ebat=' + encodeURIComponent(ebat));
        var rows = data.rows || [];
        if (!rows.length) {
          res.innerHTML = '<div style="color:#64748b;font-size:13px">"' + ebat + '" için fiyat bulunamadı.</div>';
          return;
        }
        var minFiyat = Math.min.apply(null, rows.map(function(r){ return parseFloat(r.liste_fiyati)||Infinity; }));
        var html = '<div style="color:#f1f5f9;font-weight:700;font-size:15px;margin-bottom:12px">🔍 ' + ebat + ' — ' + rows.length + ' sonuç</div>';
        html += '<table style="width:100%;border-collapse:collapse;font-size:13px"><thead><tr style="color:#64748b;font-size:11px">';
        ['Marka','Kategori','Liste Tarihi','Model','Hız/Yük','Fiyat (TL)'].forEach(function(h){
          html += '<th style="padding:6px 10px;text-align:left;border-bottom:1px solid rgba(255,255,255,0.08)">' + h + '</th>';
        });
        html += '</tr></thead><tbody>';
        rows.forEach(function(r, i) {
          var bg     = i%2===0 ? 'rgba(255,255,255,0.02)' : 'transparent';
          var fiyat  = r.liste_fiyati ? parseFloat(r.liste_fiyati) : null;
          var fStr   = fiyat ? fiyat.toLocaleString('tr-TR',{minimumFractionDigits:0}) + ' ₺' : '—';
          var isBest = fiyat && fiyat === minFiyat;
          var tarih  = (r.liste_tarihi||'').slice(0,10);
          html += '<tr style="background:' + bg + '">' +
            '<td style="padding:6px 10px;color:#f1f5f9;font-weight:700">' + r.marka + '</td>' +
            '<td style="padding:6px 10px;color:#94a3b8">' + r.kategori + '</td>' +
            '<td style="padding:6px 10px;color:#64748b">' + tarih + '</td>' +
            '<td style="padding:6px 10px;color:#94a3b8">' + (r.desen||'—') + '</td>' +
            '<td style="padding:6px 10px;color:#64748b">' + (r.hiz_yuk||'—') + '</td>' +
            '<td style="padding:6px 10px;font-weight:700;text-align:right;color:' + (isBest?'#4ade80':'#f1f5f9') + '">' + fStr + (isBest?' ✓':'') + '</td>' +
          '</tr>';
        });
        html += '</tbody></table>';
        html += '<button onclick="this.parentElement.parentElement.style.display=\'none\'" style="margin-top:12px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:5px 12px;color:#94a3b8;font-size:12px;cursor:pointer">✕ Kapat</button>';
        res.innerHTML = html;
      } catch(e) {
        res.innerHTML = '<div style="color:#f87171;font-size:13px">Hata: ' + e.message + '</div>';
      }
    }


    // ── İndirim Yapısı button + panel ────────────────────────────────────────
    el.querySelector('#pl-toggle-lists').insertAdjacentHTML('afterend',
      '<button id="pl-iskonto-btn" style="background:rgba(255,255,255,0.05);border:0.5px solid rgba(255,255,255,0.15);border-radius:6px;padding:5px 12px;color:#fbbf24;font-size:12px;cursor:pointer;font-weight:600;white-space:nowrap">⚙️ İndirim Yapısı ▾</button>' +
      '<button id="pl-index-btn" style="background:rgba(99,102,241,0.1);border:0.5px solid rgba(99,102,241,0.3);border-radius:6px;padding:5px 12px;color:#a5b4fc;font-size:12px;cursor:pointer;font-weight:600;white-space:nowrap">📊 Fiyat Endeksi ▴</button>'
    );
    el.querySelector('div').insertAdjacentHTML('beforeend',
      '<div id="pl-index-wrap" style="margin-top:8px"></div>'
    );
    el.querySelector('div').insertAdjacentHTML('beforeend',
      '<div id="pl-iskonto-wrap" style="display:none;margin-top:24px;padding-top:22px;border-top:1px solid rgba(255,255,255,0.1)">' +
        '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px">' +
          '<div style="color:#f1f5f9;font-weight:700;font-size:15px">💰 Tedarikçi İndirim Yapısı</div>' +
          '<div style="display:flex;gap:8px;align-items:center">' +
            '<button id="pl-add-iskonto-btn" style="background:rgba(5,150,105,0.15);border:1px solid rgba(5,150,105,0.4);border-radius:6px;padding:4px 12px;color:#34d399;font-size:12px;cursor:pointer">+ Yeni Tier</button>' +
            '<button onclick="this.closest(\'[id]\').querySelector(\'#pl-iskonto-wrap\').style.display=\'none\'" style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:4px 10px;color:#64748b;font-size:11px;cursor:pointer">✕</button>' +
          '</div>' +
        '</div>' +
        '<div style="color:#64748b;font-size:11px;margin-bottom:12px">Net iskonto = (1−Baz1) × (1−Baz2) × (1−DS) bileşik. Skala primi ayrıca yıl sonu bonusu.</div>' +
        '<div id="pl-iskonto-table"><div style="color:#64748b;font-size:13px">Yükleniyor...</div></div>' +
        '<div id="pl-add-iskonto-form" style="display:none;margin-top:16px;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.1);border-radius:10px;padding:16px">' +
          '<div style="color:#f1f5f9;font-weight:600;font-size:13px;margin-bottom:12px">Yeni İndirim Tieri</div>' +
          '<div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;margin-bottom:12px">' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">Marka *</div><input id="fi-marka" type="text" placeholder="LASSA" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">Segment Adı *</div><input id="fi-seg" type="text" placeholder="LVR (13-16 Jant)" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">Baz İsk.1 %</div><input id="fi-b1" type="number" step="0.1" placeholder="35" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">Baz İsk.2 %</div><input id="fi-b2" type="number" step="0.1" placeholder="0" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">DS %</div><input id="fi-ds" type="number" step="0.1" placeholder="0" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">Skala Primi %</div><input id="fi-sk" type="number" step="0.1" placeholder="0" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">Rim Minimum (ör: 13)</div><input id="fi-ralt" type="number" placeholder="" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">Rim Maksimum (ör: 16)</div><input id="fi-rust" type="number" placeholder="" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
            '<div><div style="color:#64748b;font-size:10px;margin-bottom:3px">Not</div><input id="fi-nota" type="text" placeholder="İsteğe bağlı" style="width:100%;box-sizing:border-box;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:6px 8px;color:#f1f5f9;font-size:12px;outline:none"></div>' +
          '</div>' +
          '<div style="display:flex;gap:8px;align-items:center">' +
            '<button id="fi-save-btn" style="background:#059669;border:none;border-radius:6px;padding:7px 18px;color:#fff;font-size:13px;cursor:pointer;font-weight:600">Kaydet</button>' +
            '<button id="fi-cancel-btn" style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:7px 14px;color:#94a3b8;font-size:12px;cursor:pointer">İptal</button>' +
            '<div id="fi-msg" style="font-size:12px;margin-left:8px"></div>' +
          '</div>' +
        '</div>' +
      '</div>'
    );

    async function loadIncentives() {
      var tbl = el.querySelector('#pl-iskonto-table');
      if (!tbl) return;

      var _tiers = [];

      // ── Style tokens ────────────────────────────────────────────────────────
      var S = {
        btn:  'background:rgba(255,255,255,0.08);border:0.5px solid rgba(255,255,255,0.18);border-radius:4px;padding:3px 9px;font-size:11px;cursor:pointer;color:#94a3b8',
        save: 'background:rgba(52,211,153,0.15);border:0.5px solid rgba(52,211,153,0.4);border-radius:4px;padding:3px 9px;font-size:11px;cursor:pointer;color:#34d399',
        del:  'background:rgba(248,113,113,0.1);border:0.5px solid rgba(248,113,113,0.3);border-radius:4px;padding:3px 9px;font-size:11px;cursor:pointer;color:#f87171',
        add:  'background:rgba(99,102,241,0.12);border:0.5px solid rgba(99,102,241,0.35);border-radius:4px;padding:3px 10px;font-size:11px;cursor:pointer;color:#818cf8;margin-top:6px',
        inp:  'background:rgba(255,255,255,0.06);border:0.5px solid rgba(255,255,255,0.15);border-radius:3px;color:#f1f5f9;font-size:11px;padding:2px 5px;width:100%;box-sizing:border-box',
        sel:  'background:#1e293b;border:0.5px solid rgba(255,255,255,0.2);border-radius:3px;color:#f1f5f9;font-size:11px;padding:2px 4px'
      };

      // ── Helpers ─────────────────────────────────────────────────────────────
      function atLbl(v) { return { BINEK:'Binek', SUV:'SUV', HAFIF_TICARI:'Hafif Ticari', OTOBUS:'Otobüs', KAMYON:'Kamyon', IS_MAKINESI:'İş Makinesi', TUM:'Tümü',
                                   PASSENGER:'Binek', LT:'Hafif Ticari' }[v] || v; } // PASSENGER/LT kept for backward compat
      function szLbl(v) { return { KIS:'Kış', YAZ:'Yaz', '4MEVSIM':'4 Mevsim', TUM:'Tüm Sezon' }[v] || v; }
      function rimLbl(a, u) {
        a = a != null ? parseInt(a) : null;
        u = u != null ? parseInt(u) : null;
        if (a === null && u === null) return 'Tümü';
        if (a === null) return '≤' + u + '"';
        if (u === null) return a + '"+';
        return a + '"–' + u + '"';
      }
      function netPct(t) {
        var b1=parseFloat(t.baz_iskonto1)||0, b2=parseFloat(t.baz_iskonto2)||0;
        var ds=parseFloat(t.ds)||0, sk=parseFloat(t.skala_primi)||0;
        return ((1-(1-b1/100)*(1-b2/100)*(1-ds/100)*(1-sk/100))*100).toFixed(1);
      }
      function pFmt(v) {
        return v > 0
          ? '<span style="color:#fbbf24;font-weight:600">%' + v + '</span>'
          : '<span style="color:#334155">—</span>';
      }
      function atSel(cur) {
        return ['PASSENGER','SUV','LT','TUM'].map(function(v) {
          return '<option value="' + v + '"' + (cur===v?' selected':'') + '>' + atLbl(v) + '</option>';
        }).join('');
      }
      function szSel(cur) {
        return ['TUM','YAZ','KIS','4MEVSIM'].map(function(v) {
          return '<option value="' + v + '"' + (cur===v?' selected':'') + '>' + szLbl(v) + '</option>';
        }).join('');
      }

      // ── Form row (edit or new) ───────────────────────────────────────────────
      function formRowHtml(t, marka) {
        var id = t ? t.id : '';
        var at = t ? (t.arac_tipi || 'PASSENGER') : 'PASSENGER';
        var sz = t ? (t.sezon     || 'TUM')        : 'TUM';
        var ra = t && t.rim_alt != null ? t.rim_alt : '';
        var ru = t && t.rim_ust != null ? t.rim_ust : '';
        var b1 = t ? (parseFloat(t.baz_iskonto1)||0) : 0;
        var b2 = t ? (parseFloat(t.baz_iskonto2)||0) : 0;
        var ds = t ? (parseFloat(t.ds)||0)           : 0;
        var sk = t ? (parseFloat(t.skala_primi)||0)  : 0;
        var nt = t ? (t.notlar || '')                : '';
        var ni = S.inp + ';width:50px';
        return '<tr class="isk-form-row" data-id="' + id + '" data-marka="' + marka + '">' +
          '<td style="padding:4px 4px"><select class="isk-at" style="' + S.sel + '">' + atSel(at) + '</select></td>' +
          '<td style="padding:4px 4px"><select class="isk-sz" style="' + S.sel + '">' + szSel(sz) + '</select></td>' +
          '<td style="padding:4px 4px;white-space:nowrap">' +
            '<input class="isk-ra" type="number" min="13" max="30" value="' + ra + '" placeholder="min" style="' + ni + '"> ' +
            '<input class="isk-ru" type="number" min="13" max="30" value="' + ru + '" placeholder="max" style="' + ni + '"></td>' +
          '<td style="padding:4px 3px"><input class="isk-b1" type="number" min="0" max="100" step="0.5" value="' + b1 + '" style="' + ni + '"></td>' +
          '<td style="padding:4px 3px"><input class="isk-b2" type="number" min="0" max="100" step="0.5" value="' + b2 + '" style="' + ni + '"></td>' +
          '<td style="padding:4px 3px"><input class="isk-ds" type="number" min="0" max="100" step="0.5" value="' + ds + '" style="' + ni + '"></td>' +
          '<td style="padding:4px 3px"><input class="isk-sk" type="number" min="0" max="100" step="0.5" value="' + sk + '" style="' + ni + '"></td>' +
          '<td style="padding:4px 4px" colspan="2"><input class="isk-nt" type="text" value="' + nt + '" placeholder="Notlar" style="' + S.inp + '"></td>' +
          '<td style="padding:4px 6px;white-space:nowrap">' +
            '<button class="isk-save-btn" style="' + S.save + '">Kaydet</button> ' +
            '<button class="isk-cancel-btn" style="' + S.btn + '">İptal</button></td>' +
          '</tr>';
      }

      // ── Collect form data from a form row ────────────────────────────────────
      function formData(row) {
        var ra = row.querySelector('.isk-ra').value;
        var ru = row.querySelector('.isk-ru').value;
        return {
          marka:        row.dataset.marka,
          sezon:        row.querySelector('.isk-sz').value,
          arac_tipi:    row.querySelector('.isk-at').value,
          rim_alt:      ra !== '' ? parseInt(ra) : null,
          rim_ust:      ru !== '' ? parseInt(ru) : null,
          desen_filtre: null,
          baz_iskonto1: parseFloat(row.querySelector('.isk-b1').value) || 0,
          baz_iskonto2: parseFloat(row.querySelector('.isk-b2').value) || 0,
          ds:           parseFloat(row.querySelector('.isk-ds').value) || 0,
          skala_primi:  parseFloat(row.querySelector('.isk-sk').value) || 0,
          notlar:       row.querySelector('.isk-nt').value || null
        };
      }

      // ── Render full table ────────────────────────────────────────────────────
      function render() {
        if (!_tiers.length) {
          tbl.innerHTML =
            '<div style="color:#64748b;font-size:13px;margin-bottom:10px">Tanımlı indirim yok.</div>' +
            '<button class="isk-add-global" style="' + S.add + '">+ Yeni Marka Tier Ekle</button>';
          tbl.querySelector('.isk-add-global').addEventListener('click', function() {
            var marka = (prompt('Marka adı (büyük harf):') || '').toUpperCase().trim();
            if (!marka) return;
            showAddForm(null, marka);
          });
          return;
        }

        var byBrand = {};
        _tiers.forEach(function(t) { (byBrand[t.marka] = byBrand[t.marka] || []).push(t); });

        var html = '';
        Object.entries(byBrand).forEach(function(entry) {
          var brand = entry[0]; var bt = entry[1];
          html += '<div class="isk-brand-block" data-marka="' + brand + '" style="margin-bottom:22px">';
          html += '<div style="color:#94a3b8;font-size:10px;font-weight:700;letter-spacing:1.5px;margin-bottom:6px;text-transform:uppercase">' + brand + '</div>';
          html += '<table style="width:100%;border-collapse:collapse;font-size:12px">';
          html += '<thead><tr style="color:#475569;font-size:10px">';
          ['Araç Tipi','Sezon','Jant Aralığı','Baz İsk.1','Baz İsk.2','DS','Skala','Net İskonto','Notlar',''].forEach(function(h) {
            html += '<th style="padding:4px 4px;text-align:left;border-bottom:1px solid rgba(255,255,255,0.07)">' + h + '</th>';
          });
          html += '</tr></thead><tbody class="isk-tbody">';
          bt.forEach(function(t, i) {
            var bg  = i % 2 === 0 ? 'rgba(255,255,255,0.02)' : 'transparent';
            var net = netPct(t);
            var nc  = parseFloat(net) > 0 ? '#4ade80' : '#475569';
            html += '<tr style="background:' + bg + '" data-id="' + t.id + '">' +
              '<td style="padding:5px 4px;color:#f1f5f9">' + atLbl(t.arac_tipi || 'PASSENGER') + '</td>' +
              '<td style="padding:5px 4px;color:#94a3b8;font-size:11px">' + szLbl(t.sezon || 'TUM') + '</td>' +
              '<td style="padding:5px 4px;color:#64748b;font-size:11px">' + rimLbl(t.rim_alt, t.rim_ust) + '</td>' +
              '<td style="padding:5px 4px">' + pFmt(parseFloat(t.baz_iskonto1)||0) + '</td>' +
              '<td style="padding:5px 4px">' + pFmt(parseFloat(t.baz_iskonto2)||0) + '</td>' +
              '<td style="padding:5px 4px">' + pFmt(parseFloat(t.ds)||0) + '</td>' +
              '<td style="padding:5px 4px">' + pFmt(parseFloat(t.skala_primi)||0) + '</td>' +
              '<td style="padding:5px 4px;font-weight:700;color:' + nc + '">%' + net + '</td>' +
              '<td style="padding:5px 4px;color:#475569;font-size:10px;font-style:italic">' + (t.notlar||'') + '</td>' +
              '<td style="padding:5px 6px;white-space:nowrap">' +
                '<button class="isk-edit" data-id="' + t.id + '" data-marka="' + brand + '" style="' + S.btn + '">Düzenle</button> ' +
                '<button class="isk-copy" data-id="' + t.id + '" data-marka="' + brand + '" style="' + S.btn + '">Kopyala</button> ' +
                '<button class="isk-del" data-id="' + t.id + '" style="' + S.del + '">Sil</button>' +
              '</td></tr>';
          });
          html += '</tbody></table>';
          html += '<button class="isk-add" data-marka="' + brand + '" style="' + S.add + '">+ Yeni Tier</button>';
          html += '</div>';
        });
        tbl.innerHTML = html;

        // ── Wire events ─────────────────────────────────────────────────────────
        tbl.querySelectorAll('.isk-edit').forEach(function(btn) {
          btn.addEventListener('click', function() {
            var id    = btn.dataset.id;
            var marka = btn.dataset.marka;
            var t     = _tiers.find(function(x) { return x.id === id; });
            if (!t) return;
            var row = tbl.querySelector('tr[data-id="' + id + '"]');
            if (!row) return;
            row.outerHTML = formRowHtml(t, marka);
            wireFormRow(tbl.querySelector('.isk-form-row[data-id="' + id + '"]'));
          });
        });

        tbl.querySelectorAll('.isk-del').forEach(function(btn) {
          btn.addEventListener('click', async function() {
            if (!confirm('Bu tier silinsin mi?')) return;
            try {
              await apiFetch('/api/price-list/incentives/' + btn.dataset.id, { method:'DELETE' });
              await reload();
            } catch(e) { alert('Silme hatası: ' + e.message); }
          });
        });

        tbl.querySelectorAll('.isk-copy').forEach(function(btn) {
          btn.addEventListener('click', function() {
            var id    = btn.dataset.id;
            var marka = btn.dataset.marka;
            var t     = _tiers.find(function(x) { return x.id === id; });
            if (!t) return;
            // Open a pre-filled form with no id → saves as new row via POST
            var block = tbl.querySelector('.isk-brand-block[data-marka="' + marka + '"]');
            if (!block) return;
            var tbody = block.querySelector('.isk-tbody');
            var tmp   = document.createElement('tbody');
            tmp.innerHTML = formRowHtml(t, marka);
            var newRow = tmp.querySelector('tr');
            newRow.dataset.id = '';  // clear id so save goes to POST
            tbody.appendChild(newRow);
            wireFormRow(newRow);
            newRow.scrollIntoView({ behavior:'smooth', block:'nearest' });
          });
        });

        tbl.querySelectorAll('.isk-add').forEach(function(btn) {
          btn.addEventListener('click', function() { showAddForm(btn, btn.dataset.marka); });
        });
      }

      // ── Wire save/cancel on a form row ───────────────────────────────────────
      function wireFormRow(row) {
        if (!row) return;
        row.querySelector('.isk-save-btn').addEventListener('click', async function() {
          var id = row.dataset.id;
          var d  = formData(row);
          try {
            if (id) {
              await apiFetch('/api/price-list/incentives/' + id, { method:'PUT', body:JSON.stringify(d) });
            } else {
              await apiFetch('/api/price-list/incentives', { method:'POST', body:JSON.stringify(d) });
            }
            await reload();
          } catch(e) { alert('Kayıt hatası: ' + e.message); }
        });
        row.querySelector('.isk-cancel-btn').addEventListener('click', function() { render(); });
      }

      // ── Show add form below the brand's table ────────────────────────────────
      function showAddForm(btn, marka) {
        // Replace the + button with a blank form row appended to the brand tbody
        var block = tbl.querySelector('.isk-brand-block[data-marka="' + marka + '"]');
        if (!block) return;
        // Remove any existing add form for this brand
        var existing = block.querySelector('.isk-form-row[data-id=""]');
        if (existing) { existing.closest('tr') && existing.closest('tr').remove(); }
        var tbody = block.querySelector('.isk-tbody');
        var tmp = document.createElement('tbody');
        tmp.innerHTML = formRowHtml(null, marka);
        var newRow = tmp.querySelector('tr');
        tbody.appendChild(newRow);
        wireFormRow(newRow);
        newRow.querySelector('.isk-at').focus();
      }

      // ── Reload from API ──────────────────────────────────────────────────────
      async function reload() {
        tbl.innerHTML = '<div style="color:#64748b;font-size:13px">Yükleniyor...</div>';
        try {
          var data = await apiFetch('/api/price-list/incentives');
          _tiers = data.tiers || [];
          render();
        } catch(e) {
          tbl.innerHTML = '<div style="color:#f87171;font-size:13px">Hata: ' + e.message + '</div>';
        }
      }

      reload();
    }

    el.querySelector('#pl-iskonto-btn').addEventListener('click', async function() {
      var w = el.querySelector('#pl-iskonto-wrap');
      var btn = el.querySelector('#pl-iskonto-btn');
      if (w.style.display==='none') {
        w.style.display='block';
        btn.textContent='⚙️ İndirim Yapısı ▴'; btn.style.color='#f1f5f9';
        await loadIncentives();
      } else {
        w.style.display='none';
        btn.textContent='⚙️ İndirim Yapısı ▾'; btn.style.color='#fbbf24';
      }
    });
    el.querySelector('#pl-toggle-lists').addEventListener('click', function() {
      var p = el.querySelector('#pl-lists-panel');
      var b = el.querySelector('#pl-toggle-lists');
      var open = p.style.display !== 'none';
      p.style.display = open ? 'none' : 'block';
      b.textContent = open ? '📋 Fiyat Listeleri ▾' : '📋 Fiyat Listeleri ▴';
      b.style.color  = open ? '#94a3b8' : '#f1f5f9';
    });
    el.querySelector('#pl-index-btn').addEventListener('click', function() {
      var w   = el.querySelector('#pl-index-wrap');
      var btn = el.querySelector('#pl-index-btn');
      var open = w.style.display !== 'none';
      w.style.display = open ? 'none' : '';
      btn.textContent = open ? '📊 Fiyat Endeksi ▾' : '📊 Fiyat Endeksi ▴';
      btn.style.color      = open ? '#64748b'              : '#a5b4fc';
      btn.style.background = open ? 'rgba(255,255,255,0.05)' : 'rgba(99,102,241,0.1)';
      btn.style.borderColor= open ? 'rgba(255,255,255,0.15)' : 'rgba(99,102,241,0.3)';
    });

    // ── Fiyat Endeksi ─────────────────────────────────────────────────────
    // Auto-load Fiyat Endeksi when room opens
    setTimeout(async function() {
      var w = el.querySelector('#pl-index-wrap');
      if (w && !w._loaded) await _piLoadData(w);
    }, 0);

    async function _piLoadData(wrap) {
      wrap.innerHTML = '<div style="color:#64748b;font-size:13px;padding:20px 0">Yükleniyor...</div>';
      try {
        // Fetch data and vehicle taxonomy in parallel
        var results = await Promise.all([
          apiFetch('/api/price-list/index-data'),
          apiFetch('/api/price-list/arac-kategorileri')
        ]);
        var d   = results[0];
        var kat = results[1];
        wrap._items   = d.items   || [];
        wrap._iskonto = d.iskonto || [];
        wrap._tesvik  = d.tesvik  || [];
        // aracKat drives all segment filter buttons — [{id, label_tr, label_en, sort_order}]
        wrap._aracKat = kat.kategoriler || [{id:'BINEK',label_tr:'Binek'},{id:'SUV',label_tr:'SUV'},{id:'HAFIF_TICARI',label_tr:'Hafif Ticari'}];
        wrap._loaded  = true;
        _piRender(wrap);
      } catch(e) {
        wrap.innerHTML = '<div style="color:#f87171;font-size:13px">Hata: ' + e.message + '</div>';
      }
    }

    function _piClassify(ebat, desen) {
      var norm = (ebat||'');
      var rm   = norm.match(/R([0-9][0-9])/i);
      var rim  = rm ? parseInt(rm[1]) : 0;
      var d    = (desen||'').toUpperCase();
      var isLT  = /C$/.test(norm) || d.indexOf(' LT') >= 0 || d.indexOf('LT ') >= 0 || d === 'LT' || d.indexOf('VAN') >= 0;
      var isSUV = d.indexOf('SUV') >= 0 || d.indexOf('4X4') >= 0 || d.indexOf('CROSSCONTACT') >= 0 ||
                  d.indexOf('GRABBER') >= 0 || d.indexOf('DUELER') >= 0 || d.indexOf('SCORPION') >= 0 ||
                  d.indexOf('GEOLANDAR') >= 0 || d.indexOf('WILDPEAK') >= 0 || d.indexOf('LATITUDE') >= 0 ||
                  d.indexOf('DISCOVERER') >= 0 || d.indexOf('KROSSOVER') >= 0;
      var vtype = isLT ? 'lt' : isSUV ? 'suv' : 'passenger';
      var rg = rim <= 16 ? '13-16' : rim === 17 ? '17' : rim === 18 ? '18' : rim === 19 ? '19' : rim === 20 ? '20' : '21+';
      return { rim: rim, rimGroup: rg, rimPlus: rim >= 17, vehicleType: vtype };
    }

    function _piRender(wrap) {
      var costType  = wrap._costType || 'net';
      var rimGrp    = wrap._rimGrp   || 'all';
      var segFlt    = wrap._segFlt   || 'all';
      var katFlt    = wrap._katFlt   || 'all';
      var _modelSel = wrap._modelSel = wrap._modelSel || {};
      var _expCell  = wrap._expCell  || null;
      var zamSen    = wrap._zamSen   || {};
      var zamOn     = wrap._zamOn    || false;
      var ebatSearch= wrap._ebatSearch|| '';
      var _piView   = wrap._piView   || 'endeks';

      var items   = wrap._items   || [];
      var iskonto = wrap._iskonto || [];
      var tesvik  = wrap._tesvik  || [];

      var ON  = 'background:rgba(255,255,255,0.12);border:0.5px solid rgba(255,255,255,0.25);border-radius:5px;padding:4px 11px;font-size:12px;color:#f1f5f9;cursor:pointer;font-weight:600';
      var OFF = 'background:rgba(255,255,255,0.04);border:0.5px solid rgba(255,255,255,0.1);border-radius:5px;padding:4px 11px;font-size:12px;color:#64748b;cursor:pointer';

      function getRim(eb) { var m=(eb||'').match(/R\s*(\d+)/i); return m?parseInt(m[1]):0; }
      function mapSez(k)  { return k==='4 MEVSIM'?'4MEVSIM':k; }

      function getNet(br, rim, seg, kat, liste) {
        var sz=mapSez(kat);
        // Map new taxonomy IDs back to old values for iskonto rows not yet migrated in DB
        var _segOld={BINEK:'PASSENGER',HAFIF_TICARI:'LT',SUV:'SUV'}[seg]||seg;
        var ts=iskonto.filter(function(t) {
          if(t.marka!==br) return false;
          var ao=!t.arac_tipi||t.arac_tipi==='TUM'||t.arac_tipi===seg||t.arac_tipi===_segOld;
          var so=!t.sezon||t.sezon==='TUM'||t.sezon===sz;
          return ao&&so;
        });
        if(!ts.length) return liste;
        var t=ts.find(function(t){
          var ao=t.rim_alt==null||rim>=parseInt(t.rim_alt);
          var uo=t.rim_ust==null||rim<=parseInt(t.rim_ust);
          return ao&&uo;
        });
        if(!t) t=ts.find(function(t){return t.rim_alt==null&&t.rim_ust==null;});
        if(!t) t=ts[0];
        if(!t) return liste;
        var b1=parseFloat(t.baz_iskonto1)||0, b2=parseFloat(t.baz_iskonto2)||0;
        var ds=parseFloat(t.ds)||0, sk=parseFloat(t.skala_primi)||0;
        return liste*(1-b1/100)*(1-b2/100)*(1-ds/100)*(1-sk/100);
      }

      function getEfk(br, kat, liste) {
        var sm={'KIS':'KIS','YAZ':'YAZ','4 MEVSIM':'YAZ'};
        var t=tesvik.find(function(t){return t.marka===br&&t.sezon===(sm[kat]||kat);});
        if(!t) return null;
        return liste*(1-(parseFloat(t.max_toplam_pct)||0)/100);
      }

      // Build bySegKat[seg][kat][ebat] = { brands:{br:{liste,cost}}, brandItems:{br:[{desen,liste,cost}]} }
      var bySegKat={}, allBrands=[];
      items.forEach(function(it) {
        var seg=it.arac_tipi||'BINEK'; // set at upload/item level via bi_arac_kategorileri
        var kat=(it.kategori||'KIS').replace(/\s+/g,''); // normalize: '4 MEVSIM' → '4MEVSIM'
        var eb=it.ebat, br=(it.marka||'').toUpperCase();
        if(!eb||!br) return;
        var rim=getRim(eb);
        if(rimGrp==='13-16'&&(rim<13||rim>16)) return;
        if(rimGrp==='17+'&&rim<17) return;
        if(allBrands.indexOf(br)===-1) allBrands.push(br);
        if(!bySegKat[seg]) bySegKat[seg]={};
        if(!bySegKat[seg][kat]) bySegKat[seg][kat]={};
        if(!bySegKat[seg][kat][eb]) bySegKat[seg][kat][eb]={brands:{},brandItems:{}};
        var liste=(parseFloat(it.liste_fiyati)||0)*(it.kdv_haric?1.20:1.0);
        if(!liste) return;
        // Track all desens per brand for picker
        if(!bySegKat[seg][kat][eb].brandItems[br]) bySegKat[seg][kat][eb].brandItems[br]=[];
        var iList=bySegKat[seg][kat][eb].brandItems[br];
        var _idk=(it.desen||'')+'|'+(it.hiz_yuk||'');
        if(!iList.find(function(x){return x._dk===_idk;})) {
          var iNet=getNet(br,rim,seg,kat,liste);
          var iEfk=getEfk(br,kat,liste);
          var iCost=costType==='efektif'&&iEfk!==null?iEfk:iNet;
          iList.push({_dk:_idk,desen:it.desen||'',hiz_yuk:it.hiz_yuk||'',liste:Math.round(liste),cost:iCost});
        }
        // Keep cheapest as default brand price
        var ex=bySegKat[seg][kat][eb].brands[br];
        if(!ex||liste<ex.liste) {
          var net=getNet(br,rim,seg,kat,liste);
          var efk=getEfk(br,kat,liste);
          var cost=costType==='efektif'&&efk!==null?efk:net;
          bySegKat[seg][kat][eb].brands[br]={liste:liste,cost:cost};
        }
      });

      allBrands.sort(function(a,b){if(a==='LASSA')return -1;if(b==='LASSA')return 1;return a.localeCompare(b);});
      var _piFlat=[];Object.keys(bySegKat).forEach(function(sg){Object.keys(bySegKat[sg]).forEach(function(kt){Object.keys(bySegKat[sg][kt]).forEach(function(eb){var slot=bySegKat[sg][kt][eb];Object.keys(slot.brands).forEach(function(br){var b=slot.brands[br];var _fitms=(slot.brandItems&&slot.brandItems[br])||[];var _fchp=_fitms.length?_fitms.reduce(function(m,x){return x.cost<m.cost?x:m;},_fitms[0]):null;var _fdes=_fchp?(((_fchp.desen||'')+(_fchp.hiz_yuk?' '+_fchp.hiz_yuk:'')).trim()):'';_piFlat.push({marka:br,ebat:eb,sezon:kt,seg:sg,net:b.cost,liste:b.liste||0,desen:_fdes,nItems:_fitms.length});});});});});wrap._piFlat=_piFlat;
      if(!wrap._salesVol&&!wrap._svLoading){wrap._svLoading=true;apiFetch('/api/price-list/sales-volume').then(function(d){wrap._salesVol=d.items||[];wrap._svLoading=false;if(wrap._piView==='firsat')_piRender(wrap);}).catch(function(){wrap._svLoading=false;wrap._salesVol=null;if(!wrap._svRetried){wrap._svRetried=true;setTimeout(function(){if(wrap._piView==='firsat')_piRender(wrap);},2000);}});}

      // Build heatmap for a seg+kat slice
      function heatmap(ebatData, hseg, hkat) {
        var brands=allBrands.filter(function(b){
          return Object.keys(ebatData).some(function(sz){
            return ebatData[sz]&&ebatData[sz].brands&&ebatData[sz].brands[b];
          });
        });
        var sizes=Object.keys(ebatData).sort(function(a,b){
          var ra=getRim(a),rb=getRim(b); return ra!==rb?ra-rb:a.localeCompare(b);
        });
        var grid={};
        sizes.forEach(function(sz){
          var slot=ebatData[sz]||{brands:{},brandItems:{}};
          var lSlot=slot.brands['LASSA']||null;
          var lSelKey=(hseg||'')+'|'+(hkat||'')+'|'+sz+'|LASSA';
          var lSel=_modelSel[lSelKey];
          var lRaw=lSlot?lSlot.cost:0;
          if(lSel){var lf=(slot.brandItems['LASSA']||[]).find(function(x){return x._dk===lSel;});if(lf)lRaw=lf.cost;}
          var lz=1+((zamSen['LASSA']||0)/100);
          grid[sz]={};
          brands.forEach(function(b){
            var bSlot=slot.brands[b]; if(!bSlot) return;
            var bItems=slot.brandItems[b]||[];
            var bSelKey=(hseg||'')+'|'+(hkat||'')+'|'+sz+'|'+b;
            var bSel=_modelSel[bSelKey];
            var bRaw=bSlot.cost;
            if(bSel){var bf=bItems.find(function(x){return x._dk===bSel;});if(bf)bRaw=bf.cost;}
            // Resolve displayed label (desen + hiz_yuk)
            function itemLabel(item){return (item.desen||'')+(item.hiz_yuk?' '+item.hiz_yuk:'');}
            var dispDes='';
            if(bSel){var bf2=bItems.find(function(x){return x._dk===bSel;});if(bf2)dispDes=itemLabel(bf2);}
            if(!dispDes&&bItems.length){
              var di=bItems.find(function(x){return Math.abs(x.cost-bRaw)<1;});
              dispDes=di?itemLabel(di):itemLabel(bItems[0]);
            }
            var bz=1+((zamSen[b]||0)/100);
            var ac=Math.round(bRaw*bz);
            var idx=b==='LASSA'?100:(lRaw*lz>0?Math.round(ac/(lRaw*lz)*100):null);
            grid[sz][b]={cost:ac,idx:idx,desen:dispDes,items:bItems,hasMulti:bItems.length>1};
          });
        });
        return {sizes:sizes,brands:brands,grid:grid};
      }

      // SEGS driven by bi_arac_kategorileri — adding a new category requires only a DB INSERT
      var _aracKat=wrap._aracKat||[{id:'BINEK',label_tr:'Binek'},{id:'SUV',label_tr:'SUV'},{id:'HAFIF_TICARI',label_tr:'Hafif Ticari'}];
      var SEGS=_aracKat.map(function(k){return k.id;});
      var SNMS={}; _aracKat.forEach(function(k){SNMS[k.id]=k.label_tr;});
      var KATS=['KIS','YAZ','4MEVSIM'];
      var KNMS={KIS:'❄️ Kış',YAZ:'☀️ Yaz','4MEVSIM':'🌦 4 Mevsim'};
      // Segment colours — fixed palette cycling for unknown future categories
      var _SCOL_PAL=['#60a5fa','#a78bfa','#fbbf24','#34d399','#f87171','#fb923c'];
      var SCOL={}; _aracKat.forEach(function(k,i){SCOL[k.id]=_SCOL_PAL[i%_SCOL_PAL.length];});

      // Overall brand scores (aggregate all seg×kat)
      var oScores={};
      SEGS.forEach(function(seg){
        if(!bySegKat[seg]) return;
        KATS.forEach(function(kat){
          if(!bySegKat[seg][kat]) return;
          var hm=heatmap(bySegKat[seg][kat],seg,kat);
          hm.brands.forEach(function(b){
            var vals=hm.sizes.map(function(sz){
              var c=hm.grid[sz]&&hm.grid[sz][b]; return (c&&c.idx!=null)?c.idx:null;
            }).filter(function(v){return v!=null;});
            if(!vals.length) return;
            var avg=Math.round(vals.reduce(function(a,v){return a+v;},0)/vals.length);
            if(!oScores[b]) oScores[b]={t:0,n:0};
            oScores[b].t+=avg; oScores[b].n++;
          });
        });
      });

      var h='';
      h+='<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;padding-bottom:10px;border-bottom:0.5px solid rgba(255,255,255,0.08)">';
      h+='<span style="font-size:14px;font-weight:700;color:#a5b4fc;letter-spacing:0.2px">📊 Fiyat Endeksi &amp; Rekabet Paneli</span>';
      h+='<span style="font-size:11px;color:#475569">' + (wrap._items&&wrap._items.length ? wrap._items.length.toLocaleString('tr-TR') + ' kayıt' : '') + '</span>';
      h+='</div>';
      var _VBON="padding:4px 12px;font-size:11px;font-weight:700;border-radius:6px;border:none;cursor:pointer;background:rgba(99,102,241,0.25);color:#a5b4fc;";
      var _VBOFF="padding:4px 12px;font-size:11px;font-weight:700;border-radius:6px;border:none;cursor:pointer;background:rgba(255,255,255,0.04);color:#475569;";
      var _pv2=wrap._piView||'endeks';
      h+='<div style="display:flex;gap:6px;margin-bottom:10px;padding:2px 0">';
      h+='<button class="pi-view-btn" data-v="endeks" style="'+(_pv2==="endeks"?_VBON:_VBOFF)+'">&#128202; Endeks</button>';
      h+='<button class="pi-view-btn" data-v="firsat" style="'+(_pv2==="firsat"?_VBON:_VBOFF)+'">&#127919; Fırsat</button>';
h+='<button class="pi-view-btn" data-v="kapsama" style="'+(_pv2==="kapsama"?_VBON:_VBOFF)+'">&#128230; Kapsama</button>';
h+='<button class="pi-view-btn" data-v="rekabet" style="'+(_pv2==="rekabet"?_VBON:_VBOFF)+'">&#127991; Rekabet</button>';
      h+='</div>';
      if(_pv2==='firsat'){h+=_buildFirsatContent(wrap);wrap.innerHTML=h;_piWire(wrap);return;}
if(_pv2==='kapsama'){h+=_buildKapsamaContent(wrap);wrap.innerHTML=h;_piWire(wrap);return;}
if(_pv2==='rekabet'){h+=_buildRekabetContent(wrap);wrap.innerHTML=h;_piWire(wrap);if(!wrap._rekabetData&&!wrap._rekabetLoading){wrap._rekabetLoading=true;apiFetch('/api/price-list/rekabet').then(function(d){wrap._rekabetData=d.rows||[];wrap._rekabetLoading=false;if(wrap._piView==='rekabet')_piRender(wrap);}).catch(function(e){console.error('[Rekabet]',e);wrap._rekabetLoading=false;wrap._rekabetError=true;if(wrap._piView==='rekabet')_piRender(wrap);});}return;}


      // ── Filter bar ──────────────────────────────────────────────────────────
      h+='<div style="display:flex;align-items:center;gap:5px;flex-wrap:wrap;margin-bottom:10px;padding:8px 12px;background:rgba(255,255,255,0.025);border-radius:8px;border:0.5px solid rgba(255,255,255,0.07)">';
      h+='<div style="display:flex;gap:3px">';
      [['all','Tüm Sezon'],['KIS','❄️ Kış'],['YAZ','☀️ Yaz'],['4MEVSIM','🌦 4M']].forEach(function(x){
        h+='<button class="pi-kflt" data-v="'+x[0]+'" style="'+(katFlt===x[0]?ON:OFF)+'">'+x[1]+'</button>';
      });
      h+='</div><div style="width:1px;height:18px;background:rgba(255,255,255,0.09);margin:0 2px"></div>';
      h+='<div style="display:flex;gap:3px">';
      // Segment buttons driven by taxonomy — same as Kapsama/Fırsat
      [['all','Tüm Seg']].concat((_aracKat||[]).map(function(k){return[k.id,k.label_tr];})).forEach(function(x){
        h+='<button class="pi-sflt" data-v="'+x[0]+'" style="'+(segFlt===x[0]?ON:OFF)+'">'+x[1]+'</button>';
      });
      h+='</div><div style="width:1px;height:18px;background:rgba(255,255,255,0.09);margin:0 2px"></div>';
      h+='<div style="display:flex;gap:3px">';
      [['all','Tüm'],['13-16','13–16"'],['17+','17+"']].forEach(function(x){
        h+='<button class="pi-rflt" data-v="'+x[0]+'" style="'+(rimGrp===x[0]?ON:OFF)+'">'+x[1]+'</button>';
      });
      h+='</div><div style="width:1px;height:18px;background:rgba(255,255,255,0.09);margin:0 2px"></div>';
      h+='<div style="display:flex;gap:3px">';
      [['net','Net'],['efektif','Efektif']].forEach(function(x){
        h+='<button class="pi-ctflt" data-v="'+x[0]+'" style="'+(costType===x[0]?ON:OFF)+'">'+x[1]+'</button>';
      });
      h+='</div>';
      h+='<div style="width:1px;height:18px;background:rgba(255,255,255,0.09);margin:0 2px"></div>';
      h+='<input class="pi-ebat-search" type="text" placeholder="🔍 ebat…" value="'+ebatSearch+'" style="background:rgba(255,255,255,0.05);border:0.5px solid rgba(255,255,255,0.12);border-radius:5px;padding:3px 10px;color:#f1f5f9;font-size:12px;width:115px;outline:none;font-family:monospace">';
      h+='</div>';

      // ── Zam simulasyonu ─────────────────────────────────────────────────────
      var _hasZam=allBrands.some(function(b){return (zamSen[b]||0)!==0;});
      h+='<div style="display:flex;align-items:center;gap:5px;flex-wrap:wrap;margin-bottom:10px;padding:7px 12px;background:rgba(251,191,36,0.03);border-radius:8px;border:0.5px solid rgba(251,191,36,'+(zamOn||_hasZam?'0.2':'0.07')+')">';
      h+='<button class="pi-zam-toggle" style="background:'+(zamOn?'rgba(251,191,36,0.15)':'rgba(255,255,255,0.04)')+';border:0.5px solid rgba(251,191,36,'+(zamOn?'0.4':'0.15')+');border-radius:5px;padding:3px 10px;color:'+(zamOn?'#fbbf24':'#64748b')+';font-size:11px;cursor:pointer;font-weight:600">📈 Zam Sim '+(zamOn?'▴':'▾')+'</button>';
      if(zamOn||_hasZam){
        allBrands.forEach(function(b){
          var z=zamSen[b]||0;
          var zc=z>0?'#fbbf24':z<0?'#34d399':'#475569';
          h+='<div style="display:flex;align-items:center;gap:2px;background:rgba(255,255,255,0.04);border-radius:5px;padding:2px 7px">';
          h+='<span style="font-size:10px;color:#94a3b8;font-weight:600;margin-right:3px">'+b.charAt(0)+b.slice(1).toLowerCase()+'</span>';
          h+='<span style="font-size:11px;font-weight:700;color:'+zc+';min-width:28px;text-align:center">'+(z>0?'+':'')+z+'%</span>';
          h+='<button class="pi-zinc-m" data-b="'+b+'" style="background:rgba(52,211,153,0.1);border:0.5px solid rgba(52,211,153,0.2);border-radius:3px;padding:0 5px;color:#34d399;font-size:10px;cursor:pointer">−5</button>';
          h+='<button class="pi-zinc" data-b="'+b+'" style="background:rgba(251,191,36,0.1);border:0.5px solid rgba(251,191,36,0.2);border-radius:3px;padding:0 5px;color:#fbbf24;font-size:10px;cursor:pointer">+5</button>';
          if(z!==0) h+='<button class="pi-zinc-r" data-b="'+b+'" style="background:rgba(239,68,68,0.07);border:0.5px solid rgba(239,68,68,0.2);border-radius:3px;padding:0 5px;color:#f87171;font-size:10px;cursor:pointer">×</button>';
          h+='</div>';
        });
        if(_hasZam) h+='<button class="pi-zinc-all-r" style="background:rgba(239,68,68,0.07);border:0.5px solid rgba(239,68,68,0.2);border-radius:5px;padding:3px 9px;color:#f87171;font-size:10px;cursor:pointer;font-weight:600;margin-left:4px">Sıfırla</button>';
      }
      h+='</div>';

      // ── Overall scorecards ──────────────────────────────────────────────────
      var oBrands=allBrands.filter(function(b){return oScores[b]&&oScores[b].n;});
      if(oBrands.length){
        h+='<div style="margin-bottom:16px">';
        h+='<div style="font-size:10px;font-weight:700;color:#475569;letter-spacing:0.8px;text-transform:uppercase;margin-bottom:8px">🏆 Genel Rekabet · LASSA = 100 (ağırlıklı ortalama)</div>';
        h+='<div style="display:flex;flex-wrap:wrap;gap:8px">';
        oBrands.forEach(function(b){
          var sc=oScores[b]; var avg=Math.round(sc.t/sc.n);
          var isL=b==='LASSA';
          var col=isL?'#60a5fa':avg<100?'#34d399':avg>100?'#f87171':'#94a3b8';
          var bg=isL?'rgba(96,165,250,0.1)':avg<100?'rgba(52,211,153,0.08)':'rgba(248,113,113,0.08)';
          h+='<div style="display:flex;flex-direction:column;align-items:center;padding:8px 14px;background:'+bg+';border:0.5px solid '+col+'40;border-radius:10px;min-width:68px">';
          h+='<div style="font-size:10px;color:#64748b;margin-bottom:2px">'+b.charAt(0)+b.slice(1).toLowerCase()+'</div>';
          h+='<div style="font-size:18px;font-weight:800;color:'+col+'">'+avg+(isL?'':avg<100?' ↓':' ↑')+'</div>';
          h+='<div style="font-size:9px;color:#475569;margin-top:2px">'+sc.n+' komb.</div>';
          h+='</div>';
        });
        h+='</div></div>';
      } else if(items.length===0){
        h+='<div style="padding:30px;color:#475569;font-size:13px;text-align:center">⏳ Fiyat verisi yükleniyor…</div>';
      }

      // ── Segment sections with heatmaps ──────────────────────────────────────
      var visSegs=SEGS.filter(function(sg){return (segFlt==='all'||segFlt===sg)&&bySegKat[sg];});
      if(!visSegs.length&&items.length>0){
        h+='<div style="padding:20px;color:#64748b;font-size:13px;text-align:center">Bu filtre kombinasyonu için veri yok</div>';
      }

      visSegs.forEach(function(seg){
        var visKats=KATS.filter(function(k){
          return (katFlt==='all'||katFlt===k)&&bySegKat[seg][k]&&Object.keys(bySegKat[seg][k]).length;
        });
        if(!visKats.length) return;

        h+='<div style="margin-bottom:22px">';
        h+='<div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;padding-bottom:5px;border-bottom:1px solid rgba(255,255,255,0.07)">';
        h+='<span style="font-size:14px;font-weight:700;color:'+SCOL[seg]+'">'+SNMS[seg]+'</span>';
        h+='</div>';

        visKats.forEach(function(kat){
          var hm=heatmap(bySegKat[seg][kat],seg,kat);
          if(!hm.sizes.length||!hm.brands.length) return;

          // Mini scorecards row
          var minis={};
          hm.brands.forEach(function(b){
            var vals=hm.sizes.map(function(sz){
              var c=hm.grid[sz]&&hm.grid[sz][b]; return (c&&c.idx!=null)?c.idx:null;
            }).filter(function(v){return v!=null;});
            if(vals.length) minis[b]=Math.round(vals.reduce(function(a,v){return a+v;},0)/vals.length);
          });

          h+='<div style="margin-bottom:10px;padding:10px 12px;background:rgba(255,255,255,0.02);border:0.5px solid rgba(255,255,255,0.06);border-radius:8px">';
          h+='<div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:8px">';
          h+='<span style="font-size:12px;font-weight:700;color:#94a3b8;min-width:70px">'+KNMS[kat]+'</span>';
          hm.brands.forEach(function(b){
            if(minis[b]==null) return;
            var mc=b==='LASSA'?'#60a5fa':minis[b]<100?'#34d399':'#f87171';
            h+='<div style="display:inline-flex;align-items:center;gap:3px;padding:2px 7px;background:rgba(255,255,255,0.04);border-radius:5px">';
            h+='<span style="font-size:10px;color:#64748b">'+b.charAt(0)+b.slice(1).toLowerCase()+'</span>';
            h+='<span style="font-size:11px;font-weight:700;color:'+mc+'">'+minis[b]+'</span>';
            h+='</div>';
          });
          h+='</div>';

          // Heatmap table
          h+='<div style="overflow-x:auto;-webkit-overflow-scrolling:touch">';
          h+='<table style="border-collapse:collapse;font-size:11px;min-width:300px">';
          h+='<thead><tr style="border-bottom:0.5px solid rgba(255,255,255,0.07)">';
          h+='<th style="text-align:left;padding:4px 8px;color:#475569;min-width:105px;font-weight:600">Ebat</th>';
          hm.brands.forEach(function(b){
            var hc=b==='LASSA'?'#60a5fa':'#94a3b8';
            h+='<th style="text-align:center;padding:4px 10px;color:'+hc+';white-space:nowrap;font-weight:600;min-width:80px">'+b.charAt(0)+b.slice(1).toLowerCase()+'</th>';
          });
          h+='</tr></thead><tbody>';

          hm.sizes.forEach(function(sz,ri){
            var rbg=ri%2===0?'rgba(255,255,255,0.012)':'transparent';
            h+='<tr data-ebat="'+sz+'" style="background:'+rbg+'">';
            h+='<td style="padding:4px 8px;color:#34d399;font-family:monospace;font-weight:600;white-space:nowrap;font-size:10px">'+sz+'</td>';
            hm.brands.forEach(function(b){
              var c=hm.grid[sz]&&hm.grid[sz][b];
              if(!c){h+='<td style="padding:4px 10px;text-align:center;color:#334155">—</td>';return;}
              var ck=seg+'|'+kat+'|'+sz+'|'+b;
              var isExp=_expCell===ck;
              var tdSt='padding:4px 8px;text-align:center;min-width:80px;vertical-align:top'+(c.hasMulti?';cursor:pointer':'')+';transition:background .1s'+(isExp?';background:rgba(99,102,241,0.1)':'');
              var tdCls=c.hasMulti?'class="pi-cell" data-ck="'+ck+'"':'';
              h+='<td '+tdCls+' style="'+tdSt+'">';
              if(b==='LASSA'){
                h+='<span style="display:inline-block;background:rgba(96,165,250,0.15);color:#60a5fa;font-weight:700;padding:1px 6px;border-radius:10px;font-size:11px">100'+(c.hasMulti?' ✎':'')+'</span>';
              } else if(c.idx==null){
                h+='<span style="color:#334155;font-size:11px">?</span>';
              } else {
                var ch2=c.idx<100;
                var col2=ch2?'#34d399':'#f87171';
                var bg2=ch2?'rgba(52,211,153,0.12)':'rgba(248,113,113,0.12)';
                h+='<span style="display:inline-block;background:'+bg2+';color:'+col2+';font-weight:700;padding:1px 6px;border-radius:10px;font-size:11px">'+c.idx+(c.hasMulti?' ✎':'')+'</span>';
              }
              h+='<div style="font-size:9px;color:#64748b;margin-top:2px">'+c.cost.toLocaleString('tr-TR')+'₺</div>';
              if(c.desen) h+='<div style="font-size:8px;color:#818cf8;margin-top:1px;max-width:78px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+c.desen.replace(/"/g,"&quot;")+'">'+c.desen+'</div>';
              h+='</td>';
            });
            h+='</tr>';
            // Expansion row (model picker)
            var mxB=null;
            for(var _bi=0;_bi<hm.brands.length;_bi++){
              if(_expCell===seg+'|'+kat+'|'+sz+'|'+hm.brands[_bi]){mxB=hm.brands[_bi];break;}
            }
            if(mxB){
              var xC=hm.grid[sz]&&hm.grid[sz][mxB];
              var xIt=(xC&&xC.items)||[];
              if(xIt.length>1){
                var xK=seg+'|'+kat+'|'+sz+'|'+mxB;
                h+='<tr style="background:rgba(99,102,241,0.06)"><td colspan="'+(hm.brands.length+1)+'" style="padding:6px 14px 8px;border-bottom:0.5px solid rgba(99,102,241,0.15)">';
                h+='<span style="font-size:10px;color:#94a3b8;font-weight:600;margin-right:6px">'+mxB.charAt(0)+mxB.slice(1).toLowerCase()+' · '+sz+':</span>';
                var sortedItems=xIt.slice().sort(function(a,b){return a.liste-b.liste;});
                sortedItems.forEach(function(item){
                  var isSel=_modelSel[xK]===item._dk;
                  var bSt=isSel
                    ?'background:rgba(99,102,241,0.2);border:0.5px solid rgba(99,102,241,0.5);border-radius:4px;padding:3px 9px;font-size:11px;color:#a5b4fc;cursor:pointer;margin-right:5px;font-weight:600'
                    :'background:rgba(255,255,255,0.04);border:0.5px solid rgba(255,255,255,0.1);border-radius:4px;padding:3px 9px;font-size:11px;color:#64748b;cursor:pointer;margin-right:5px';
                  var safeD=(item._dk||'').replace(/"/g,'&quot;');
                  var lbl=(item.desen||'(desensiz)')+(item.hiz_yuk?' '+item.hiz_yuk:'');
                  h+='<button class="pi-modpick" data-ck="'+xK.replace(/"/g,'&quot;')+'" data-des="'+safeD+'" style="'+bSt+'">'+lbl+' <span style="color:#475569;font-size:10px">'+item.liste.toLocaleString('tr-TR')+'₺</span></button>';
                });
                h+='</td></tr>';
              }
            }
          });
          h+='</tbody></table></div>';
          h+='</div>'; // kat panel
        });
        h+='</div>'; // seg section
      });

      // ── AI analysis panel ───────────────────────────────────────────────────
      h+='<div style="margin-top:12px;padding:12px 14px;background:rgba(99,102,241,0.06);border:0.5px solid rgba(99,102,241,0.2);border-radius:10px">';
      h+='<div style="display:flex;align-items:center;gap:10px;margin-bottom:6px">';
      h+='<span style="font-size:12px;font-weight:700;color:#a5b4fc">🤖 AI Rekabet Analizi</span>';
      h+='<button id="pi-ai-btn" style="background:rgba(99,102,241,0.2);border:0.5px solid rgba(99,102,241,0.4);border-radius:5px;padding:4px 12px;color:#a5b4fc;font-size:11px;cursor:pointer;font-weight:600">Analiz Yap</button>';
      h+='</div>';
      h+='<div id="pi-ai-result" style="font-size:12px;color:#64748b;line-height:1.6"></div>';
      h+='</div>';

      wrap.innerHTML = h;
      _piWire(wrap);
    }

    function _buildKapsamaContent(wrap){
      // Use raw items for spec-level coverage (ebat + hiz_yuk grouping)
      var rawItems=wrap._items||[];
      var kaFlt=wrap._kaFlt||{sezon:'all',seg:'all'};
      var kaView=wrap._kaView||'gaps';
      var kaSort=wrap._kaSort||'gaps';
      var kaSearch=(wrap._kaSearch||'').trim().toUpperCase().replace(/\s+/g,'');

      if(!rawItems.length)return'<div style="padding:20px;color:#64748b;text-align:center">&#9203; Fiyat listesi bekleniyor…</div>';

      // Filter by segment + season from raw items
      var filt=rawItems.filter(function(it){
        if(!it.ebat||!it.marka)return false;
        var seg=it.arac_tipi||'BINEK';
        var sezon=(it.kategori||'KIS').replace(/\s+/g,'');
        if(kaFlt.seg!=='all'&&seg!==kaFlt.seg)return false;
        if(kaFlt.sezon!=='all'&&sezon!==kaFlt.sezon)return false;
        return true;
      });

      if(!filt.length)return'<div style="padding:20px;color:#64748b;text-align:center">Bu filtre kombinasyonu için fiyat listesi bulunamadı</div>';

      // Build coverage at ebat + hiz_yuk + sezon level
      // Sep = \x00 (null byte) — never appears in tire data
      var SEP='\x00';
      var brandSet=new Set();
      var priceSet=new Set(); // "br SEP ebat SEP spec SEP sezon"
      var slotMap={}; // "ebat SEP spec SEP sezon" -> {ebat,spec,sezon}

      filt.forEach(function(it){
        var br=(it.marka||'').toUpperCase();
        var sezon=(it.kategori||'KIS').replace(/\s+/g,'');
        var spec=(it.hiz_yuk||'').trim();
        var slotKey=it.ebat+SEP+spec+SEP+sezon;
        brandSet.add(br);
        priceSet.add(br+SEP+slotKey);
        if(!slotMap[slotKey])slotMap[slotKey]={ebat:it.ebat,spec:spec,sezon:sezon};
      });

      var brands=[...brandSet].sort(function(a,b){
        if(a==='LASSA')return -1;if(b==='LASSA')return 1;return a.localeCompare(b);
      });

      // Build rows — one per unique ebat+spec+sezon combination
      var rows=Object.keys(slotMap).map(function(key){
        var slot=slotMap[key];
        var covered=[],missing=[];
        brands.forEach(function(br){
          if(priceSet.has(br+SEP+key))covered.push(br);
          else missing.push(br);
        });
        return{ebat:slot.ebat,spec:slot.spec,sezon:slot.sezon,covered:covered,missing:missing};
      });

      // Sort
      rows.sort(function(a,b){
        if(kaSort==='gaps'){
          var d=b.missing.length-a.missing.length;
          if(d!==0)return d;
        } else {
          var d=b.covered.length-a.covered.length;
          if(d!==0)return d;
        }
        var ea=a.ebat.localeCompare(b.ebat);
        return ea!==0?ea:(a.spec||'').localeCompare(b.spec||'');
      });

      // Apply ebat search filter
      if(kaSearch){rows=rows.filter(function(r){return r.ebat.toUpperCase().replace(/\s+/g,'').indexOf(kaSearch)>=0;});}

      var gapRows=rows.filter(function(r){return r.missing.length>0;});
      var totalGaps=rows.reduce(function(s,r){return s+r.missing.length;},0);
      var totalCov=rows.reduce(function(s,r){return s+r.covered.length;},0);

      var BON='background:rgba(99,102,241,0.2);color:#a5b4fc;border:0.5px solid rgba(99,102,241,0.4);padding:3px 9px;border-radius:5px;font-size:10px;cursor:pointer;font-weight:600;';
      var BOFF='background:rgba(255,255,255,0.03);color:#475569;border:0.5px solid rgba(255,255,255,0.06);padding:3px 9px;border-radius:5px;font-size:10px;cursor:pointer;';
      var SZN={'KIS':'&#10052; Kış','YAZ':'&#9728; Yaz','4MEVSIM':'&#127782; 4M'};

      var h='';

      // Filter + view + sort controls
      h+='<div style="display:flex;align-items:center;gap:4px;flex-wrap:wrap;margin-bottom:8px;padding:6px 10px;background:rgba(255,255,255,0.02);border-radius:7px;border:0.5px solid rgba(255,255,255,0.05)">';
      [['all','Tüm Sezon'],['KIS','&#10052; Kış'],['YAZ','&#9728; Yaz'],['4MEVSIM','&#127782; 4M']].forEach(function(x){
        h+='<button class="ka-flt" data-fk="sezon" data-fv="'+x[0]+'" style="'+(kaFlt.sezon===x[0]?BON:BOFF)+'">'+x[1]+'</button>';
      });
      h+='<span style="display:inline-block;width:1px;height:16px;background:rgba(255,255,255,0.08);margin:0 3px"></span>';
      // Segment buttons built from taxonomy — no code change when new categories are added
      var _kaSegBtns=[['all','Tüm']].concat((wrap._aracKat||[]).map(function(k){return[k.id,k.label_tr];}));
      _kaSegBtns.forEach(function(x){
        h+='<button class="ka-flt" data-fk="seg" data-fv="'+x[0]+'" style="'+(kaFlt.seg===x[0]?BON:BOFF)+'">'+x[1]+'</button>';
      });
      h+='<span style="display:inline-block;width:1px;height:16px;background:rgba(255,255,255,0.08);margin:0 6px"></span>';
      h+='<button class="ka-view-btn" data-v="gaps" style="'+(kaView==='gaps'?BON:BOFF)+'">&#9888; Eksik Liste</button>';
      h+='<button class="ka-view-btn" data-v="matrix" style="'+(kaView==='matrix'?BON:BOFF)+'">&#9636; Matris</button>';
      h+='<span style="display:inline-block;width:1px;height:16px;background:rgba(255,255,255,0.08);margin:0 6px"></span>';
      h+='<button class="ka-flt" data-fk="__sort" data-fv="gaps" style="'+(kaSort==='gaps'?BON:BOFF)+'">↓ En Eksik</button>';
      h+='<button class="ka-flt" data-fk="__sort" data-fv="coverage" style="'+(kaSort==='coverage'?BON:BOFF)+'">↓ En Kapsamlı</button>';
      h+='<span style="display:inline-block;width:1px;height:16px;background:rgba(255,255,255,0.08);margin:0 6px"></span>';
      h+='<input id="ka-search-input" type="text" placeholder="🔍 Ebat ara…" value="'+(wrap._kaSearch||'')+'" style="background:rgba(255,255,255,0.05);border:0.5px solid rgba(255,255,255,0.12);border-radius:5px;padding:3px 8px;font-size:11px;color:#e2e8f0;outline:none;width:130px">';
      h+='</div>';

      // Summary cards
      h+='<div style="display:flex;gap:8px;margin-bottom:12px">';
      [{l:'Toplam Slot',v:rows.length,c:'#60a5fa'},{l:'Kapsamalı',v:totalCov,c:'#34d399'},{l:'Eksik Slot',v:totalGaps,c:'#f87171'},{l:'Marka',v:brands.length,c:'#fbbf24'}].forEach(function(c){
        h+='<div style="padding:8px 14px;background:rgba(255,255,255,0.03);border:0.5px solid '+c.c+'30;border-radius:8px;flex:1;min-width:80px">';
        h+='<div style="font-size:9px;color:#475569;text-transform:uppercase;letter-spacing:0.5px">'+c.l+'</div>';
        h+='<div style="font-size:18px;font-weight:800;color:'+c.c+'">'+c.v+'</div></div>';
      });
      h+='</div>';

      if(kaView==='gaps'){
        var dispRows=(kaSort==='gaps'?gapRows:rows);
        if(!dispRows.length){h+='<div style="padding:20px;color:#34d399;text-align:center">&#10003; Tüm ebatlar tüm markalar tarafından kapsanıyor</div>';return h;}
        h+='<div style="overflow-x:auto"><table style="border-collapse:collapse;width:100%">';
        h+='<thead><tr style="border-bottom:0.5px solid rgba(255,255,255,0.1)">';
        h+='<th style="padding:5px 8px;text-align:left;font-size:10px;font-weight:700;color:#475569">Ebat</th>';
        h+='<th style="padding:5px 6px;text-align:left;font-size:10px;font-weight:700;color:#94a3b8">Spec</th>';
        h+='<th style="padding:5px 6px;font-size:10px;font-weight:700;color:#475569">Sez</th>';
        h+='<th style="padding:5px 6px;text-align:center;font-size:10px;font-weight:700;color:#475569">Kapsama</th>';
        h+='<th style="padding:5px 8px;text-align:left;font-size:10px;font-weight:700;color:#f87171">Eksik → Ön Sipariş</th>';
        h+='<th style="padding:5px 8px;text-align:left;font-size:10px;font-weight:700;color:#34d399">Mevcut</th>';
        h+='</tr></thead><tbody>';
        dispRows.forEach(function(r,ri){
          var bg=ri%2===0?'rgba(255,255,255,0.012)':'transparent';
          var covPct=brands.length?Math.round(r.covered.length/brands.length*100):0;
          var barC=covPct>=80?'#34d399':covPct>=50?'#fbbf24':'#f87171';
          h+='<tr style="background:'+bg+';border-bottom:0.5px solid rgba(255,255,255,0.03)">';
          h+='<td style="padding:3px 8px;color:#34d399;font-family:monospace;font-size:11px;font-weight:700;white-space:nowrap">'+r.ebat+'</td>';
          h+='<td style="padding:3px 6px;color:#94a3b8;font-size:10px;white-space:nowrap">'+(r.spec||'<span style="color:#334155">—</span>')+'</td>';
          h+='<td style="padding:3px 6px;color:#64748b;font-size:10px;white-space:nowrap">'+(SZN[r.sezon]||r.sezon)+'</td>';
          h+='<td style="padding:3px 6px"><div style="display:flex;align-items:center;gap:3px;justify-content:center"><div style="width:38px;height:4px;background:rgba(255,255,255,0.06);border-radius:2px;overflow:hidden"><div style="width:'+covPct+'%;height:100%;background:'+barC+'"></div></div><span style="color:'+barC+';font-size:9px;font-weight:700">'+r.covered.length+'/'+brands.length+'</span></div></td>';
          h+='<td style="padding:3px 8px">';
          r.missing.forEach(function(br){h+='<span style="display:inline-block;background:rgba(248,113,113,0.12);color:#f87171;border:0.5px solid rgba(248,113,113,0.3);border-radius:4px;padding:1px 6px;font-size:9px;font-weight:600;margin:1px 2px;white-space:nowrap">'+br.charAt(0)+br.slice(1).toLowerCase()+'</span>';});
          h+='</td><td style="padding:3px 8px">';
          r.covered.forEach(function(br){h+='<span style="display:inline-block;background:rgba(52,211,153,0.08);color:#34d399;border:0.5px solid rgba(52,211,153,0.2);border-radius:4px;padding:1px 6px;font-size:9px;margin:1px 2px;white-space:nowrap">'+br.charAt(0)+br.slice(1).toLowerCase()+'</span>';});
          h+='</td></tr>';
        });
        h+='</tbody></table></div>';
      } else {
        var matRows=rows;
        h+='<div style="overflow-x:auto"><table style="border-collapse:collapse;font-size:10px">';
        h+='<thead><tr style="border-bottom:0.5px solid rgba(255,255,255,0.1)">';
        h+='<th style="padding:4px 8px;text-align:left;color:#475569;white-space:nowrap">Ebat</th>';
        h+='<th style="padding:4px 6px;text-align:left;color:#94a3b8;white-space:nowrap">Spec</th>';
        h+='<th style="padding:4px 5px;color:#475569">Sez</th>';
        brands.forEach(function(br){
          var abbr=br.length>8?br.slice(0,7)+'…':br;
          h+='<th style="padding:4px 5px;color:#475569;white-space:nowrap;min-width:44px;text-align:center" title="'+br+'">'+abbr+'</th>';
        });
        h+='</tr></thead><tbody>';
        matRows.forEach(function(r,ri){
          var bg=ri%2===0?'rgba(255,255,255,0.012)':'transparent';
          h+='<tr style="background:'+bg+';border-bottom:0.5px solid rgba(255,255,255,0.03)">';
          h+='<td style="padding:2px 8px;color:#34d399;font-family:monospace;font-weight:700;white-space:nowrap">'+r.ebat+'</td>';
          h+='<td style="padding:2px 6px;color:#94a3b8;white-space:nowrap;font-size:9px">'+(r.spec||'—')+'</td>';
          h+='<td style="padding:2px 5px;color:#64748b;white-space:nowrap">'+(SZN[r.sezon]||r.sezon)+'</td>';
          brands.forEach(function(br){
            var cvd=r.covered.indexOf(br)>=0;
            h+='<td style="padding:2px 5px;text-align:center;background:'+(cvd?'rgba(52,211,153,0.05)':'rgba(248,113,113,0.04)')+'">'+(cvd?'<span style="color:#34d399;font-size:13px">&#10003;</span>':'<span style="color:#2d3748;font-size:10px">—</span>')+'</td>';
          });
          h+='</tr>';
        });
        h+='</tbody></table></div>';
      }
      return h;
    }
    function _fmtAi(txt){
      if(!txt)return'';
      return txt.split('\n').filter(function(l){return l.trim();}).map(function(l){
        var m=l.match(/^(\d+\.?)\s+(.*)/s);
        if(m)return'<div style="display:flex;gap:8px;margin-bottom:12px"><div style="color:#6366f1;font-weight:800;font-size:11px;flex-shrink:0;padding-top:2px">'+m[1]+'</div><div style="color:#94a3b8;font-size:12px;line-height:1.65">'+m[2]+'</div></div>';
        return'<div style="color:#64748b;font-size:12px;margin-bottom:6px">'+l+'</div>';
      }).join('');
    }
    function _buildFirsatContent(wrap) {
      var flat=wrap._piFlat||[];
      var salesVol=wrap._salesVol;
      var zamSen=wrap._zamSen||{};
      var faFlt=wrap._faFlt||{sezon:'all',seg:'all',durum:'all'};
      var faSort=wrap._faSort||'adet';
      var faSortDir=wrap._faSortDir!=null?wrap._faSortDir:-1;
      var faYil=wrap._faYil||'all';

      if(!flat.length) return '<div style="padding:20px;color:#64748b;text-align:center">&#9203; Fiyat listesi bekleniyor…</div>';
      if(salesVol===undefined||salesVol===null) return '<div style="padding:20px;color:#64748b;text-align:center">&#9203; Satış verisi yükleniyor…</div>';

      function nSez(k){return k==='4 MEVSIM'?'4MEVSIM':(k||'');}

      // Price map: (marka|ebat|sezon) -> cheapest after zam
      var priceMap={};
      flat.forEach(function(f){
        var z=1+((zamSen[f.marka]||0)/100);
        var adjNet=Math.round(f.net*z);
        var k=f.marka+'|'+f.ebat+'|'+f.sezon;
        if(!priceMap[k]||adjNet<priceMap[k].net) priceMap[k]={marka:f.marka,ebat:f.ebat,sezon:f.sezon,seg:f.seg,net:adjNet,liste:Math.round(f.liste||0),desen:f.desen||'',nItems:f.nItems||1};
      });

      // Lassa reference per (ebat|sezon)
      var lRef={};
      flat.filter(function(f){return f.marka==='LASSA';}).forEach(function(f){
        var z=1+((zamSen['LASSA']||0)/100);
        var adjNet=f.net*z;
        var k=f.ebat+'|'+f.sezon;
        if(!lRef[k]||adjNet<lRef[k]) lRef[k]=adjNet;
      });

      // Available years from sales data
      var allYears=[...new Set(salesVol.map(function(sv){return sv.yil;}))].filter(Boolean).map(Number).sort(function(a,b){return b-a;});

      // Segment lookup for no-price-list rows
      var segLookup={};
      salesVol.forEach(function(sv){
        var k=sv.marka+'|'+sv.ebat+'|'+nSez(sv.sezon);
        if(!segLookup[k]) segLookup[k]=sv.segment||'';
      });

      // Sales map: aggregate filtered by year
      var salesMap={};
      salesVol.forEach(function(sv){
        if(faYil!=='all'&&String(sv.yil)!==String(faYil)) return;
        var k=sv.marka+'|'+sv.ebat+'|'+nSez(sv.sezon);
        if(!salesMap[k]) salesMap[k]={adet:0,ciro:0,musteri_sayisi:0};
        salesMap[k].adet+=parseFloat(sv.adet)||0;
        salesMap[k].ciro+=parseFloat(sv.ciro)||0;
        salesMap[k].musteri_sayisi+=parseInt(sv.musteri_sayisi)||0;
      });

      // Build rows
      var rows=[];
      var seenKeys={};

      Object.keys(priceMap).forEach(function(k){
        seenKeys[k]=true;
        var p=priceMap[k];
        var sv=salesMap[k];
        var lR=lRef[p.ebat+'|'+p.sezon]||0;
        var endeks=p.marka==='LASSA'?100:(lR>0?Math.round(p.net/lR*100):null);
        rows.push({marka:p.marka,ebat:p.ebat,sezon:p.sezon,seg:p.seg,
          desen:p.desen,nItems:p.nItems,
          net:p.net,liste:p.liste,endeks:endeks,
          adet:sv?sv.adet:0,ciro:sv?sv.ciro:0,musteri:sv?sv.musteri_sayisi:0,
          hp:true,hs:!!sv});
      });

      // Sold but not in price list
      Object.keys(salesMap).forEach(function(k){
        if(seenKeys[k]) return;
        seenKeys[k]=true;
        var sv=salesMap[k];
        var pts=k.split('|');
        rows.push({marka:pts[0],ebat:pts[1],sezon:pts[2],seg:segLookup[k]||'',
          desen:'',nItems:0,net:null,liste:null,endeks:null,
          adet:sv.adet,ciro:sv.ciro,musteri:sv.musteri_sayisi,
          hp:false,hs:true});
      });

      // Filters
      if(faFlt.sezon&&faFlt.sezon!=='all') rows=rows.filter(function(r){return r.sezon===faFlt.sezon;});
      if(faFlt.seg&&faFlt.seg!=='all') rows=rows.filter(function(r){return r.seg===faFlt.seg;});
      if(faFlt.durum==='matched') rows=rows.filter(function(r){return r.hp&&r.hs;});
      else if(faFlt.durum==='noprice') rows=rows.filter(function(r){return !r.hp&&r.hs;});
      else if(faFlt.durum==='notsold') rows=rows.filter(function(r){return r.hp&&!r.hs;});

      rows.sort(function(a,b){var av=a[faSort]||0,bv=b[faSort]||0;return faSortDir*(bv-av);});

      var matchedCnt=rows.filter(function(r){return r.hp&&r.hs;}).length;
      var noPriceCnt=rows.filter(function(r){return !r.hp&&r.hs;}).length;
      var notSoldCnt=rows.filter(function(r){return r.hp&&!r.hs;}).length;
      var totalAdet=rows.reduce(function(a,r){return a+(r.adet||0);},0);
      var maxAdet=Math.max.apply(null,rows.map(function(r){return r.adet||0;}))||1;

      var BON='background:rgba(99,102,241,0.2);color:#a5b4fc;border:0.5px solid rgba(99,102,241,0.4);padding:3px 9px;border-radius:5px;font-size:10px;cursor:pointer;font-weight:600;';
      var BOFF='background:rgba(255,255,255,0.03);color:#475569;border:0.5px solid rgba(255,255,255,0.06);padding:3px 9px;border-radius:5px;font-size:10px;cursor:pointer;';

      var h='';

      // Year filter bar
      h+='<div style="display:flex;align-items:center;gap:4px;flex-wrap:wrap;margin-bottom:8px;padding:6px 10px;background:rgba(255,255,255,0.02);border-radius:7px;border:0.5px solid rgba(255,255,255,0.05)">';
      h+='<span style="font-size:9px;color:#475569;text-transform:uppercase;letter-spacing:0.5px;margin-right:4px">Dönem</span>';
      h+='<button class="fa-yil" data-y="all" style="'+(faYil==='all'?BON:BOFF)+'">Tümü (2021–)</button>';
      allYears.forEach(function(y){h+='<button class="fa-yil" data-y="'+y+'" style="'+(String(faYil)===String(y)?BON:BOFF)+'">'+y+'</button>';});
      h+='</div>';

      // Sezon + Segment + Durum filters
      h+='<div style="display:flex;align-items:center;gap:4px;flex-wrap:wrap;margin-bottom:10px;padding:8px 10px;background:rgba(255,255,255,0.025);border-radius:8px;border:0.5px solid rgba(255,255,255,0.06)">';
      [['all','Tüm Sezon'],['KIS','&#10052; Kış'],['YAZ','&#9728; Yaz'],['4MEVSIM','&#127782; 4M']].forEach(function(x){var on=faFlt.sezon===x[0];h+='<button class="fa-flt" data-fk="sezon" data-fv="'+x[0]+'" style="'+(on?BON:BOFF)+'">'+x[1]+'</button>';});
      h+='<span style="display:inline-block;width:1px;height:16px;background:rgba(255,255,255,0.08);margin:0 3px"></span>';
      // Segment buttons built from taxonomy
[['all','Tüm']].concat((wrap._aracKat||[]).map(function(k){return[k.id,k.label_tr];})).forEach(function(x){var on=faFlt.seg===x[0];h+='<button class="fa-flt" data-fk="seg" data-fv="'+x[0]+'" style="'+(on?BON:BOFF)+'">'+x[1]+'</button>';});
      h+='<span style="display:inline-block;width:1px;height:16px;background:rgba(255,255,255,0.08);margin:0 3px"></span>';
      [['all','Tümü'],['matched','Eşleşti'],['noprice','Fiyatsız'],['notsold','Satılmaz']].forEach(function(x){var on=faFlt.durum===x[0];h+='<button class="fa-flt" data-fk="durum" data-fv="'+x[0]+'" style="'+(on?BON:BOFF)+'">'+x[1]+'</button>';});
      h+='</div>';

      // Summary cards
      h+='<div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:10px">';
      [{l:'Eşleşen SKU',v:matchedCnt,c:'#60a5fa'},{l:'Fiyatsız Satış',v:noPriceCnt,c:'#f59e0b'},{l:'Satılmayan',v:notSoldCnt,c:'#475569'},{l:'Toplam Adet',v:Math.round(totalAdet).toLocaleString('tr-TR'),c:'#34d399'}].forEach(function(c){
        h+='<div style="padding:8px 14px;background:rgba(255,255,255,0.03);border:0.5px solid '+c.c+'30;border-radius:8px;flex:1;min-width:90px">';
        h+='<div style="font-size:9px;color:#475569;text-transform:uppercase;letter-spacing:0.5px">'+c.l+'</div>';
        h+='<div style="font-size:18px;font-weight:800;color:'+c.c+'">'+c.v+'</div></div>';
      });
      h+='</div>';

      wrap._firsatRows=rows;
      if(!rows.length){h+='<div style="padding:20px;color:#475569;text-align:center">Filtre kriterine uyan kayıt yok</div>';return h;}

      function thS(k,lbl,right){
        var active=faSort===k;
        var arr=active?(faSortDir<0?' ▾':' ▴'):'';
        return '<th class="fa-sort" data-k="'+k+'" style="text-align:'+(right?'right':'left')+';padding:5px 8px;color:'+(active?'#a5b4fc':'#475569')+';cursor:pointer;white-space:nowrap;font-size:10px;font-weight:700;user-select:none">'+lbl+arr+'</th>';
      }

      h+='<div style="display:flex;gap:16px;align-items:flex-start"><div style="flex:1;min-width:0"><div style="overflow-x:auto"><table style="border-collapse:collapse;width:100%;min-width:620px">';
      h+='<thead><tr style="border-bottom:0.5px solid rgba(255,255,255,0.1)">';
      h+=thS('ebat','Ebat',false)+thS('marka','Marka',false)+thS('desen','Model',false)+'<th style="padding:5px 8px;color:#475569;font-size:10px;font-weight:700;white-space:nowrap">Sezon</th>';
      h+=thS('adet','Adet',true)+thS('ciro','Ciro (K₺)',true)+thS('musteri','Müşteri',true);
      h+=thS('net','Net (₺)',true)+thS('endeks','Endeks',true)+'<th style="padding:5px 8px;color:#475569;font-size:10px;font-weight:700">Durum</th>';
      h+='</tr></thead><tbody>';

      var SZN={'KIS':'&#10052; Kış','YAZ':'&#9728; Yaz','4MEVSIM':'&#127782; 4M','4 MEVSIM':'&#127782; 4M'};
      var shown=rows.slice(0,300);
      shown.forEach(function(r,ri){
        var bg=ri%2===0?'rgba(255,255,255,0.012)':'transparent';
        h+='<tr style="background:'+bg+';border-bottom:0.5px solid rgba(255,255,255,0.03)">';
        h+='<td style="padding:2px 6px;color:#34d399;font-family:monospace;font-size:10px;white-space:nowrap">'+r.ebat+'</td>';
        var mc=r.marka==='LASSA'?'#60a5fa':r.hp?'#cbd5e1':'#94a3b8';
        var mn=r.marka.charAt(0)+r.marka.slice(1).toLowerCase();
        h+='<td style="padding:3px 8px;color:'+mc+';font-weight:600;white-space:nowrap">'+mn+'</td>';
        var nEx=r.nItems>1?'<span style="color:#334155;font-size:9px"> +'+( r.nItems-1)+'</span>':'';
        h+='<td style="padding:3px 8px;font-size:10px"><div style="color:'+(r.desen?'#94a3b8':'#334155')+';max-width:130px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">'+(r.desen||'—')+nEx+'</div></td>';
        h+='<td style="padding:3px 8px;white-space:nowrap;color:#64748b">'+(SZN[r.sezon]||r.sezon||'—')+'</td>';
        if(r.adet>0){var bw=Math.max(2,Math.round(r.adet/maxAdet*48));h+='<td style="padding:3px 8px;text-align:right"><div style="display:inline-flex;align-items:center;gap:4px"><div style="width:'+bw+'px;height:3px;background:#34d399;border-radius:2px"></div><span style="color:#f1f5f9;font-weight:600">'+Math.round(r.adet).toLocaleString('tr-TR')+'</span></div></td>';}
        else h+='<td style="padding:3px 8px;text-align:right;color:#2d3748">—</td>';
        h+='<td style="padding:3px 8px;text-align:right;color:'+(r.ciro>0?'#94a3b8':'#2d3748')+'">'+(r.ciro>0?Math.round(r.ciro/1000).toLocaleString('tr-TR')+'K':'—')+'</td>';
        h+='<td style="padding:3px 8px;text-align:right;color:'+(r.musteri>0?'#64748b':'#2d3748')+'">'+(r.musteri||'—')+'</td>';
        h+='<td style="padding:3px 8px;text-align:right;color:'+(r.net?'#cbd5e1':'#2d3748')+'">'+(r.net?r.net.toLocaleString('tr-TR')+'₺':'—')+'</td>';
        if(r.endeks===null||r.endeks===undefined) h+='<td style="padding:3px 8px;text-align:right;color:#2d3748">—</td>';
        else{var ec=r.endeks<95?'#34d399':r.endeks>108?'#f87171':'#fbbf24';var ebg='rgba('+(r.endeks<95?'52,211,153':r.endeks>108?'248,113,113':'251,191,36')+',0.12)';h+='<td style="padding:3px 8px;text-align:right"><span style="background:'+ebg+';color:'+ec+';font-weight:700;padding:1px 6px;border-radius:10px;font-size:10px">'+r.endeks+'</span></td>';}
        var dl,dc,db;
        if(r.hp&&r.hs){dl='&#10003; Eşleşti';dc='#34d399';db='rgba(52,211,153,0.1)';}
        else if(!r.hp&&r.hs){dl='&#9888; Fiyatsız';dc='#f59e0b';db='rgba(245,158,11,0.1)';}
        else{dl='&#9702; Satılmaz';dc='#475569';db='rgba(71,85,105,0.1)';}
        h+='<td style="padding:3px 8px"><span style="background:'+db+';color:'+dc+';padding:1px 7px;border-radius:10px;font-size:9px">'+dl+'</span></td>';
        h+='</tr>';
      });
      h+='</tbody></table></div>';
      if(rows.length>300) h+='<div style="padding:6px;color:#334155;font-size:10px;text-align:center">↳ İlk 300 gösteriliyor (toplam '+rows.length+')</div>';
      h+='</div>';
      h+='<div id="firsat-ai-panel" style="width:220px;flex-shrink:0;position:sticky;top:16px;max-height:calc(100vh - 160px);overflow-y:auto;background:rgba(8,12,22,0.92);border:0.5px solid rgba(99,102,241,0.3);border-radius:12px;padding:18px">';
      h+='<div style="font-size:9px;color:#6366f1;text-transform:uppercase;letter-spacing:1.2px;font-weight:800;margin-bottom:14px">&#129302; Fırsat Yorumu</div>';
      h+='<div id="firsat-ai-body" style="color:#475569;font-size:12px;line-height:1.7">&#9203; Analiz yükleniyor…</div>';
      h+='</div>';
      h+='</div>';
      var _aiFKey=[faYil,(faFlt.sezon||'all'),(faFlt.seg||'all')].join('|');
      if(wrap._aiKey!==_aiFKey){wrap._aiKey=_aiFKey;wrap._aiCache=null;}
      var _aiPld=rows.slice(0,20).map(function(r){return{marka:r.marka,ebat:r.ebat,sezon:r.sezon,adet:Math.round(r.adet||0),endeks:r.endeks,ciro:Math.round(r.ciro||0),durum:r.hp&&r.hs?'Eşleşti':!r.hp&&r.hs?'Fiyatsız':'Satılmaz'};});
      setTimeout(function(){
        var _aib=wrap.querySelector('#firsat-ai-body');if(!_aib)return;
        if(wrap._aiCache){_aib.innerHTML=_fmtAi(wrap._aiCache);return;}
        if(wrap._aiLoading)return;
        wrap._aiLoading=true;
        fetch('/api/ai/interpret-firsat',{method:'POST',credentials:'include',headers:{'content-type':'application/json'},body:JSON.stringify({rows:_aiPld,filters:{yil:faYil,sezon:faFlt.sezon||'all',seg:faFlt.seg||'all'}})})
          .then(function(r){return r.json();})
          .then(function(d){
            wrap._aiLoading=false;
            if(d&&d.text){wrap._aiCache=d.text;var e=wrap.querySelector('#firsat-ai-body');if(e)e.innerHTML=_fmtAi(d.text);}
          })
          .catch(function(){
            wrap._aiLoading=false;
            var e=wrap.querySelector('#firsat-ai-body');
            if(e)e.innerHTML='<div style="color:#374151">Analiz yüklenemedi.</div>';
          });
      },150);
      return h;
    }

    // ── Rekabet Analizi ────────────────────────────────────────────────────────
    // Piyasa fiyat matrisi: Cost | EM | EMR | 1EMR | 2EMR | 3EMR (tek satır/ürün)
    // Veriler: bi_pazar_fiyat (cimri scraper) × bi_fiyat_listesi_kalemler (KRB)
    function _buildRekabetContent(wrap) {
      var BON ='background:rgba(99,102,241,0.2);color:#a5b4fc;border:0.5px solid rgba(99,102,241,0.4);padding:3px 9px;border-radius:5px;font-size:10px;cursor:pointer;font-weight:600;';
      var BOFF='background:rgba(255,255,255,0.03);color:#475569;border:0.5px solid rgba(255,255,255,0.06);padding:3px 9px;border-radius:5px;font-size:10px;cursor:pointer;';
      var rFlt   = wrap._rFlt   || {sezon:'all'};
      var rSearch= (wrap._rSearch||'').trim().toUpperCase();

      // Kolon tanımları (tooltip)
      var DEFS = {
        'EM':   'marka + ebat + yük + hız + XL + sezon  (kendi marka, tam eşleşme)',
        'EMR':  'ebat + yük + hız + XL + sezon  (en ucuz rakip, tam spec)',
        '1EMR': 'ebat + yük + hız + sezon  (XL gözetilmez)',
        '2EMR': 'ebat + yük + sezon  (hız gözetilmez)',
        '3EMR': 'ebat + sezon  (piyasa tabanı)'
      };

      var h = '';

      // ── Filtre çubuğu ─────────────────────────────────────────────────────
      h+='<div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;margin-bottom:12px;padding:8px 12px;background:rgba(255,255,255,0.025);border-radius:8px;border:0.5px solid rgba(255,255,255,0.07)">';
      [['all','Tüm Sezon'],['KIS','❄️ Kış'],['YAZ','☀️ Yaz'],['4MEV','🌦 4M']].forEach(function(x){
        h+='<button class="rek-flt" data-fk="sezon" data-fv="'+x[0]+'" style="'+(rFlt.sezon===x[0]?BON:BOFF)+'">'+x[1]+'</button>';
      });
      h+='<div style="width:1px;height:18px;background:rgba(255,255,255,0.09);margin:0 2px"></div>';
      h+='<input class="rek-search" type="text" placeholder="🔍 ebat / marka…" value="'+rSearch.replace(/"/g,'&quot;')+'" style="background:rgba(255,255,255,0.05);border:0.5px solid rgba(255,255,255,0.12);border-radius:5px;padding:3px 10px;color:#f1f5f9;font-size:12px;width:150px;outline:none;font-family:monospace">';
      h+='<button class="rek-refresh" style="'+BOFF+';margin-left:auto" title="Veriyi yenile">↻ Yenile</button>';
      h+='</div>';

      // ── Yükleniyor / hata / boş ───────────────────────────────────────────
      if(!wrap._rekabetData && !wrap._rekabetError){
        h+='<div style="padding:48px;text-align:center;color:#475569"><div style="font-size:28px;margin-bottom:12px">⏳</div><div style="font-size:13px">Piyasa verisi yükleniyor…</div></div>';
        return h;
      }
      if(wrap._rekabetError){
        h+='<div style="padding:30px;text-align:center;color:#f87171;font-size:13px">Veri yüklenemedi — lütfen sayfayı yenileyin.</div>';
        return h;
      }

      var rows = (wrap._rekabetData||[]).slice();

      // Filtrele
      if(rFlt.sezon!=='all') rows=rows.filter(function(r){return r.krb_sezon===rFlt.sezon;});
      if(rSearch) rows=rows.filter(function(r){
        return (r.krb_ebat||'').includes(rSearch)||(r.krb_marka||'').toUpperCase().includes(rSearch)||(r.krb_desen||'').toUpperCase().includes(rSearch);
      });

      if(!rows.length){
        h+='<div style="padding:30px;text-align:center;color:#475569;font-size:13px">Bu filtre için ürün bulunamadı.</div>';
        if(!(wrap._rekabetData||[]).length){
          h+='<div style="padding:0 30px 30px;text-align:center">';
          h+='<div style="color:#64748b;font-size:12px;margin-bottom:10px">Piyasa verisi henüz yüklenmedi.</div>';
          h+='<code style="display:inline-block;background:rgba(255,255,255,0.04);border:0.5px solid rgba(255,255,255,0.1);border-radius:6px;padding:6px 12px;color:#a78bfa;font-size:11px">python3 /app/scripts/n11_cimri_scraper.py</code>';
          h+='</div>';
        }
        return h;
      }

      // ── Özet banner ───────────────────────────────────────────────────────
      var matched = rows.filter(function(r){return r.emr_fiyat_1;}).length;
      var zarar   = rows.filter(function(r){return r.uyari==='ZARAR_RİSKİ';}).length;
      h+='<div style="display:flex;gap:10px;flex-wrap:wrap;margin-bottom:12px">';
      [{l:'Toplam SKU',v:rows.length,c:'#60a5fa'},{l:'Piyasa Eşleşmesi',v:matched,c:'#34d399'},{l:'Zarar Riski',v:zarar,c:'#f87171'}].forEach(function(s){
        h+='<div style="padding:7px 14px;background:rgba('+s.c.replace('#','')+',0.06);border:0.5px solid '+s.c+'30;border-radius:8px;text-align:center">';
        h+='<div style="font-size:18px;font-weight:800;color:'+s.c+'">'+s.v+'</div>';
        h+='<div style="font-size:10px;color:#64748b;margin-top:1px">'+s.l+'</div></div>';
      });
      h+='</div>';

      // ── Tablo başlığı ─────────────────────────────────────────────────────
      function thTip(label, key){
        return '<th style="padding:6px 8px;text-align:right;color:#64748b;font-size:10px;font-weight:700;white-space:nowrap;cursor:help;border-bottom:1px solid rgba(255,255,255,0.07)" title="'+label+': '+(DEFS[key]||'')+'">'+label+' <span style="opacity:0.45;font-size:9px">ⓘ</span></th>';
      }

      h+='<div style="overflow-x:auto;max-height:520px;overflow-y:auto">';
      h+='<table style="width:100%;border-collapse:collapse;font-size:12px">';
      h+='<thead style="position:sticky;top:0;z-index:2;background:#0f172a"><tr>';
      h+='<th style="padding:6px 8px;text-align:left;color:#64748b;font-size:10px;font-weight:700;border-bottom:1px solid rgba(255,255,255,0.07);white-space:nowrap">Marka / Ebat</th>';
      h+='<th style="padding:6px 8px;text-align:left;color:#64748b;font-size:10px;font-weight:700;border-bottom:1px solid rgba(255,255,255,0.07)">Model / Spec</th>';
      h+='<th style="padding:6px 8px;text-align:right;color:#64748b;font-size:10px;font-weight:700;border-bottom:1px solid rgba(255,255,255,0.07);white-space:nowrap">Maliyet</th>';
      h+=thTip('EM','EM');
      h+=thTip('EMR','EMR');
      h+=thTip('1EMR','1EMR');
      h+=thTip('2EMR','2EMR');
      h+=thTip('3EMR','3EMR');
      h+='<th style="padding:6px 8px;text-align:center;color:#64748b;font-size:10px;font-weight:700;border-bottom:1px solid rgba(255,255,255,0.07)">Durum</th>';
      h+='</tr></thead><tbody>';

      rows.forEach(function(r,ri){
        var rowBg = ri%2===0?'rgba(255,255,255,0.008)':'transparent';
        if(r.uyari==='ZARAR_RİSKİ') rowBg='rgba(239,68,68,0.07)';
        else if(r.uyari==='SIFIR_MARJ') rowBg='rgba(251,191,36,0.05)';

        var spec=[(r.krb_yuk&&r.krb_hiz)?(r.krb_yuk+r.krb_hiz):null, r.krb_xl?'XL':null].filter(Boolean).join(' ');
        var sezonEmoji={KIS:'❄️',YAZ:'☀️','4MEV':'🌦'}[r.krb_sezon]||'';

        h+='<tr style="background:'+rowBg+';border-bottom:0.5px solid rgba(255,255,255,0.03)">';

        // Marka / Ebat
        h+='<td style="padding:6px 8px;white-space:nowrap">';
        h+='<div style="font-size:10px;color:#64748b;font-weight:600">'+esc(r.krb_marka||'')+'</div>';
        h+='<div style="font-size:12px;color:#e2e8f0;font-family:monospace;font-weight:700">'+esc(r.krb_ebat||'')+'</div>';
        h+='</td>';

        // Model / Spec
        h+='<td style="padding:6px 8px">';
        if(r.krb_desen) h+='<div style="font-size:10px;color:#94a3b8;max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+esc(r.krb_desen)+'">'+esc(r.krb_desen)+'</div>';
        h+='<div style="font-size:10px;color:#475569;white-space:nowrap">'+esc(spec)+' '+sezonEmoji+'</div>';
        h+='</td>';

        // Maliyet
        var mal=r.krb_maliyet?Math.round(parseFloat(r.krb_maliyet)).toLocaleString('tr-TR')+' ₺':'—';
        h+='<td style="padding:6px 8px;text-align:right;color:#64748b;font-family:monospace;font-size:11px;white-space:nowrap">'+mal+'</td>';

        // Fiyat hücresi
        function priceCell(fiyat,marka,urun,f2,f3,guv){
          if(!fiyat) return '<td style="padding:6px 8px;text-align:right;color:#2d3748;font-size:10px">—</td>';
          var f=parseFloat(fiyat);
          var col='#e2e8f0';
          var malV=r.krb_maliyet?parseFloat(r.krb_maliyet):null;
          if(guv===false||guv==='false') col='#fbbf24';
          if(malV&&f<malV) col='#f87171';
          else if(malV&&f>=malV*1.1) col='#34d399';
          var disp=Math.round(f).toLocaleString('tr-TR')+' ₺';
          var tip='';
          if(marka) tip+=marka+'\n';
          if(urun)  tip+=urun+'\n';
          if(f2) tip+='2. ucuz: '+Math.round(parseFloat(f2)).toLocaleString('tr-TR')+' ₺\n';
          if(f3) tip+='3. ucuz: '+Math.round(parseFloat(f3)).toLocaleString('tr-TR')+' ₺';
          var warn=(guv===false||guv==='false')?' ⚠':'';
          // popup data — click shows detail
          var pd=JSON.stringify({marka:marka||r.krb_marka,urun:urun||'',f1:fiyat,f2:f2,f3:f3}).replace(/"/g,'&quot;');
          return '<td style="padding:6px 8px;text-align:right"><span class="rek-price" data-pd="'+pd+'" style="color:'+col+';font-family:monospace;font-size:12px;font-weight:700;cursor:pointer;text-decoration:underline;text-decoration-style:dashed;text-decoration-color:'+col+'60" title="'+tip.replace(/"/g,'&quot;')+'">'+disp+warn+'</span></td>';
        }

        h+=priceCell(r.em_fiyat_1, r.krb_marka, null, r.em_fiyat_2, r.em_fiyat_3, r.em_guvenilir);
        h+=priceCell(r.emr_fiyat_1, r.emr_marka, r.emr_urun_adi, null, null, r.emr_guvenilir);
        h+=priceCell(r.one_emr_fiyat_1, r.one_emr_marka, r.one_emr_urun_adi, null, null, r.one_emr_guvenilir);
        h+=priceCell(r.two_emr_fiyat_1, r.two_emr_marka, r.two_emr_urun_adi, null, null, r.two_emr_guvenilir);
        h+=priceCell(r.three_emr_fiyat_1, r.three_emr_marka, r.three_emr_urun_adi, null, null, r.three_emr_guvenilir);

        // Durum
        var uyMap={'ZARAR_RİSKİ':'background:rgba(239,68,68,0.2);color:#f87171','SIFIR_MARJ':'background:rgba(251,191,36,0.2);color:#fbbf24','EM_ŞÜPHELİ':'background:rgba(148,163,184,0.12);color:#94a3b8','EMR_ŞÜPHELİ':'background:rgba(148,163,184,0.12);color:#94a3b8'};
        var uyariHtml=r.uyari?'<span style="'+uyMap[r.uyari]+';font-size:9px;padding:2px 5px;border-radius:3px;font-weight:700;white-space:nowrap">'+esc(r.uyari)+'</span>':'<span style="color:#374151;font-size:11px">✓</span>';
        h+='<td style="padding:6px 8px;text-align:center">'+uyariHtml+'</td>';
        h+='</tr>';
      });

      h+='</tbody></table></div>';

      // Popup (click'te gösterilir, document click ile kapanır)
      h+='<div id="rek-popup" style="display:none;position:fixed;z-index:9999;background:#1e293b;border:1px solid rgba(255,255,255,0.15);border-radius:10px;padding:14px 18px;min-width:220px;max-width:320px;box-shadow:0 8px 32px rgba(0,0,0,0.5);font-size:12px;color:#e2e8f0;pointer-events:none"></div>';

      return h;
    }

    function _piWire(wrap) {
      wrap.querySelectorAll('.pi-view-btn').forEach(function(b){
        b.addEventListener('click',function(){wrap._piView=this.dataset.v;_piRender(wrap);});
      });
      wrap.querySelectorAll('.fa-flt').forEach(function(b){
        b.addEventListener('click',function(){
          if(!wrap._faFlt)wrap._faFlt={sezon:'all',seg:'all',durum:'all'};
          wrap._faFlt[this.dataset.fk]=this.dataset.fv;
          _piRender(wrap);
        });
      });
      wrap.querySelectorAll('.ka-flt').forEach(function(b){
    b.addEventListener('click',function(){
      var fk=this.dataset.fk,fv=this.dataset.fv;
      if(fk==='__sort'){wrap._kaSort=fv;_piRender(wrap);return;}
      if(!wrap._kaFlt)wrap._kaFlt={sezon:'all',seg:'all'};
      wrap._kaFlt[fk]=fv;
      _piRender(wrap);
    });
  });
  wrap.querySelectorAll('.ka-view-btn').forEach(function(b){
    b.addEventListener('click',function(){wrap._kaView=this.dataset.v;_piRender(wrap);});
  });
  var _kaSearchEl=wrap.querySelector('#ka-search-input');
  if(_kaSearchEl){
    _kaSearchEl.addEventListener('input',function(){
      var _v=this.value;
      wrap._kaSearch=_v;
      _piRender(wrap);
      // Defer refocus until after browser finishes input event cycle
      setTimeout(function(){
        var _el=wrap.querySelector('#ka-search-input');
        if(_el){_el.focus();_el.setSelectionRange(_v.length,_v.length);}
      },0);
    });
  }
  wrap.querySelectorAll('.fa-yil').forEach(function(b){
        b.addEventListener('click',function(){wrap._faYil=this.dataset.y;_piRender(wrap);});
      });
      wrap.querySelectorAll('.fa-sort').forEach(function(th){
        th.addEventListener('click',function(){
          var k=this.dataset.k;
          if(wrap._faSort===k){wrap._faSortDir=wrap._faSortDir===-1?1:-1;}
          else{wrap._faSort=k;wrap._faSortDir=-1;}
          _piRender(wrap);
        });
      });
      // Cell click — model picker toggle
      wrap.querySelectorAll('.pi-cell').forEach(function(td){
        td.addEventListener('click',function(e){
          e.stopPropagation();
          wrap._expCell=wrap._expCell===td.dataset.ck?null:td.dataset.ck;
          _piRender(wrap);
        });
      });
      // Model selection button
      wrap.querySelectorAll('.pi-modpick').forEach(function(btn){
        btn.addEventListener('click',function(e){
          e.stopPropagation();
          if(!wrap._modelSel) wrap._modelSel={};
          if(wrap._modelSel[btn.dataset.ck]===btn.dataset.des) delete wrap._modelSel[btn.dataset.ck];
          else wrap._modelSel[btn.dataset.ck]=btn.dataset.des;
          wrap._expCell=null;
          _piRender(wrap);
        });
      });
      // Zam sim toggle
      var zt=wrap.querySelector('.pi-zam-toggle');
      if(zt) zt.addEventListener('click',function(){wrap._zamOn=!wrap._zamOn;_piRender(wrap);});
      // Zam +5
      wrap.querySelectorAll('.pi-zinc').forEach(function(btn){
        btn.addEventListener('click',function(){
          if(!wrap._zamSen) wrap._zamSen={};
          wrap._zamSen[btn.dataset.b]=Math.min(100,(wrap._zamSen[btn.dataset.b]||0)+5);
          _piRender(wrap);
        });
      });
      // Zam −5
      wrap.querySelectorAll('.pi-zinc-m').forEach(function(btn){
        btn.addEventListener('click',function(){
          if(!wrap._zamSen) wrap._zamSen={};
          wrap._zamSen[btn.dataset.b]=Math.max(-50,(wrap._zamSen[btn.dataset.b]||0)-5);
          _piRender(wrap);
        });
      });
      // Zam reset one brand
      wrap.querySelectorAll('.pi-zinc-r').forEach(function(btn){
        btn.addEventListener('click',function(){
          if(!wrap._zamSen) wrap._zamSen={};
          delete wrap._zamSen[btn.dataset.b];
          _piRender(wrap);
        });
      });
      // Zam reset all
      var zar=wrap.querySelector('.pi-zinc-all-r');
      if(zar) zar.addEventListener('click',function(){wrap._zamSen={};_piRender(wrap);});
      // Filters
      wrap.querySelectorAll('.pi-kflt').forEach(function(b){b.addEventListener('click',function(){wrap._katFlt=b.dataset.v;_piRender(wrap);});});
      wrap.querySelectorAll('.pi-sflt').forEach(function(b){b.addEventListener('click',function(){wrap._segFlt=b.dataset.v;_piRender(wrap);});});
      wrap.querySelectorAll('.pi-rflt').forEach(function(b){b.addEventListener('click',function(){wrap._rimGrp=b.dataset.v;_piRender(wrap);});});
      wrap.querySelectorAll('.pi-ctflt').forEach(function(b){b.addEventListener('click',function(){wrap._costType=b.dataset.v;_piRender(wrap);});});
      // Ebat search
      (function(){
        var _sch=wrap.querySelector('.pi-ebat-search');
        function applyQ(q){
          wrap.querySelectorAll('tr[data-ebat]').forEach(function(tr){
            var show=!q||tr.dataset.ebat.toLowerCase().includes(q);
            tr.style.display=show?'':'none';
            var nx=tr.nextElementSibling;
            if(nx&&!nx.hasAttribute('data-ebat')) nx.style.display=show?'':'none';
          });
        }
        if(_sch){
          _sch.addEventListener('input',function(){wrap._ebatSearch=this.value;applyQ((this.value||'').trim().toLowerCase());});
          if(wrap._ebatSearch) applyQ(wrap._ebatSearch.trim().toLowerCase());
        }
      })();
      // AI button
      var aiBtn=wrap.querySelector('#pi-ai-btn');
      if(aiBtn) aiBtn.addEventListener('click',async function(){
        var res=wrap.querySelector('#pi-ai-result'); if(!res) return;
        res.innerHTML='<span style="color:#6366f1;font-size:11px">Analiz yapılıyor...</span>';
        var brands=[...new Set((wrap._items||[]).map(function(i){return i.marka;}))].join(', ');
        var segs=[...new Set((wrap._items||[]).map(function(i){return i.segment||''}))].filter(Boolean).join(', ');
        var prompt='KRB Lastik fiyat endeksi — LASSA=100 bazında marka karşılaştırması. Markalar: '+brands+'. Segmentler: '+segs+'. Net maliyet bazlı rekabet pozisyonu hakkında 2-3 kısa cümle yaz. Türkçe.';
        try {
          var d=await apiFetch('/api/ai/chat',{method:'POST',body:JSON.stringify({message:prompt,context:'pricing'})});
          res.textContent=d.reply||'Analiz tamamlandı.';
        } catch(e){ res.textContent='AI analizi şu an mevcut değil.'; }
      });

      // ── Rekabet panel event handlers ────────────────────────────────────────
      // Filtre butonları
      wrap.querySelectorAll('.rek-flt').forEach(function(b){
        b.addEventListener('click',function(){
          if(!wrap._rFlt) wrap._rFlt={sezon:'all'};
          wrap._rFlt[this.dataset.fk]=this.dataset.fv;
          _piRender(wrap);
        });
      });
      // Arama
      (function(){
        var _rs=wrap.querySelector('.rek-search');
        if(!_rs) return;
        _rs.addEventListener('input',function(){
          var v=this.value;
          wrap._rSearch=v;
          _piRender(wrap);
          setTimeout(function(){var el2=wrap.querySelector('.rek-search');if(el2){el2.focus();el2.setSelectionRange(v.length,v.length);}},0);
        });
      })();
      // Yenile
      var _rRef=wrap.querySelector('.rek-refresh');
      if(_rRef) _rRef.addEventListener('click',function(){
        wrap._rekabetData=null; wrap._rekabetError=false; wrap._rekabetLoading=false;
        _piRender(wrap);
      });
      // Fiyat hücresi tıkla — popup göster
      wrap.querySelectorAll('.rek-price').forEach(function(sp){
        sp.addEventListener('click',function(e){
          e.stopPropagation();
          var popup=wrap.querySelector('#rek-popup'); if(!popup) return;
          try { var pd=JSON.parse(this.dataset.pd.replace(/&quot;/g,'"')); } catch(er){ return; }
          var html='';
          if(pd.marka) html+='<div style="font-size:11px;color:#94a3b8;font-weight:700;margin-bottom:4px">'+esc(pd.marka)+'</div>';
          if(pd.urun)  html+='<div style="font-size:11px;color:#cbd5e1;margin-bottom:8px;line-height:1.4">'+esc(pd.urun)+'</div>';
          html+='<div style="display:flex;flex-direction:column;gap:4px">';
          if(pd.f1) html+='<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:#64748b">En Ucuz</span><span style="color:#34d399;font-weight:700;font-family:monospace">'+Math.round(parseFloat(pd.f1)).toLocaleString('tr-TR')+' ₺</span></div>';
          if(pd.f2) html+='<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:#64748b">2. Ucuz</span><span style="color:#94a3b8;font-family:monospace">'+Math.round(parseFloat(pd.f2)).toLocaleString('tr-TR')+' ₺</span></div>';
          if(pd.f3) html+='<div style="display:flex;justify-content:space-between;gap:16px"><span style="color:#64748b">3. Ucuz</span><span style="color:#94a3b8;font-family:monospace">'+Math.round(parseFloat(pd.f3)).toLocaleString('tr-TR')+' ₺</span></div>';
          html+='</div>';
          popup.innerHTML=html;
          popup.style.display='block';
          popup.style.pointerEvents='none';
          var rect=sp.getBoundingClientRect();
          popup.style.left=Math.min(rect.left, window.innerWidth-340)+'px';
          popup.style.top=(rect.bottom+6)+'px';
          // Auto-close after 3s
          clearTimeout(popup._t);
          popup._t=setTimeout(function(){popup.style.display='none';},3000);
        });
      });
      // Popup kapat (document click)
      document.addEventListener('click',function(){
        var popup=wrap.querySelector('#rek-popup');
        if(popup) popup.style.display='none';
      },{once:true});
    }

    el.querySelector('#pl-kat-filter').addEventListener('change', loadUploads);
    el.querySelector('#pl-brand-filter').addEventListener('change', loadUploads);
    el.querySelector('#pl-ebat-btn').addEventListener('click', runCompare);
    el.querySelector('#pl-ebat-inp').addEventListener('keydown', function(e){ if (e.key==='Enter') runCompare(); });

    await loadUploads();
  }

  // ── Marka Fırsatları room ─────────────────────────────────────────────────
  async function loadBrandAnalysis() {
    const el = container.querySelector('#vmo-room-brand-analysis');
    if (!el) return;
    if (el._baInit) return;
    el._baInit = true;
    el.style.overflowY = 'auto';
    el.style.flexDirection = 'column';

    let baKategori = 'ALL';
    let baRef = 'LASSA';

    // ─ Render shell ─
    el.innerHTML =
      '<div style="padding:8px 0">' +
        '<div style="margin-bottom:14px;display:flex;align-items:baseline;gap:10px;flex-wrap:wrap">' +
          '<span style="font-weight:700;color:#f1f5f9;font-size:15px">🔍 Marka Fırsatları</span>' +
          '<span style="font-size:11px;color:#64748b">Aynı ebatta markalar arası maliyet · fiyat · marj · bekleme süresi karşılaştırması</span>' +
        '</div>' +
        // Kategori pills
        '<div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:14px" id="ba-kat-pills">' +
          [['ALL','Tümü','#be185d'],['YAZ','Yaz ☀️','#d97706'],['KIS','Kış ❄️','#0891b2'],
           ['4 MEVSIM','4 Mevsim','#059669'],['TBR','TBR','#7c3aed'],['OTR','OTR','#b45309'],
           ['LSR','LSR','#0d9488'],['IND','Endüstriyel','#64748b']]
          .map(function(item, i) {
            return '<button class="ba-kat-btn" data-kat="' + item[0] + '" data-color="' + item[2] + '"' +
              ' style="padding:5px 13px;border-radius:20px;border:1px solid rgba(255,255,255,' + (i===0?'0.35':'0.12') +
              ');background:' + (i===0?'rgba(190,24,93,0.2)':'rgba(255,255,255,0.04)') +
              ';color:' + (i===0?'#f9a8d4':'#94a3b8') + ';font-size:12px;cursor:pointer;white-space:nowrap">' + item[1] + '</button>';
          }).join('') +
        '</div>' +
        // Search bar
        '<div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:18px">' +
          '<div style="position:relative">' +
            '<input id="ba-ebat-input" type="text" placeholder="Ebat — ör: 205/55R16" list="ba-ebat-list" autocomplete="off"' +
            ' style="background:#1e293b;border:1px solid rgba(255,255,255,0.15);border-radius:8px;padding:8px 12px;font-size:13px;color:#f1f5f9;outline:none;width:210px">' +
            '<datalist id="ba-ebat-list"></datalist>' +
          '</div>' +
          '<select id="ba-months-sel" style="background:#1e293b;border:1px solid rgba(255,255,255,0.15);border-radius:8px;padding:8px 10px;font-size:12px;color:#94a3b8;cursor:pointer">' +
            '<option value="6">6 Ay</option><option value="12" selected>12 Ay</option><option value="24">24 Ay</option>' +
          '</select>' +
          '<button id="ba-search-btn"' +
          ' style="background:linear-gradient(135deg,#be185d,#9d174d);color:#fff;border:none;border-radius:8px;padding:8px 22px;font-size:13px;font-weight:600;cursor:pointer">Karşılaştır →</button>' +
        '</div>' +
        '<div id="ba-results"></div>' +
      '</div>';

    async function refreshEbatList() {
      try {
        var q = (container.querySelector('#ba-ebat-input') || {}).value || '';
        var data = await apiFetch('/api/bi/brand-compare/sizes?q=' + encodeURIComponent(q) + '&kategori=' + encodeURIComponent(baKategori));
        var dl = container.querySelector('#ba-ebat-list');
        if (dl) dl.innerHTML = (data.sizes || []).map(function(e) { return '<option value="' + e + '">'; }).join('');
      } catch(e) {}
    }

    async function runCompare() {
      var ebat = ((container.querySelector('#ba-ebat-input') || {}).value || '').trim();
      if (!ebat) {
        container.querySelector('#ba-results').innerHTML = '<div style="color:#94a3b8;font-size:13px;padding:16px 0">Lütfen bir ebat girin.</div>';
        return;
      }
      var months = parseInt((container.querySelector('#ba-months-sel') || {}).value || '12');
      var resEl = container.querySelector('#ba-results');
      resEl.innerHTML = '<div class="vmo-kpi-loading">Analiz yapılıyor…</div>';
      try {
        var data = await apiFetch(
          '/api/bi/brand-compare?ebat=' + encodeURIComponent(ebat) +
          '&kategori=' + encodeURIComponent(baKategori) +
          '&months=' + months
        );
        var rows = data.brands || [];
        if (!rows.length) {
          resEl.innerHTML = '<div class="vmo-no-data">Bu ebat + kategori için satış kaydı bulunamadı.</div>';
          return;
        }
        var margins = rows.map(function(r) { return parseFloat(r.margin_unit) || 0; });
        var maxM = Math.max.apply(null, margins);
        var minM = Math.min.apply(null, margins);
        var range = maxM - minM || 1;
        // Compute reference brand weighted avg cost for size index
        var refRows = rows.filter(function(r){ return r.marka === baRef && r.avg_cost; });
        var refCost = null;
        if (refRows.length > 0) {
          var rTU = refRows.reduce(function(acc,r){ return acc+(parseInt(r.total_units)||0); }, 0);
          refCost = rTU > 0
            ? refRows.reduce(function(acc,r){ return acc+(parseFloat(r.avg_cost)||0)*(parseInt(r.total_units)||0); }, 0) / rTU
            : (parseFloat(refRows[0].avg_cost) || null);
        }

        var html =
          '<div style="font-size:12px;color:#64748b;margin-bottom:10px">' +
            '<strong style="color:#f9a8d4">' + ebat + '</strong>' +
            (baKategori !== 'ALL' ? ' · ' + baKategori : '') +
            ' · ' + rows.length + ' ürün · Son ' + months + ' ay' +
            ' · <span style="color:#64748b">Büyük marjdan küçüğe sıralı</span>' +
          '</div>' +
          '<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:12px">' +
          '<thead><tr style="border-bottom:2px solid rgba(255,255,255,0.12)">' +
          '<th style="text-align:left;padding:7px 8px;color:#94a3b8">#</th>' +
          '<th style="text-align:left;padding:7px 8px;color:#94a3b8">Ürün Adı</th>' +
          '<th style="text-align:left;padding:7px 8px;color:#94a3b8">Marka</th>' +
          '<th style="text-align:center;padding:7px 8px;color:#94a3b8;cursor:help" title="Maliyet endeksi: referans marka = 100. Marka Endeksi panelinden referansı değiştirin.">İndeks</th>' +
          '<th style="text-align:right;padding:7px 8px;color:#94a3b8;cursor:help" title="Ortalama alış/stok maliyeti (birim)">Maliyet ①</th>' +
          '<th style="text-align:right;padding:7px 8px;color:#94a3b8;cursor:help" title="Ortalama fatura satış fiyatı (birim)">Satış Fiyatı</th>' +
          '<th style="text-align:right;padding:7px 8px;color:#94a3b8;cursor:help" title="Birim başına tahmini brüt kâr — Satış Fiyatı eksi Maliyet">Marj/Adet ₺</th>' +
          '<th style="text-align:right;padding:7px 8px;color:#94a3b8;cursor:help" title="Maliyete göre kâr yüzdesi">Marj %</th>' +
          '<th style="text-align:center;padding:7px 8px;color:#94a3b8;cursor:help" title="Seçili dönemdeki toplam satış adedi">Adet</th>' +
          '<th style="text-align:center;padding:7px 8px;color:#94a3b8;cursor:help" title="Son alıştan itibaren ortalama stokta bekleme süresi (gün)">Bekleme</th>' +
          '<th style="text-align:center;padding:7px 8px;color:#94a3b8;cursor:help" title="Mevcut stoku güncel satış hızıyla tüketme süresi (gün)">Stok Eritme</th>' +
          '<th style="text-align:right;padding:7px 8px;color:#94a3b8;cursor:help" title="Seçili dönem toplam cirosu">Ciro</th>' +
          '</tr></thead><tbody>' +
          rows.map(function(r, i) {
            var margin = (r.avg_cost != null && r.avg_cost !== '' && r.margin_unit != null) ? parseFloat(r.margin_unit) : null;
            var marginPct = parseFloat(r.margin_pct);
            var mColor = margin == null ? '#475569' : margin > 0 ? '#4ade80' : '#f87171';
            var barW = margin == null ? 0 : Math.round(Math.max(0, (margin - minM) / range) * 100);
            var isTop = i === 0;
            var isRef = r.marka === baRef;
            var sizeIdx = (refCost && r.avg_cost && parseFloat(r.avg_cost) > 0)
              ? Math.round(parseFloat(r.avg_cost) / refCost * 100)
              : (isRef && refCost ? 100 : null);
            var waitDays = r.avg_days_on_hand != null ? parseInt(r.avg_days_on_hand) : null;
            var clearDays = r.days_to_clear != null ? parseInt(r.days_to_clear) : null;
            var clearColor = clearDays != null && clearDays < 30 ? '#fbbf24' : clearDays != null && clearDays < 7 ? '#ef4444' : '#94a3b8';
            return '<tr style="border-bottom:1px solid rgba(255,255,255,0.05);' +
              (isTop ? 'background:rgba(190,24,93,0.07)' : (i%2===0?'background:rgba(255,255,255,0.015)':'')) + '">' +
              '<td style="padding:7px 8px;color:#64748b">' + (i+1) + '</td>' +
              '<td style="padding:7px 8px;color:#f1f5f9;font-weight:' + (isTop?'700':'500') + '">' +
                (r.kalem_tanimi || r.kalem_kodu || '—') +
                (isTop ? ' <span style="font-size:10px;background:rgba(190,24,93,0.3);color:#f9a8d4;border-radius:4px;padding:1px 6px;margin-left:4px">EN İYİ</span>' : '') +
              '</td>' +
              '<td style="padding:7px 8px;color:#94a3b8;font-size:11px">' + (r.marka || '—') + '</td>' +
              '<td style="padding:7px 8px;text-align:center">' +
                (sizeIdx == null ? '<span style="color:#475569">—</span>' :
                  '<span style="color:' + (sizeIdx === 100 ? '#f9a8d4' : sizeIdx < 100 ? '#4ade80' : '#f87171') + ';font-weight:700;font-size:13px">' + sizeIdx + '</span>') +
              '</td>' +
              '<td style="padding:7px 8px;text-align:right;color:#94a3b8">' + (r.avg_cost ? fmtAbbrev(parseFloat(r.avg_cost)) + ' ₺' : '<span style="color:#475569">—</span>') + '</td>' +
              '<td style="padding:7px 8px;text-align:right;color:#e2e8f0">' + fmtAbbrev(parseFloat(r.avg_sale_price)||0) + ' ₺</td>' +
              '<td style="padding:7px 8px;text-align:right">' +
                '<div style="display:inline-flex;align-items:center;gap:5px">' +
                  '<div style="width:36px;height:4px;background:rgba(255,255,255,0.08);border-radius:2px;overflow:hidden">' +
                    '<div style="height:100%;width:' + barW + '%;background:' + mColor + ';border-radius:2px"></div>' +
                  '</div>' +
                  '<span style="color:' + mColor + ';font-weight:600">' + (margin == null ? '—' : (margin >= 0 ? '+' : '') + fmtAbbrev(margin) + ' ₺') + '</span>' +
                '</div>' +
              '</td>' +
              '<td style="padding:7px 8px;text-align:right;color:' + mColor + '">' +
                (isNaN(marginPct) ? '<span style="color:#475569">—</span>' : (marginPct >= 0 ? '+' : '') + marginPct.toFixed(1) + '%') +
              '</td>' +
              '<td style="padding:7px 8px;text-align:center;color:#94a3b8">' + (parseInt(r.total_units)||0).toLocaleString('tr-TR') + '</td>' +
              '<td style="padding:7px 8px;text-align:center;color:#94a3b8">' + (waitDays != null ? waitDays + ' gün' : '—') + '</td>' +
              '<td style="padding:7px 8px;text-align:center;color:' + clearColor + '">' + (clearDays != null ? clearDays + ' gün' : '—') + '</td>' +
              '<td style="padding:7px 8px;text-align:right;color:#94a3b8">' + fmtAbbrev(parseFloat(r.total_revenue)||0) + ' ₺</td>' +
              '</tr>';
          }).join('') +
          '</tbody></table></div>';
        resEl.innerHTML = html;
      } catch(e) {
        resEl.innerHTML = '<div class="vmo-kpi-err">Yüklenemedi: ' + e.message + '</div>';
      }
    }

    // ── Marka Endeksi & Anomali Paneli ──────────────────────────────────────
    el.insertAdjacentHTML('beforeend',
      '<div id="ba-endeks-wrap" style="flex:0 0 100%;width:100%;box-sizing:border-box;margin-top:28px;padding-top:22px;border-top:1px solid rgba(255,255,255,0.1)">' +
        '<div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;flex-wrap:wrap">' +
          '<span style="font-size:14px;font-weight:700;color:#f1f5f9">🔢 Marka Endeksi</span>' +
          '<select id="ba-endeks-kat" style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:5px 8px;color:#94a3b8;font-size:12px;outline:none">' +
        '<option value="ALL">Tüm</option><option value="YAZ" selected>YAZ</option><option value="KIS">KIS</option><option value="4 MEVSIM">4 Mevsim</option><option value="TBR">TBR</option>' +
        '</select>' +
        '<input id="ba-ref-input" type="text" value="LASSA" ' +
            'style="width:80px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.18);border-radius:6px;padding:5px 10px;color:#f1f5f9;font-size:12px;outline:none;text-transform:uppercase" ' +
            'placeholder="Ref marka">' +
          '<button id="ba-idx-btn" style="background:rgba(190,24,93,0.25);border:1px solid rgba(190,24,93,0.45);border-radius:6px;padding:5px 14px;color:#f9a8d4;font-size:12px;cursor:pointer">Endeksi Göster</button>' +
        '</div>' +
        '<div id="ba-idx-results" style="font-size:12px;color:#94a3b8;max-height:340px;overflow-y:auto">Referans markayı girin ve Endeksi Göster butonuna basın.</div>' +
        '<div style="margin-top:18px;padding-top:16px;border-top:1px solid rgba(255,255,255,0.07)">' +
          '<div style="display:flex;align-items:center;gap:10px;margin-bottom:10px;flex-wrap:wrap">' +
            '<span style="font-size:13px;font-weight:600;color:#f1f5f9">⚡ Anomali Tespiti</span>' +
            '<span style="font-size:12px;color:#94a3b8">Eşik: <strong id="ba-thr-val" style="color:#fbbf24">10</strong> pt</span>' +
            '<input id="ba-thr-slider" type="range" min="5" max="40" value="10" style="width:100px;accent-color:#be185d">' +
            '<button id="ba-alert-btn" style="background:rgba(245,158,11,0.15);border:1px solid rgba(245,158,11,0.35);border-radius:6px;padding:5px 14px;color:#fbbf24;font-size:12px;cursor:pointer">Anomali Tara</button>' +
          '</div>' +
          '<div id="ba-alert-results" style="font-size:12px;color:#94a3b8">Eşik seçin ve Anomali Tara butonuna basın.</div>' +
        '</div>' +
      '</div>'
    );

    async function loadEndeksPanel() {
      var ri = el.querySelector('#ba-ref-input');
      if (ri) baRef = (ri.value || 'LASSA').trim().toUpperCase();
      var months = parseInt((container.querySelector('#ba-months-sel') || {}).value || '12');
      var idxEl = el.querySelector('#ba-idx-results');
      idxEl.innerHTML = '<div class="vmo-kpi-loading">Yükleniyor…</div>';
      try {
        var baEndeksKat = (el.querySelector('#ba-endeks-kat') || {}).value || 'YAZ';
        var data = await apiFetch('/api/bi/brand-index?ref=' + encodeURIComponent(baRef) + '&months=' + months + '&kategori=' + encodeURIComponent(baEndeksKat));
        var brands = (data.brands || []).filter(function(b){ return parseFloat(b.global_index) > 0 && parseFloat(b.global_index) <= 400; });
        if (!brands.length) {
          idxEl.innerHTML = '<div style="color:#94a3b8;font-size:13px;padding:8px 0">Bu referans marka için veri bulunamadı.</div>';
          return;
        }
        var maxIdx = Math.max.apply(null, brands.map(function(b){ return parseFloat(b.global_index)||0; })) || 200;
        var refRow = brands.find(function(b){ return b.marka === baRef; });
        var refLabel = refRow ? ' (' + fmtAbbrev(parseFloat(refRow.weighted_avg_cost)||0) + ' ₺)' : '';
        var html =
          '<div style="font-size:11px;color:#64748b;margin-bottom:8px">Referans: <strong style="color:#f9a8d4">' + baRef + ' = 100' + refLabel + '</strong>' +
          ' · Ağırlıklı ort. alış maliyeti · Yeşil = daha ucuz, Kırmızı = daha pahalı</div>' +
          '<table style="width:100%;border-collapse:collapse;font-size:12px">' +
          '<thead><tr style="border-bottom:1px solid rgba(255,255,255,0.1)">' +
          '<th style="text-align:left;padding:5px 8px;color:#94a3b8">Marka</th>' +
          '<th style="padding:5px 8px;color:#94a3b8">Endeks</th>' +
          '<th style="text-align:right;padding:5px 8px;color:#94a3b8">Ort. Maliyet</th>' +
          '<th style="text-align:right;padding:5px 8px;color:#94a3b8">Toplam Adet</th>' +
          '</tr></thead><tbody>' +
          brands.map(function(b) {
            var idx = parseFloat(b.global_index) || 0;
            var isRefB = b.marka === baRef;
            var barW = Math.min(100, Math.round(idx / maxIdx * 100));
            var col = isRefB ? '#f9a8d4' : idx <= 100 ? '#4ade80' : '#f87171';
            return '<tr style="border-bottom:1px solid rgba(255,255,255,0.04)">' +
              '<td style="padding:5px 8px;color:#f1f5f9">' + b.marka +
                (isRefB ? ' <span style="font-size:9px;background:rgba(190,24,93,0.3);color:#f9a8d4;border-radius:3px;padding:1px 4px">REF</span>' : '') +
              '</td>' +
              '<td style="padding:5px 8px">' +
                '<div style="display:flex;align-items:center;gap:6px">' +
                  '<div style="width:80px;height:4px;background:rgba(255,255,255,0.08);border-radius:2px;flex-shrink:0">' +
                    '<div style="width:' + barW + '%;height:100%;background:' + col + ';border-radius:2px"></div>' +
                  '</div>' +
                  '<span style="color:' + col + ';font-weight:700;min-width:36px">' + idx + '</span>' +
                '</div>' +
              '</td>' +
              '<td style="padding:5px 8px;text-align:right;color:#94a3b8">' + fmtAbbrev(parseFloat(b.weighted_avg_cost)||0) + ' ₺</td>' +
              '<td style="padding:5px 8px;text-align:right;color:#64748b">' + (parseInt(b.total_units)||0).toLocaleString('tr-TR') + '</td>' +
              '</tr>';
          }).join('') +
          '</tbody></table>';
        idxEl.innerHTML = html;
      } catch(e) { idxEl.innerHTML = '<div class="vmo-kpi-err">Hata: ' + e.message + '</div>'; }
    }

    async function runAlerts() {
      var ri = el.querySelector('#ba-ref-input');
      if (ri) baRef = (ri.value || 'LASSA').trim().toUpperCase();
      var thr = parseInt((el.querySelector('#ba-thr-slider') || {}).value || '10');
      var months = parseInt((container.querySelector('#ba-months-sel') || {}).value || '12');
      var alertEl = el.querySelector('#ba-alert-results');
      alertEl.innerHTML = '<div class="vmo-kpi-loading">Taranıyor…</div>';
      try {
        var data = await apiFetch(
          '/api/bi/brand-alerts?ref=' + encodeURIComponent(baRef) +
          '&months=' + months + '&threshold=' + thr
        );
        var alerts = data.alerts || [];
        if (!alerts.length) {
          alertEl.innerHTML = '<div style="color:#94a3b8;font-size:13px;padding:8px 0">Bu eşikte anomali bulunamadı. Eşiği düşürün.</div>';
          return;
        }
        var html =
          '<div style="font-size:11px;color:#64748b;margin-bottom:8px">' + alerts.length +
          ' anomali · ' + baRef + ' = 100 · Eşik ±' + thr + ' puan</div>' +
          '<table style="width:100%;border-collapse:collapse;font-size:12px">' +
          '<thead><tr style="border-bottom:1px solid rgba(255,255,255,0.1)">' +
          '<th style="text-align:left;padding:5px 8px;color:#94a3b8">Ebat</th>' +
          '<th style="text-align:left;padding:5px 8px;color:#94a3b8">Marka</th>' +
          '<th style="text-align:center;padding:5px 8px;color:#94a3b8" title="Bu markanın tüm ebatlardaki normal endeksi">Normal</th>' +
          '<th style="text-align:center;padding:5px 8px;color:#94a3b8" title="Bu ebattaki endeksi">Bu Ebat</th>' +
          '<th style="text-align:center;padding:5px 8px;color:#94a3b8">Sapma</th>' +
          '<th style="text-align:right;padding:5px 8px;color:#94a3b8">Adet</th>' +
          '</tr></thead><tbody>' +
          alerts.map(function(a) {
            var dev = parseFloat(a.deviation);
            var devCol = dev > 0 ? '#f87171' : '#4ade80';
            var devTip = dev > 0
              ? 'Bu ebatta normalden pahalı (alım fırsatı kaçırılmış olabilir)'
              : 'Bu ebatta normalden ucuz (fiyatlama fırsatı)';
            return '<tr style="border-bottom:1px solid rgba(255,255,255,0.04)">' +
              '<td style="padding:5px 8px;color:#f1f5f9;font-weight:500">' + a.ebat + '</td>' +
              '<td style="padding:5px 8px;color:#94a3b8">' + a.marka + '</td>' +
              '<td style="padding:5px 8px;text-align:center;color:#64748b">' + a.global_index + '</td>' +
              '<td style="padding:5px 8px;text-align:center;color:#f1f5f9;font-weight:600">' + a.size_index + '</td>' +
              '<td style="padding:5px 8px;text-align:center;color:' + devCol + ';font-weight:700" title="' + devTip + '">' +
                (dev > 0 ? '▲ +' : '▼ ') + Math.abs(dev).toFixed(1) +
              '</td>' +
              '<td style="padding:5px 8px;text-align:right;color:#64748b">' + (parseInt(a.units)||0) + '</td>' +
              '</tr>';
          }).join('') +
          '</tbody></table>';
        alertEl.innerHTML = html;
      } catch(e) { alertEl.innerHTML = '<div class="vmo-kpi-err">Hata: ' + e.message + '</div>'; }
    }

    var idxBtn = el.querySelector('#ba-idx-btn');
    if (idxBtn) idxBtn.addEventListener('click', loadEndeksPanel);
    var alertBtn = el.querySelector('#ba-alert-btn');
    if (alertBtn) alertBtn.addEventListener('click', runAlerts);
    var thrSlider = el.querySelector('#ba-thr-slider');
    var thrVal = el.querySelector('#ba-thr-val');
    if (thrSlider && thrVal) thrSlider.addEventListener('input', function(){ thrVal.textContent = thrSlider.value; });
    var refInput = el.querySelector('#ba-ref-input');
    if (refInput) refInput.addEventListener('change', function(){
      baRef = (refInput.value || 'LASSA').trim().toUpperCase();
      refInput.value = baRef;
    });

    // Wire events
    container.querySelectorAll('.ba-kat-btn').forEach(function(btn) {
      btn.addEventListener('click', function() {
        container.querySelectorAll('.ba-kat-btn').forEach(function(b) {
          b.style.background = 'rgba(255,255,255,0.04)';
          b.style.borderColor = 'rgba(255,255,255,0.12)';
          b.style.color = '#94a3b8';
        });
        var c = btn.dataset.color || '#be185d';
        btn.style.background = 'rgba(190,24,93,0.2)';
        btn.style.borderColor = 'rgba(255,255,255,0.35)';
        btn.style.color = '#f9a8d4';
        baKategori = btn.dataset.kat;
        refreshEbatList();
      });
    });

    var inp = container.querySelector('#ba-ebat-input');
    if (inp) {
      inp.addEventListener('input', function() { refreshEbatList(); });
      inp.addEventListener('keydown', function(e) { if (e.key === 'Enter') runCompare(); });
    }
    var btn = container.querySelector('#ba-search-btn');
    if (btn) btn.addEventListener('click', runCompare);

    refreshEbatList();
  }

  
  // =========================================================================
  // Rakip Fiyatlar — loadRakipRoom (initBiSurface içinde)
  // =========================================================================
  function loadRakipRoom(cont, _apiFetch) {
    // DARK_THEME_V1
    const room = cont.querySelector('#vmo-room-rakip .vmo-data-wall') || cont.querySelector('#vmo-room-rakip');
    if (!room) return;

    room.innerHTML = `
      <div style="flex:1;overflow-y:auto;padding:24px;max-width:1200px;margin:0 auto;width:100%">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px">
          <h2 style="margin:0;font-size:22px;font-weight:700;color:#ef4444">Rakip Fiyatlar</h2>
          <div id="rf-ozet-bar" style="display:flex;gap:16px;font-size:13px;color:#9ab"></div>
        </div>
        <div style="display:flex;gap:0;border-bottom:2px solid rgba(255,255,255,0.15);margin-bottom:20px">
          <button onclick="rfTab('piyasa')" id="rf-tab-piyasa"
            style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;
                   cursor:pointer;border-bottom:3px solid #3182ce;color:#3182ce;margin-bottom:-2px">Ham Veri</button>
          <button onclick="rfTab('akilli')" id="rf-tab-akilli" style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;cursor:pointer;border-bottom:3px solid transparent;color:#778;margin-bottom:-2px">🎯 Smart Matched</button>
          <button onclick="rfTab('trend')" id="rf-tab-trend" style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;cursor:pointer;border-bottom:3px solid transparent;color:#778;margin-bottom:-2px">📈 Fiyat Trendi</button>
          <button onclick="rfTab('dot')" id="rf-tab-dot" style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;cursor:pointer;border-bottom:3px solid transparent;color:#778;margin-bottom:-2px">📅 Eski Üretim (DOT)</button>
          <button onclick="rfTab('master')" id="rf-tab-master" style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;cursor:pointer;border-bottom:3px solid transparent;color:#778;margin-bottom:-2px">📦 Ürün Master</button>
          <button onclick="rfTab('izleme')" id="rf-tab-izleme"
            style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;
                   cursor:pointer;border-bottom:3px solid transparent;color:#778;margin-bottom:-2px">İzleme</button>
          <button onclick="rfTab('alarmlar')" id="rf-tab-alarmlar"
            style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;
                   cursor:pointer;border-bottom:3px solid transparent;color:#778;margin-bottom:-2px">
            Alarmlar <span id="rf-alarm-count" style="display:none;background:#e53e3e;color:#fff;
              border-radius:10px;padding:1px 5px;font-size:11px;margin-left:4px">0</span>
          </button>
          <button onclick="rfTab('ayarlar')" id="rf-tab-ayarlar"
            style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;
                   cursor:pointer;border-bottom:3px solid transparent;color:#778;margin-bottom:-2px">⚙ Ayarlar</button>
        </div>
        <div id="rf-pane-piyasa">
          <!-- PIYASA_VISUAL_V1 -->
          <!-- Piyasa Overview -->
          <div id="rf-piyasa-ozet-panel" style="margin-bottom:20px">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
              <div style="font-size:13px;font-weight:600;color:#94a3b8;letter-spacing:.5px;text-transform:uppercase">Piyasa Genel Bakış</div>
              <div id="rf-piyasa-ozet-meta" style="font-size:11px;color:#667"></div>
            </div>
            <div id="rf-marka-karti-listesi" style="display:flex;gap:10px;flex-wrap:wrap;margin-bottom:16px"></div>
            <div id="rf-mevsim-bar" style="display:none;margin-bottom:16px">
              <div style="font-size:12px;color:#778;margin-bottom:6px">Mevsim dağılımı</div>
              <div id="rf-mevsim-list" style="display:flex;gap:8px;flex-wrap:wrap"></div>
            </div>
            <div id="rf-kaynak-matrix" style="display:none;margin-bottom:16px">
              <div style="font-size:12px;color:#778;margin-bottom:6px">Kaynak bazlı en ucuz oran</div>
              <div id="rf-kaynak-wins" style="display:flex;gap:8px;flex-wrap:wrap"></div>
            </div>
            <div style="height:1px;background:rgba(255,255,255,0.08);margin-bottom:16px"></div>
          </div>
          <!-- Search -->
          <div style="display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap">
            <input id="rf-marka" placeholder="Marka (ör. Continental)"
              style="padding:8px 12px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:14px;width:200px;color:#e2e8f0">
            <input id="rf-ebat" placeholder="Ebat (ör. 205/55R16)"
              style="padding:8px 12px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:14px;width:200px;color:#e2e8f0">
            <button onclick="rfPiyasaAra()"
              style="padding:8px 20px;background:#3182ce;color:#fff;border:none;border-radius:6px;font-size:14px;cursor:pointer;font-weight:600">Ara</button>
            <button onclick="rfPiyasaIzleEkle()"
              style="padding:8px 16px;background:#38a169;color:#fff;border:none;border-radius:6px;font-size:14px;cursor:pointer">⭐ İzlemeye Ekle</button>
          </div>
          <div id="rf-piyasa-result"></div>
        </div>
        <div id="rf-pane-akilli" style="display:none">
          <div style="display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap;align-items:center">
            <input id="rf-ak-marka" placeholder="Marka (ör. Continental)" style="padding:8px 12px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:14px;width:200px;color:#e2e8f0;background:transparent">
            <input id="rf-ak-ebat" placeholder="Ebat (ör. 205/55R16)" style="padding:8px 12px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:14px;width:200px;color:#e2e8f0;background:transparent">
            <button onclick="rfAkilliAra()" style="padding:8px 20px;background:#6366f1;color:#fff;border:none;border-radius:6px;font-size:14px;cursor:pointer;font-weight:600">🎯 Eşleştir</button>
            <span style="font-size:12px;color:#8899aa">Aynı ürünü tüm pazaryerlerinde birebir eşleştirir</span>
          </div>
          <div id="rf-akilli-result"></div>
        </div>
        <div id="rf-pane-trend" style="display:none">
          <div style="display:flex;gap:10px;flex-wrap:wrap;align-items:flex-end;margin-bottom:14px">
            <label style="font-size:12px;color:#9ab">Ebat
              <input id="rf-tr-ebat" list="rf-tr-ebatlar" placeholder="205/55R16"
                     style="display:block;margin-top:4px;padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px;width:140px">
              <datalist id="rf-tr-ebatlar"></datalist>
            </label>
            <label style="font-size:12px;color:#9ab">Marka
              <input id="rf-tr-marka" placeholder="(tümü)"
                     style="display:block;margin-top:4px;padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px;width:130px">
            </label>
            <label style="font-size:12px;color:#9ab">Görünüm
              <select id="rf-tr-grup" style="display:block;margin-top:4px;padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px">
                <option value="kaynak">Pazaryeri karşılaştırma</option>
                <option value="piyasa">Piyasa (min / ort / max)</option>
                <option value="marka">Marka karşılaştırma</option>
              </select>
            </label>
            <label style="font-size:12px;color:#9ab">Dönem
              <select id="rf-tr-gun" style="display:block;margin-top:4px;padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px">
                <option value="14">Son 14 gün</option>
                <option value="30" selected>Son 30 gün</option>
                <option value="60">Son 60 gün</option>
              </select>
            </label>
            <button onclick="rfYukleTrend()" style="padding:8px 18px;background:#3182ce;border:none;border-radius:6px;color:#fff;font-size:13px;font-weight:600;cursor:pointer">Göster</button>
          </div>
          <div id="rf-tr-ozet" style="display:flex;gap:14px;flex-wrap:wrap;margin-bottom:14px"></div>
          <div id="rf-tr-chart" style="background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.08);border-radius:10px;padding:14px;overflow-x:auto"></div>
          <div id="rf-tr-not" style="margin-top:10px;font-size:11px;color:#667"></div>
        </div>

        <div id="rf-pane-master" style="display:none">
          <div style="background:rgba(99,179,237,0.08);border:1px solid rgba(99,179,237,0.25);border-radius:8px;padding:10px 14px;margin-bottom:14px;font-size:12px;color:#63b3ed">
            <b>Kendi ürün veritabanımız.</b> Her tarama pazardaki her ürünü bu listeye karşı kontrol eder;
            yeni bir ürün görülürse listeye eklenir. KRB'nin SAP ürünleri aynı anahtarla eşleştirilir.
            <span id="rf-m-ozet" style="color:#9ab"></span>
          </div>
          <div style="display:flex;gap:6px;margin-bottom:12px;flex-wrap:wrap">
            <button onclick="rfMasterGor('bosluk')" id="rf-mg-bosluk" class="rf-mg" style="padding:7px 14px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.06);border-radius:6px;color:#e2e8f0;font-size:12.5px;font-weight:600;cursor:pointer">🕳 Stok Boşluğu</button>
            <button onclick="rfMasterGor('fiyat')"  id="rf-mg-fiyat"  class="rf-mg" style="padding:7px 14px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.06);border-radius:6px;color:#e2e8f0;font-size:12.5px;font-weight:600;cursor:pointer">💰 Fiyat Pozisyonu</button>
            <button onclick="rfMasterGor('yeni')"   id="rf-mg-yeni"   class="rf-mg" style="padding:7px 14px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.06);border-radius:6px;color:#e2e8f0;font-size:12.5px;font-weight:600;cursor:pointer">✨ Yeni Ürünler</button>
            <span style="flex:1"></span>
            <input id="rf-m-marka" placeholder="Marka" style="padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px;width:120px">
            <input id="rf-m-ebat" placeholder="Ebat" style="padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px;width:110px">
            <button onclick="rfYukleMaster()" style="padding:7px 16px;background:#3182ce;border:none;border-radius:6px;color:#fff;font-size:13px;font-weight:600;cursor:pointer">Göster</button>
          </div>
          <div id="rf-m-aciklama" style="font-size:11.5px;color:#8fa;margin-bottom:10px"></div>
          <div id="rf-m-liste"></div>
        </div>

        <div id="rf-pane-dot" style="display:none">
          <div style="background:rgba(251,191,36,0.08);border:1px solid rgba(251,191,36,0.25);border-radius:8px;padding:10px 14px;margin-bottom:14px;font-size:12px;color:#fbbf24">
            <b>Rakipler eski üretim (DOT) stoğunu indirimle boşaltıyor.</b>
            Aynı lastiğin eski üretim yılı, güncel üretimden ne kadar ucuza satılıyor —
            ve <b>hangi pazaryerinde</b>. Sahadaki temsilci bu teklifin içine körlemesine giriyor.
          </div>
          <div style="display:flex;gap:10px;flex-wrap:wrap;align-items:flex-end;margin-bottom:14px">
            <label style="font-size:12px;color:#9ab">Marka
              <input id="rf-dot-marka" placeholder="(tümü)" style="display:block;margin-top:4px;padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px;width:130px">
            </label>
            <label style="font-size:12px;color:#9ab">Ebat
              <input id="rf-dot-ebat" placeholder="(tümü)" style="display:block;margin-top:4px;padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px;width:130px">
            </label>
            <label style="font-size:12px;color:#9ab">Min. indirim
              <select id="rf-dot-ind" style="display:block;margin-top:4px;padding:7px 10px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.15);border-radius:6px;color:#e2e8f0;font-size:13px">
                <option value="10">%10+</option>
                <option value="20" selected>%20+</option>
                <option value="40">%40+</option>
                <option value="60">%60+</option>
              </select>
            </label>
            <button onclick="rfYukleDot()" style="padding:8px 18px;background:#3182ce;border:none;border-radius:6px;color:#fff;font-size:13px;font-weight:600;cursor:pointer">Göster</button>
          </div>
          <div id="rf-dot-kanal" style="display:flex;gap:10px;flex-wrap:wrap;margin-bottom:14px"></div>
          <div id="rf-dot-liste"></div>
        </div>

        <div id="rf-pane-izleme" style="display:none">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px">
            <div id="rf-izle-limit-info" style="font-size:13px;color:#9ab"></div>
            <div style="display:flex;gap:8px;align-items:center">
              <label style="font-size:13px;color:#9ab">Varsayılan alarm eşiği %:
                <input id="rf-esik-ayar" type="number" min="1" max="100" step="0.5"
                  style="width:60px;padding:4px 8px;border:1px solid rgba(255,255,255,0.18);border-radius:4px;font-size:13px;margin-left:6px">
              </label>
              <button onclick="rfKaydetAyar()"
                style="padding:5px 12px;background:#718096;color:#fff;border:none;border-radius:5px;font-size:13px;cursor:pointer">Kaydet</button>
            </div>
          </div>
          <div id="rf-izle-table"></div>
          <div style="margin-top:16px;padding:16px;background:rgba(255,255,255,0.06);border-radius:8px;border:1px dashed rgba(255,255,255,0.15)">
            <div style="font-size:13px;font-weight:600;margin-bottom:10px;color:#9ab">Yeni SKU Ekle</div>
            <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">
              <input id="rf-yeni-marka" placeholder="Marka *"
                style="padding:7px 12px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;width:160px">
              <input id="rf-yeni-ebat" placeholder="Ebat *"
                style="padding:7px 12px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;width:180px">
              <select id="rf-yeni-cekim"
                style="padding:7px 12px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px">
                <option value="3">3x Günlük (VIP)</option>
                <option value="1">1x Günlük</option>
              </select>
              <input id="rf-yeni-esik" type="number" min="1" max="100" step="0.5" placeholder="Eşik %"
                style="padding:7px 8px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;width:80px">
              <input id="rf-yeni-hedef-dusuk" type="number" min="0" step="1" placeholder="Hedef ↓ ₺"
                style="padding:7px 8px;border:1px solid rgba(74,222,128,0.45);border-radius:6px;font-size:13px;width:110px;color:#4ade80">
              <input id="rf-yeni-hedef-yuksek" type="number" min="0" step="1" placeholder="Hedef ↑ ₺"
                style="padding:7px 8px;border:1px solid rgba(248,113,113,0.45);border-radius:6px;font-size:13px;width:110px;color:#f87171">
              <input id="rf-yeni-aciklama" placeholder="Not (isteğe bağlı)"
                style="padding:7px 12px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;width:180px">
              <button onclick="rfIzleEkle()"
                style="padding:7px 16px;background:#3182ce;color:#fff;border:none;border-radius:6px;font-size:13px;cursor:pointer;font-weight:600">+ Ekle</button>
            </div>
          </div>
        </div>
        <div id="rf-pane-alarmlar" style="display:none">
          <div style="display:flex;justify-content:space-between;margin-bottom:12px">
            <div id="rf-alarm-info" style="font-size:13px;color:#9ab"></div>
            <button onclick="rfHepsiniOku()"
              style="padding:5px 14px;background:#718096;color:#fff;border:none;border-radius:5px;font-size:13px;cursor:pointer">Tümünü Okundu İşaretle</button>
          </div>
          <div id="rf-alarm-table"></div>
        </div>
        <div id="rf-pane-ayarlar" style="display:none">
          <!-- RAKIP_SETTINGS_TAB_V1 -->
          <!-- AYARLAR_LAYOUT_V1 -->
          <div style="display:flex;gap:20px;align-items:flex-start;flex-wrap:wrap">

            <!-- Sol: Veritabanı Durumu -->
            <div style="flex:1;min-width:320px;background:rgba(255,255,255,0.06);border-radius:10px;padding:20px;border:1px solid rgba(255,255,255,0.12)">
              <div style="font-size:15px;font-weight:700;color:#e2e8f0;margin-bottom:16px">📊 Veritabanı Durumu</div>
              <div id="rf-stats-yukleniyor" style="color:#778;font-size:13px">Yükleniyor...</div>
              <div id="rf-stats-grid" style="display:none;gap:12px;display:none">
                <table style="width:100%;border-collapse:collapse;font-size:13px">
                  <tbody id="rf-stats-tbody"></tbody>
                </table>
              </div>
              <div style="margin-top:14px;padding-top:12px;border-top:1px solid rgba(255,255,255,0.12)">
                <button onclick="rfYukleStats()"
                  style="padding:6px 14px;background:rgba(49,130,206,0.18);color:#63b3ed;border:1px solid rgba(49,130,206,0.4);border-radius:6px;font-size:12px;cursor:pointer">↻ Yenile</button>
              </div>
            </div>

            <!-- Sağ: Tarama Ayarları -->
            <div style="width:320px;min-width:280px;background:rgba(255,255,255,0.06);border-radius:10px;padding:20px;border:1px solid rgba(255,255,255,0.12)">
              <div style="font-size:15px;font-weight:700;color:#e2e8f0;margin-bottom:16px">⚙ Tarama Ayarları</div>
              <div style="display:flex;flex-direction:column;gap:12px;font-size:13px">

                <label style="display:flex;align-items:center;gap:10px;cursor:pointer">
                  <input type="checkbox" id="rf-ayar-aktif" style="width:16px;height:16px;cursor:pointer">
                  <span style="font-weight:600">Otomatik tarama aktif</span>
                </label>

                <div>
                  <div style="font-weight:600;color:#94a3b8;margin-bottom:4px">Tarama sıklığı (günde kaç kez)</div>
                  <select id="rf-ayar-sikligi"
                    style="width:100%;padding:7px 10px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;background:rgba(255,255,255,0.08);color:#e2e8f0">
                    <option value="1">1 kez (günlük)</option>
                    <option value="2">2 kez (sabah + akşam)</option>
                    <option value="3">3 kez (sabah / öğle / akşam)</option>
                    <option value="6">6 kez (her 4 saatte)</option>
                    <option value="24">24 kez (saatlik)</option>
                  </select>
                </div>

                <div>
                  <div style="font-weight:600;color:#94a3b8;margin-bottom:4px">Tarama saatleri (virgülle)</div>
                  <input id="rf-ayar-saatler" type="text" placeholder="08:00,13:00,18:00"
                    style="width:100%;padding:7px 10px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;box-sizing:border-box;color:#e2e8f0">
                </div>

                <div>
                  <div style="font-weight:600;color:#94a3b8;margin-bottom:4px">İzlenecek markalar (virgülle)</div>
                  <textarea id="rf-ayar-markalar" rows="2" placeholder="Continental,Bridgestone,Michelin,Lassa,Pirelli"
                    style="width:100%;padding:7px 10px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;resize:vertical;box-sizing:border-box"></textarea>
                </div>

                <div>
                  <div style="font-weight:600;color:#94a3b8;margin-bottom:4px">Kaynak siteler (virgülle)</div>
                  <input id="rf-ayar-kaynaklar" type="text" placeholder="lastikborsasi,lastiksepeti,n11"
                    style="width:100%;padding:7px 10px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;box-sizing:border-box;color:#e2e8f0">
                </div>

                <div>
                  <div style="font-weight:600;color:#94a3b8;margin-bottom:4px">Varsayılan alarm eşiği (%)</div>
                  <input id="rf-ayar-esik2" type="number" min="1" max="50" step="0.5" value="10"
                    style="width:100%;padding:7px 10px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;box-sizing:border-box;color:#e2e8f0">
                </div>

                <button onclick="rfKaydetTumAyarlar()"
                  style="padding:9px;background:#3182ce;color:#fff;border:none;border-radius:6px;font-size:14px;font-weight:600;cursor:pointer;width:100%;margin-top:4px">
                  Ayarları Kaydet
                </button>
                <div id="rf-ayar-msg" style="font-size:12px;text-align:center;min-height:16px"></div>
              </div>
            </div>

          </div>
        </div>
      </div>
    `;

    window.rfTab = function(tab) {
      ['piyasa','akilli','trend','dot','master','izleme','alarmlar','ayarlar'].forEach(t => {
        const pane = document.getElementById('rf-pane-' + t);
        const btn  = document.getElementById('rf-tab-'  + t);
        if (!pane || !btn) return;
        pane.style.display = t === tab ? 'block' : 'none';
        btn.style.borderBottomColor = t === tab ? '#3182ce' : 'transparent';
        btn.style.color = t === tab ? '#3182ce' : '#888';
      });
      if (tab === 'piyasa')   rfYuklePiyasaOzet();
      if (tab === 'trend')    rfYukleTrend();
      if (tab === 'dot')      rfYukleDot();
      if (tab === 'master')   rfYukleMaster();
      if (tab === 'izleme')   rfYukleIzle();
      if (tab === 'alarmlar') rfYukleAlarm();
      if (tab === 'ayarlar')  { rfYukleStats(); rfYukleAyarlar(); }
    };

    // ═══ URUN MASTER (URUN_MASTER_V1) ════════════════════════════════════════
    window._rfMasterGorunum = 'bosluk';
    window.rfMasterGor = function(g) { window._rfMasterGorunum = g; rfYukleMaster(); };

    window.rfYukleMaster = async function() {
      const g     = window._rfMasterGorunum || 'bosluk';
      const marka = (document.getElementById('rf-m-marka') || {}).value || '';
      const ebat  = (document.getElementById('rf-m-ebat')  || {}).value || '';
      const liste = document.getElementById('rf-m-liste');
      if (!liste) return;

      ['bosluk','fiyat','yeni'].forEach(k => {
        const b = document.getElementById('rf-mg-' + k);
        if (b) {
          b.style.background = (k === g) ? '#3182ce' : 'rgba(255,255,255,0.06)';
          b.style.borderColor = (k === g) ? '#3182ce' : 'rgba(255,255,255,0.15)';
        }
      });

      liste.innerHTML = '<div style="color:#778;padding:40px;text-align:center">Yükleniyor…</div>';
      let d;
      try {
        const qs = new URLSearchParams({ gorunum: g });
        if (marka) qs.set('marka', marka);
        if (ebat)  qs.set('ebat', ebat);
        const _s = window._rfSegment || 'TUMU';
        if (_s !== 'TUMU') qs.set('segment', _s);
        d = await rfApi('/api/rakip/urun-master?' + qs.toString());
      } catch (e) {
        liste.innerHTML = '<div style="color:#e53e3e;padding:30px">Hata: ' + (e && e.message) + '</div>';
        return;
      }

      const esc2 = x => String(x == null ? '' : x).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
      const tl = n => (n == null || isNaN(n)) ? '—' : Number(n).toLocaleString('tr-TR', {maximumFractionDigits:0}) + ' ₺';
      const gun = t => { try { return new Date(t).toLocaleDateString('tr-TR'); } catch(_) { return '—'; } };

      const oz = d.ozet || {};
      const ozEl = document.getElementById('rf-m-ozet');
      if (ozEl) ozEl.innerHTML = ' &nbsp;·&nbsp; <b>' + (oz.toplam || 0).toLocaleString('tr-TR') + '</b> ürün · '
        + '<b>' + (oz.krb_eslesen || 0).toLocaleString('tr-TR') + '</b> KRB SKU eşleşti · '
        + '<b>' + (oz.bosluk || 0).toLocaleString('tr-TR') + '</b> boşluk · '
        + '<b>' + (oz.marka || 0) + '</b> marka';

      const aciklama = {
        bosluk: 'Pazarın <b>3+ pazaryerinde</b> sattığı, KRB\'de karşılık gelen SKU bulunamayan ürünler. ⚠ Eşleşme oranı %36 — bu liste <b>incelenecek aday listesidir, sipariş listesi değildir</b>. Bir satır burada çıktı diye stokta yok demek değil; SAP tanımı farklı yazılmış olabilir.',
        fiyat:  'KRB SKU\'su pazarda bulunan ürünler. <b>Liste fiyatı</b> ile pazarın min/medyan/max\'ı karşılaştırıldı. Liste fiyatı iskonto öncesidir — bu bir marj hesabı değil, <b>müşterinin telefonunda gördüğü fiyat</b>tır.',
        yeni:   'Son 7 günde <b>ilk kez</b> görülen ürünler. Bir marka yeni desen çıkardığında burada belirir. (Master yeni kurulduğu için ilk günlerde çoğu ürün "yeni" görünebilir.)'
      }[g] || '';
      const acEl = document.getElementById('rf-m-aciklama');
      if (acEl) acEl.innerHTML = aciklama;

      const r = d.satirlar || [];
      if (!r.length) {
        liste.innerHTML = '<div style="color:#778;padding:40px;text-align:center">Kayıt bulunamadı.</div>';
        return;
      }

      let h = '<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:12.5px"><thead><tr style="background:rgba(255,255,255,0.06);font-weight:600;text-align:left">';
      if (g === 'fiyat') {
        h += '<th style="padding:9px 10px">Marka / Desen</th><th style="padding:9px 10px">Ebat</th>'
           + '<th style="padding:9px 10px">KRB SKU</th>'
           + '<th style="padding:9px 10px;text-align:right">KRB liste</th>'
           + '<th style="padding:9px 10px;text-align:right">Pazar min</th>'
           + '<th style="padding:9px 10px;text-align:right">Pazar medyan</th>'
           + '<th style="padding:9px 10px;text-align:right">Pazar max</th>'
           + '<th style="padding:9px 10px;text-align:right">Max üstü</th>'
           + '<th style="padding:9px 10px;text-align:center">Site</th>';
      } else if (g === 'yeni') {
        h += '<th style="padding:9px 10px">Marka / Desen</th><th style="padding:9px 10px">Ebat</th>'
           + '<th style="padding:9px 10px">İlk görülme</th>'
           + '<th style="padding:9px 10px;text-align:center">Pazaryeri</th>'
           + '<th style="padding:9px 10px;text-align:right">Min fiyat</th>'
           + '<th style="padding:9px 10px;text-align:center">KRB\'de</th>';
      } else {
        h += '<th style="padding:9px 10px">Marka / Desen</th><th style="padding:9px 10px">Ebat</th>'
           + '<th style="padding:9px 10px">Mevsim</th>'
           + '<th style="padding:9px 10px;text-align:center">Pazaryeri</th>'
           + '<th style="padding:9px 10px;text-align:center">İlan</th>'
           + '<th style="padding:9px 10px;text-align:right">Min</th>'
           + '<th style="padding:9px 10px;text-align:right">Medyan</th>';
      }
      h += '</tr></thead><tbody>';

      r.forEach(x => {
        h += '<tr style="border-bottom:1px solid rgba(255,255,255,0.06)">'
          + '<td style="padding:8px 10px"><b>' + esc2(x.marka) + '</b> <span style="color:#9ab">' + esc2(x.desen) + '</span></td>'
          + '<td style="padding:8px 10px;font-family:monospace;color:#9ab">' + esc2(x.ebat) + '</td>';
        if (g === 'fiyat') {
          const ust = x.max_ustu_yuzde;
          const renk = ust == null ? '#94a3b8' : (ust > 20 ? '#f87171' : (ust > 0 ? '#fbbf24' : '#4ade80'));
          h += '<td style="padding:8px 10px;font-family:monospace;color:#8fa;font-size:11.5px">' + esc2(x.krb_kalem_kodu) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;font-weight:700;color:' + renk + '">' + tl(x.krb_liste) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;color:#9ab">' + tl(x.pazar_min) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;color:#cbd5e1">' + tl(x.pazar_medyan) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;color:#9ab">' + tl(x.pazar_max) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;font-weight:800;color:' + renk + '">'
              + (ust == null ? '—' : (ust > 0 ? '+%' + ust : '%' + ust)) + '</td>'
            + '<td style="padding:8px 10px;text-align:center;color:#9ab">' + (x.pazaryeri_sayisi || 0) + '</td>';
        } else if (g === 'yeni') {
          h += '<td style="padding:8px 10px;color:#4ade80">' + gun(x.ilk_gorulme) + '</td>'
            + '<td style="padding:8px 10px;text-align:center;color:#cbd5e1">' + (x.pazaryeri_sayisi || 0) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;color:#cbd5e1">' + tl(x.pazar_min) + '</td>'
            + '<td style="padding:8px 10px;text-align:center">' + (x.krb_de_var
                ? '<span style="color:#4ade80">✓</span>'
                : '<span style="color:#f87171">✗</span>') + '</td>';
        } else {
          h += '<td style="padding:8px 10px;color:#9ab">' + esc2(x.mevsim || '') + '</td>'
            + '<td style="padding:8px 10px;text-align:center"><b style="color:' + ((x.pazaryeri_sayisi||0) >= 5 ? '#f87171' : '#cbd5e1') + '">' + (x.pazaryeri_sayisi || 0) + '</b></td>'
            + '<td style="padding:8px 10px;text-align:center;color:#9ab">' + (x.ilan_sayisi || 0) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;color:#cbd5e1">' + tl(x.pazar_min) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;color:#9ab">' + tl(x.pazar_medyan) + '</td>';
        }
        h += '</tr>';
      });
      h += '</tbody></table></div>';
      h += '<div style="margin-top:10px;font-size:11px;color:#667">' + r.length + ' kayıt gösteriliyor (en fazla 300).</div>';
      liste.innerHTML = h;
    };

    // ═══ ESKI URETIM / DOT (RAKIP_DOT_V1) ════════════════════════════════════
    window.rfYukleDot = async function() {
      const marka = (document.getElementById('rf-dot-marka') || {}).value || '';
      const ebat  = (document.getElementById('rf-dot-ebat')  || {}).value || '';
      const ind   = (document.getElementById('rf-dot-ind')   || {}).value || '20';
      const liste = document.getElementById('rf-dot-liste');
      const kanalEl = document.getElementById('rf-dot-kanal');
      if (!liste) return;
      liste.innerHTML = '<div style="color:#778;padding:40px;text-align:center">Yükleniyor…</div>';

      let d;
      try {
        const qs = new URLSearchParams({ min_indirim: ind });
        if (marka) qs.set('marka', marka);
        if (ebat)  qs.set('ebat', ebat);
        d = await rfApi('/api/rakip/dot?' + qs.toString());
      } catch (e) {
        liste.innerHTML = '<div style="color:#e53e3e;padding:30px">Hata: ' + (e && e.message) + '</div>';
        return;
      }

      const esc2 = x => String(x == null ? '' : x).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
      const tl = n => (n == null || isNaN(n)) ? '—' : Number(n).toLocaleString('tr-TR', {maximumFractionDigits:0}) + ' ₺';

      // kanal kartlari: hangi pazaryeri eski stok deposu?
      kanalEl.innerHTML = (d.kanal || []).map(k => {
        const kirmizi = k.eski_oran >= 6;
        return '<div style="background:rgba(255,255,255,0.05);border:1px solid ' + (kirmizi ? 'rgba(248,113,113,0.35)' : 'rgba(255,255,255,0.08)') + ';border-radius:8px;padding:9px 13px;min-width:130px">'
          + '<div style="font-size:12px;color:#cbd5e1;font-weight:600;margin-bottom:3px">' + esc2(k.kaynak) + '</div>'
          + '<div style="font-size:17px;font-weight:700;color:' + (kirmizi ? '#f87171' : '#94a3b8') + '">%' + (k.eski_oran ?? 0) + '</div>'
          + '<div style="font-size:10px;color:#667">2022 ve öncesi · ' + (k.eski || 0) + ' ilan</div>'
          + '</div>';
      }).join('');

      const f = d.firsatlar || [];
      if (!f.length) {
        liste.innerHTML = '<div style="color:#778;padding:40px;text-align:center">Bu filtreyle eski üretim indirimi bulunamadı.</div>';
        return;
      }

      let h = '<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:12.5px">'
        + '<thead><tr style="background:rgba(255,255,255,0.06);font-weight:600;text-align:left">'
        + '<th style="padding:9px 10px">Marka / Desen</th>'
        + '<th style="padding:9px 10px">Ebat</th>'
        + '<th style="padding:9px 10px">Eski üretim</th>'
        + '<th style="padding:9px 10px;text-align:right">Eski fiyat</th>'
        + '<th style="padding:9px 10px">Güncel</th>'
        + '<th style="padding:9px 10px;text-align:right">Güncel fiyat</th>'
        + '<th style="padding:9px 10px;text-align:right">İndirim</th>'
        + '<th style="padding:9px 10px">Eski stok nerede</th>'
        + '<th></th></tr></thead><tbody>';

      f.forEach(r => {
        const derin = r.indirim >= 50;
        h += '<tr style="border-bottom:1px solid rgba(255,255,255,0.06)">'
          + '<td style="padding:8px 10px"><b>' + esc2(r.marka) + '</b> <span style="color:#9ab">' + esc2(r.desen) + '</span></td>'
          + '<td style="padding:8px 10px;font-family:monospace;color:#9ab">' + esc2(r.ebat) + '</td>'
          + '<td style="padding:8px 10px"><span style="background:rgba(248,113,113,0.15);color:#f87171;border-radius:5px;padding:2px 7px;font-weight:700">' + r.eski_yil + '</span> <span style="color:#667;font-size:11px">' + (r.eski_ilan || 0) + ' ilan</span></td>'
          + '<td style="padding:8px 10px;text-align:right;font-weight:700;color:#f87171">' + tl(r.eski_fiyat) + '</td>'
          + '<td style="padding:8px 10px"><span style="background:rgba(74,222,128,0.12);color:#4ade80;border-radius:5px;padding:2px 7px;font-weight:700">' + r.yeni_yil + '</span></td>'
          + '<td style="padding:8px 10px;text-align:right;color:#cbd5e1">' + tl(r.yeni_fiyat) + '</td>'
          + '<td style="padding:8px 10px;text-align:right"><span style="font-size:14px;font-weight:800;color:' + (derin ? '#f87171' : '#fbbf24') + '">−%' + r.indirim + '</span><div style="font-size:10px;color:#667">' + tl(r.fark_tl) + ' fark</div></td>'
          + '<td style="padding:8px 10px;color:#94a3b8">' + esc2(r.eski_kaynak) + '</td>'
          + '<td style="padding:8px 10px">' + (r.eski_url ? '<a href="' + esc2(r.eski_url) + '" target="_blank" rel="noopener noreferrer" style="color:#63b3ed;text-decoration:none">↗</a>' : '') + '</td>'
          + '</tr>';
      });
      h += '</tbody></table></div>';
      h += '<div style="margin-top:10px;font-size:11px;color:#667">'
         + f.length + ' fırsat · Aynı ürünün (marka + desen + ebat + yük/hız) eski ve güncel üretim yılı fiyatları karşılaştırıldı. '
         + 'Setler ve lastik olmayan ürünler hariç. <b>Tek bir satıra körü körüne güvenmeyin</b> — ilanı ↗ ile açıp doğrulayın.</div>';
      liste.innerHTML = h;
    };

    // ═══ FIYAT TRENDI (RAKIP_TREND_V1) ═══════════════════════════════════════
    const RF_RENK = { akakce:'#f59e0b', n11:'#8b5cf6', trendyol:'#f97316', pttavm:'#10b981',
                      kolayoto:'#3b82f6', lastikborsasi:'#ef4444', lastiksiparis:'#06b6d4',
                      hepsiburada:'#eab308', Piyasa:'#38bdf8' };
    const RF_PALET = ['#38bdf8','#f59e0b','#a78bfa','#34d399','#f472b6','#fb923c','#22d3ee','#facc15'];
    const rfTL = n => (n == null || isNaN(n)) ? '—' : Number(n).toLocaleString('tr-TR', {maximumFractionDigits:0}) + ' ₺';
    const rfGunEt = g => { const d = new Date(g + 'T00:00:00'); return d.toLocaleDateString('tr-TR', {day:'2-digit', month:'short'}); };

    window.rfYukleTrend = async function() {
      const ebat  = (document.getElementById('rf-tr-ebat')  || {}).value || '';
      const marka = (document.getElementById('rf-tr-marka') || {}).value || '';
      const grup  = (document.getElementById('rf-tr-grup')  || {}).value || 'kaynak';
      const gun   = (document.getElementById('rf-tr-gun')   || {}).value || '30';
      const chart = document.getElementById('rf-tr-chart');
      const ozetEl = document.getElementById('rf-tr-ozet');
      const notEl = document.getElementById('rf-tr-not');
      if (!chart) return;
      chart.innerHTML = '<div style="color:#778;padding:40px;text-align:center">Yükleniyor…</div>';

      // ebat listesi (bir kez)
      try {
        const dl = document.getElementById('rf-tr-ebatlar');
        if (dl && !dl.children.length) {
          const e = await rfApi('/api/rakip/trend-ebatlar');
          dl.innerHTML = (e.ebatlar || []).map(x => '<option value="' + x.ebat + '">' + x.ebat + ' (' + x.ilan + ')</option>').join('');
        }
      } catch (e) {}

      let d;
      try {
        const qs = new URLSearchParams({ grup, gun });
        if (ebat)  qs.set('ebat', ebat);
        if (marka) qs.set('marka', marka);
        d = await rfApi('/api/rakip/trend?' + qs.toString());
      } catch (e) {
        chart.innerHTML = '<div style="color:#e53e3e;padding:30px">Hata: ' + (e && e.message) + '</div>';
        return;
      }

      const seri = (d.seri || []).filter(s => s.noktalar && s.noktalar.length);
      if (!seri.length) {
        chart.innerHTML = '<div style="color:#778;padding:40px;text-align:center">Bu filtre için veri yok.</div>';
        ozetEl.innerHTML = ''; notEl.textContent = '';
        return;
      }

      // ── özet kartları ──
      const kart = (baslik, deger, renk, alt) =>
        '<div style="background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);border-radius:8px;padding:10px 14px;min-width:150px">'
        + '<div style="font-size:11px;color:#778;margin-bottom:3px">' + baslik + '</div>'
        + '<div style="font-size:18px;font-weight:700;color:' + (renk || '#e2e8f0') + '">' + deger + '</div>'
        + (alt ? '<div style="font-size:11px;color:#667;margin-top:2px">' + alt + '</div>' : '')
        + '</div>';

      const tumNokta = seri.flatMap(s => s.noktalar);
      const gunler = [...new Set(tumNokta.map(p => p.gun))].sort();
      const sonGun = gunler[gunler.length - 1], ilkGun = gunler[0];
      const sonlar = seri.map(s => { const p = s.noktalar.filter(x => x.gun === sonGun)[0]; return p ? { ad: s.ad, v: p.min } : null; }).filter(Boolean);
      const enUcuz = sonlar.length ? sonlar.reduce((a,b) => a.v < b.v ? a : b) : null;
      const enPahali = sonlar.length ? sonlar.reduce((a,b) => a.v > b.v ? a : b) : null;
      // ilk güne göre değişim (en ucuz seri)
      let degisim = null;
      if (enUcuz) {
        const sIlk = seri.filter(s => s.ad === enUcuz.ad)[0].noktalar.filter(x => x.gun === ilkGun)[0];
        if (sIlk) degisim = ((enUcuz.v - sIlk.min) / sIlk.min) * 100;
      }
      ozetEl.innerHTML =
          kart('En ucuz (bugün)', enUcuz ? rfTL(enUcuz.v) : '—', '#4ade80', enUcuz ? enUcuz.ad : '')
        + (degisim != null ? kart('Değişim (' + rfGunEt(ilkGun) + '→)', (degisim > 0 ? '▲ ' : '▼ ') + Math.abs(degisim).toFixed(1) + '%', degisim > 0 ? '#f87171' : '#4ade80', 'en ucuz kaynakta') : '')
        + (enUcuz && enPahali && enUcuz.ad !== enPahali.ad ? kart('Pazaryeri farkı', rfTL(enPahali.v - enUcuz.v), '#fbbf24', enUcuz.ad + ' ↔ ' + enPahali.ad) : '')
        + kart('Veri', gunler.length + ' gün · ' + seri.length + ' seri', '#94a3b8', tumNokta.reduce((a,p) => a + p.adet, 0).toLocaleString('tr-TR') + ' ilan (setler hariç)');

      // ── grafik ──
      const W = Math.max(900, gunler.length * 90), H = 400;
      const ML = 70, MR = 150, MT = 16, MB = 46;
      const iw = W - ML - MR, ih = H - MT - MB;
      const tamSite = d.tam_site || 0;
      const eksikGun = g => {
        const k = (d.kapsama || []).filter(x => x.gun === g)[0];
        return (k && tamSite && k.site < tamSite) ? k.site : 0;   // 0 = tam kapsama
      };
      const vals = [];
      seri.forEach(s => s.noktalar.forEach(p => { vals.push(p.min); if (grup === 'piyasa') { vals.push(p.p10, p.p50, p.p90); } }));
      let ymin = Math.min.apply(null, vals), ymax = Math.max.apply(null, vals);
      const pad = (ymax - ymin) * 0.12 || (ymax * 0.1) || 1;
      ymin = Math.max(0, ymin - pad); ymax = ymax + pad;
      const X = g => ML + (gunler.length === 1 ? iw / 2 : (gunler.indexOf(g) / (gunler.length - 1)) * iw);
      const Y = v => MT + ih - ((v - ymin) / ((ymax - ymin) || 1)) * ih;

      let svg = '<svg width="' + W + '" height="' + H + '" style="font-family:inherit">';
      // Y ekseni + grid
      for (let i = 0; i <= 5; i++) {
        const v = ymin + (ymax - ymin) * i / 5, y = Y(v);
        svg += '<line x1="' + ML + '" y1="' + y + '" x2="' + (ML + iw) + '" y2="' + y + '" stroke="rgba(255,255,255,0.07)" stroke-width="1"/>';
        svg += '<text x="' + (ML - 10) + '" y="' + (y + 4) + '" text-anchor="end" font-size="11" fill="#778">' + Math.round(v).toLocaleString('tr-TR') + '</text>';
      }
      // X ekseni
      gunler.forEach(g => {
        const x = X(g);
        svg += '<line x1="' + x + '" y1="' + MT + '" x2="' + x + '" y2="' + (MT + ih) + '" stroke="rgba(255,255,255,0.04)"/>';
        svg += '<text x="' + x + '" y="' + (MT + ih + 20) + '" text-anchor="middle" font-size="11" fill="#889">' + rfGunEt(g) + '</text>';
      });
      svg += '<text x="' + (ML - 52) + '" y="' + (MT + ih / 2) + '" transform="rotate(-90 ' + (ML - 52) + ' ' + (MT + ih / 2) + ')" text-anchor="middle" font-size="11" fill="#667">Fiyat (₺)</text>';

      // piyasa modunda p10–p90 bandı (min/max degil: tek bir hatali ilan bandi mahvediyordu)
      if (grup === 'piyasa' && seri[0]) {
        const pts = seri[0].noktalar.slice().sort((a,b) => a.gun.localeCompare(b.gun));
        const ust = pts.map(p => X(p.gun) + ',' + Y(p.p90)).join(' ');
        const alt = pts.slice().reverse().map(p => X(p.gun) + ',' + Y(p.p10)).join(' ');
        svg += '<polygon points="' + ust + ' ' + alt + '" fill="rgba(56,189,248,0.10)" stroke="none"/>';
      }
      // eksik kapsamalı günleri tara (fiyat hareketi değil, veri eksiği)
      gunler.forEach(g => {
        const eks = eksikGun(g);
        if (!eks) return;
        const x = X(g), yarim = gunler.length > 1 ? (iw / (gunler.length - 1)) / 2 : 30;
        svg += '<rect x="' + (x - Math.min(yarim, 34)) + '" y="' + MT + '" width="' + (Math.min(yarim, 34) * 2) + '" height="' + ih + '" fill="rgba(251,191,36,0.07)"/>';
        svg += '<text x="' + x + '" y="' + (MT + 12) + '" text-anchor="middle" font-size="9" fill="#fbbf24">eksik veri</text>';
      });

      // seriler
      seri.forEach((sr, si) => {
        const renk = RF_RENK[sr.ad] || RF_PALET[si % RF_PALET.length];
        const pts = sr.noktalar.slice().sort((a,b) => a.gun.localeCompare(b.gun));
        const cizgi = (key, dash) => {
          const d = pts.map((p, i) => (i ? 'L' : 'M') + X(p.gun) + ' ' + Y(p[key])).join(' ');
          return '<path d="' + d + '" fill="none" stroke="' + renk + '" stroke-width="' + (dash ? 1.4 : 2.4) + '"'
               + (dash ? ' stroke-dasharray="4 3" opacity="0.75"' : '') + ' stroke-linejoin="round"/>';
        };
        svg += cizgi('min');
        if (grup === 'piyasa') { svg += cizgi('p50', true); }
        pts.forEach(p => {
          const eks = eksikGun(p.gun);
          svg += '<circle cx="' + X(p.gun) + '" cy="' + Y(p.min) + '" r="4" fill="' + (eks ? '#0b1220' : renk) + '" stroke="' + renk + '" stroke-width="' + (eks ? 2 : 1.5) + '"' + (eks ? ' stroke-dasharray="2 1"' : '') + '>'
               + '<title>' + sr.ad + ' — ' + rfGunEt(p.gun)
               + '\nEn ucuz: ' + rfTL(p.min)
               + '\nMedyan: ' + rfTL(p.p50)
               + '\np10–p90: ' + rfTL(p.p10) + ' – ' + rfTL(p.p90)
               + '\n' + p.adet + ' ilan'
               + (eks ? '\n\n⚠ EKSİK VERİ: bu gün sadece ' + eks + '/' + tamSite + ' pazaryeri çekildi.\nFiyat hareketi değil, kapsama boşluğu olabilir.' : '')
               + '</title></circle>';
        });
        // son değer etiketi
        const son = pts[pts.length - 1];
        if (son) {
          svg += '<text x="' + (X(son.gun) + 9) + '" y="' + (Y(son.min) + 4) + '" font-size="11" font-weight="700" fill="' + renk + '">' + rfTL(son.min) + '</text>';
        }
      });

      // legend
      seri.forEach((sr, si) => {
        const renk = RF_RENK[sr.ad] || RF_PALET[si % RF_PALET.length];
        const ly = MT + 14 + si * 20;
        svg += '<rect x="' + (ML + iw + 28) + '" y="' + (ly - 8) + '" width="10" height="10" rx="2" fill="' + renk + '"/>';
        svg += '<text x="' + (ML + iw + 44) + '" y="' + (ly + 1) + '" font-size="12" fill="#cbd5e1">' + sr.ad + '</text>';
      });
      svg += '</svg>';
      chart.innerHTML = svg;

      const eksikler = gunler.filter(g => eksikGun(g));
      notEl.innerHTML = 'Kesintisiz çizgi = <b>o gün o kaynaktaki en ucuz ilan</b>'
        + (grup === 'piyasa' ? '; kesikli çizgi = <b>medyan</b>; gölgeli alan = <b>p10–p90</b> (aykırı ilanlara dayanıklı)' : '')
        + '. 4\'lü setler hariç tutuldu. Noktaların üzerine gelin.'
        + '<br>Veri ' + rfGunEt(ilkGun) + ' – ' + rfGunEt(sonGun)
        + (eksikler.length
            ? ' · <span style="color:#fbbf24">⚠ Taralı günlerde tüm pazaryerleri çekilmedi (' + eksikler.map(rfGunEt).join(', ') + ') — oradaki sıçrama fiyat hareketi değil, veri eksiği olabilir.</span>'
            : '')
        + (gunler.length < 7 ? ' · <span style="color:#fbbf24">Geçmiş veri henüz ' + gunler.length + ' gün — her gün derinleşiyor.</span>' : '');
    };

    async function rfApi(path, method, body) {
      const opts = { method: method || 'GET' };
      if (body) { opts.body = JSON.stringify(body); opts.headers = {'Content-Type':'application/json'}; }
      const r = await fetch(path, opts);
      return r.json();
    }

    rfYukleOzet();
    rfYuklePiyasaOzet();

    let _rfMinSort = 0; // 0=varsayılan 1=artan -1=azalan — RAKIP_UI_V1
        window.rfRawIzleEkle = async function(marka, ebat) {
          if (!marka || !ebat) { alert('Marka/ebat eksik.'); return; }
          var x = prompt('"' + marka + ' ' + ebat + '"\nHEDEF ↓ — fiyat buna DÜŞERSE alarm (₺, boş bırakılabilir):', '');
          if (x === null) return;
          var y = prompt('HEDEF ↑ — fiyat buna ÇIKARSA alarm (₺, boş bırakılabilir):', '');
          if (y === null) return;
          var payload = { marka: marka, ebat: ebat, gunluk_cekim: 3 };
          var xn = parseFloat(x), yn = parseFloat(y);
          if (!isNaN(xn)) payload.hedef_dusuk = xn;
          if (!isNaN(yn)) payload.hedef_yuksek = yn;
          try {
            var data = await rfApi('/api/rakip/izle', 'POST', payload);
            if (data && data.error) { alert(data.error); return; }
            var hedefTxt = (!isNaN(xn) || !isNaN(yn)) ? (' Hedef:' + (!isNaN(xn) ? ' ↓' + xn : '') + (!isNaN(yn) ? ' ↑' + yn : '')) : ' (Hedef için İzleme sekmesinden belirleyin.)';
            alert('"' + marka + ' ' + ebat + '" izlemeye eklendi (3x/gün).' + hedefTxt);
          } catch(e) { alert('Hata: ' + e.message); }
        };
        // CHIP_FILTRE_V1 — mevsim/kaynak rozetine tiklayinca Ham Veri'yi doldur.
    window._rfChip = null;
    window.rfChipFiltre = function(tip, deger) {
      window._rfChip = { tip: tip, deger: deger };
      const mk = document.getElementById('rf-marka'); if (mk) mk.value = '';
      const eb = document.getElementById('rf-ebat');  if (eb) eb.value = '';
      window.rfPiyasaAra();
      const res = document.getElementById('rf-piyasa-result');
      if (res) res.scrollIntoView({ behavior: 'smooth', block: 'start' });
    };

    window.rfPiyasaAra = async function() { // RAKIP_RAWDATA_V1 (flat per-listing; replaces pivot)
      const marka = (document.getElementById('rf-marka')?.value || '').trim();
      const ebat  = (document.getElementById('rf-ebat')?.value  || '').trim();
      const _chip = window._rfChip;
      if (!marka && !ebat && !_chip) { alert('Lütfen marka veya ebat girin.'); return; }
      const res = document.getElementById('rf-piyasa-result');
      res.innerHTML = '<div style="color:#778;padding:20px">Yükleniyor...</div>';
      const qs = new URLSearchParams();
      if (marka) qs.set('marka', marka);
      if (ebat)  qs.set('ebat', ebat);
      // SEGMENT_SERVERSIDE_V1: cap'ten ONCE sunucuda filtrele
      const _sg = window._rfSegment || 'TUMU';
      if (_sg !== 'TUMU') qs.set('segment', _sg);
      // CHIP_FILTRE_V1
      if (_chip) { qs.set(_chip.tip, _chip.deger); window._rfChip = null; }
      qs.set('limit', '5000');   // LIMIT_V2: 500 kesiyordu
      try {
        const data = await rfApi('/api/rakip/piyasa?' + qs.toString());
        if (!data.rows?.length) { res.innerHTML = '<div style="color:#778;padding:20px">Sonuç bulunamadı.</div>'; return; }
        const histByUrl = {};
        try {
          const hist = await rfApi('/api/rakip/gecmis?' + qs.toString());
          (hist.rows || []).forEach(h => { if (!h.url || isNaN(parseFloat(h.fiyat))) return; (histByUrl[h.url] = histByUrl[h.url] || []).push({ t: +new Date(h.gecerli_tarih), fy: parseFloat(h.fiyat) }); });
          Object.keys(histByUrl).forEach(u => histByUrl[u].sort((a,b) => a.t - b.t));
        } catch (e) {}
        const trendBadge = (url, cur) => {
          const pts = url && histByUrl[url]; if (!pts || pts.length < 2 || isNaN(cur)) return '';
          let prev = null;
          for (let i = pts.length - 1; i >= 0; i--) { if (pts[i].fy && pts[i].fy !== cur) { prev = pts[i].fy; break; } }
          if (prev == null || prev <= 0) return '';
          const pct = (cur - prev) / prev * 100; if (Math.abs(pct) < 0.5) return '';
          const up = pct > 0;
          return ' <span title="\u00d6nceki: ' + Number(prev).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' \u20ba" style="font-size:9px;font-weight:700;white-space:nowrap;color:' + (up ? '#f87171' : '#4ade80') + '">' + (up ? '\u25b2' : '\u25bc') + Math.abs(pct).toFixed(0) + '%</span>';
        };
        const esc = s => String(s == null ? '' : s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
        const isSet = m => /(4\s*['`´]?\s*l[üu]|4\s*adet|takım|takim|set olarak)/i.test(m || '');
        const money = n => (n == null || isNaN(n)) ? '—' : Number(n).toLocaleString('tr-TR', { maximumFractionDigits: 0 }) + ' ₺';
        // Veri ne kadar taze? Ölü bir siteden gelen 4 günlük fiyat, canlı fiyat gibi görünmemeli.
        const taze = ts => {
          if (!ts) return '<span style="color:#556">—</span>';
          const d = new Date(ts);
          if (isNaN(d)) return '<span style="color:#556">—</span>';
          const saat = (Date.now() - d.getTime()) / 3600000;
          const gun  = Math.floor(saat / 24);
          const kisa = saat < 24
            ? d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })
            : d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit' });
          let renk = '#8899aa', ek = '';
          if (saat >= 72)      { renk = '#f87171'; ek = ' · ' + gun + 'g'; }
          else if (saat >= 24) { renk = '#fbbf24'; ek = ' · ' + gun + 'g'; }
          return '<span title="' + esc(d.toLocaleString('tr-TR')) + '" style="color:' + renk + ';white-space:nowrap">' + kisa + ek + '</span>';
        };
        const sizeOf = r => (r.genislik && r.profil && r.cap) ? (r.genislik + '/' + r.profil + 'R' + r.cap) : (r.ebat || '');
        window._rfRawSort = window._rfRawSort || { col: 'default', dir: 1 };
        const state = window._rfRawSort;
        const val = {
          kaynak: r => (r.kaynak || '').toLowerCase(),
          marka:  r => (r.marka || '').toLowerCase(),
          ebat:   r => sizeOf(r),
          fiyat:  r => (parseFloat(r.fiyat) || 0),
          birim:  r => (isSet(r.model) && parseFloat(r.fiyat)) ? parseFloat(r.fiyat) / 4 : (parseFloat(r.fiyat) || 0),
          satici: r => (parseInt(r.satici_sayisi, 10) || 0),
          puan:   r => (parseFloat(r.puan) || 0),
          tarih:  r => (r.scraped_at ? +new Date(r.scraped_at) : 0)
        };
        const defaultCmp = (a,b) => sizeOf(a).localeCompare(sizeOf(b)) || (a.marka || '').localeCompare(b.marka || '') || ((parseFloat(a.fiyat) || 0) - (parseFloat(b.fiyat) || 0));
        const cmp = (a,b) => {
          if (state.col === 'default' || !val[state.col]) return defaultCmp(a,b);
          const va = val[state.col](a), vb = val[state.col](b);
          let c = (typeof va === 'string') ? va.localeCompare(vb) : (va - vb);
          if (!c) c = defaultCmp(a,b);
          return c * state.dir;
        };
        window._rfRawSortBy = function(col) { const s = window._rfRawSort; if (s.col === col) { s.dir = -s.dir; } else { s.col = col; s.dir = 1; } if (window._rfRawDraw) window._rfRawDraw(); };
        const arrow = col => state.col === col ? (state.dir > 0 ? ' \u25b2' : ' \u25bc') : '';
        const th  = (t, extra) => '<th style="padding:9px 10px;border-bottom:2px solid rgba(255,255,255,0.15);' + (extra || '') + '">' + t + '</th>';
        const thS = (t, col, extra) => '<th onclick="window._rfRawSortBy(\'' + col + '\')" title="S\u0131rala" style="cursor:pointer;user-select:none;padding:9px 10px;border-bottom:2px solid rgba(255,255,255,0.15);' + (extra || '') + '">' + t + arrow(col) + '</th>';
        const draw = () => {
        // ── SEGMENT_UI_V1: Tüketici / Ticari ayrimi ──
        const _seg = window._rfSegment || 'TUMU';
        const _isTicari = r => ['KAMYON_OTOBUS','HAFIF_TICARI','IS_MAKINESI'].indexOf(r.segment) >= 0;
        const _tumRows = data.rows.slice();
        const _nT = _tumRows.filter(r => r.segment === 'BINEK').length;
        const _nC = _tumRows.filter(_isTicari).length;
        const rows = _tumRows.filter(r =>
            _seg === 'TUKETICI' ? r.segment === 'BINEK'
          : _seg === 'TICARI'   ? _isTicari(r)
          : true).sort(cmp);

        const _segBtn = (k, etiket, n) => {
          const aktif = (_seg === k);
          return '<button onclick="rfSegSec(\'' + k + '\')" style="padding:6px 14px;border:1px solid '
            + (aktif ? '#3182ce' : 'rgba(255,255,255,0.15)') + ';background:' + (aktif ? '#3182ce' : 'rgba(255,255,255,0.06)')
            + ';border-radius:6px;color:#e2e8f0;font-size:12.5px;font-weight:600;cursor:pointer;margin-right:6px">'
            + etiket + ' <span style="opacity:.7;font-weight:400">' + n + '</span></button>';
        };
        let html = '<div style="margin-bottom:12px;display:flex;align-items:center;flex-wrap:wrap">'
          + _segBtn('TUMU','Tümü', _tumRows.length)
          + _segBtn('TUKETICI','🚗 Tüketici', _nT)
          + _segBtn('TICARI','🚚 Ticari', _nC)
          + '<span style="font-size:11px;color:#667;margin-left:8px">Ticari = kamyon/otobüs (R17.5·19.5·22.5) + hafif ticari (C)</span>'
          + '</div>';
        html += '<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:12.5px">'
          + '<thead><tr style="background:rgba(255,255,255,0.06);font-weight:600;text-align:left">'
          + thS('Kaynak','kaynak') + thS('Marka','marka') + th('Segment') + thS('Ebat','ebat') + th('Model')
          + thS('Fiyat','fiyat','text-align:right') + thS('Birim (₺/adet)','birim','text-align:right')
          + thS('Satıcı','satici') + thS('Puan','puan') + thS('Son Çekim','tarih') + th('')
          + '</tr></thead><tbody>';
        let setCount = 0;
        for (const r of rows) {
          const set = isSet(r.model); if (set) setCount++;
          const fy = parseFloat(r.fiyat);
          const birim = (set && fy) ? fy / 4 : null;
          const link = r.url ? '<a href="' + esc(r.url) + '" target="_blank" rel="noopener noreferrer" style="color:#63b3ed;text-decoration:none">↗</a>' : '';
          const _wq = s => String(s == null ? '' : s).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
          const _wsz = sizeOf(r);
          const izleBtn = (r.marka && _wsz) ? '<button onclick="rfRawIzleEkle(\'' + _wq(r.marka) + '\',\'' + _wq(_wsz) + '\')" title="İzleme listesine ekle + hedef fiyat" style="padding:2px 7px;background:rgba(56,161,105,0.15);border:1px solid rgba(56,161,105,0.4);border-radius:5px;font-size:11px;cursor:pointer;color:#68d391;white-space:nowrap">+ İzle</button>' : '';
          const badge = set ? ' <span style="background:#7c3f00;color:#ffd9a0;font-size:9px;font-weight:700;padding:1px 5px;border-radius:8px;white-space:nowrap">4\'LÜ SET</span>' : '';
          html += '<tr style="border-bottom:1px solid rgba(255,255,255,0.06)">'
            + '<td style="padding:8px 10px;color:#94a3b8;white-space:nowrap">' + esc(r.kaynak) + '</td>'
            + '<td style="padding:8px 10px;font-weight:600;white-space:nowrap">' + esc(r.marka) + '</td>'
            + '<td style="padding:8px 10px;white-space:nowrap">' + segRozet(r.segment) + '</td>'
            + '<td style="padding:8px 10px;color:#9ab;font-family:monospace;white-space:nowrap">' + esc(sizeOf(r)) + '</td>'
            + '<td style="padding:8px 10px;max-width:360px;word-break:break-word;color:#cbd5e1">' + esc(r.model) + badge + '</td>'
            + '<td style="padding:8px 10px;text-align:right;font-weight:700;' + (set ? 'color:#f59e0b' : 'color:#e2e8f0') + ';white-space:nowrap">' + money(fy) + trendBadge(r.url, fy) + '</td>'
            + '<td style="padding:8px 10px;text-align:right;white-space:nowrap;color:' + (birim ? '#38a169' : '#556') + '">' + (birim ? money(birim) : '—') + '</td>'
            + '<td style="padding:8px 10px;color:#8899aa;white-space:nowrap">' + (r.satici_sayisi ? ('🏪' + r.satici_sayisi) : '') + '</td>'
            + '<td style="padding:8px 10px;color:#8899aa;white-space:nowrap">' + (r.puan ? ('⭐' + r.puan) : '') + '</td>'
            + '<td style="padding:8px 10px">' + taze(r.scraped_at) + '</td>'
            + '<td style="padding:8px 10px;white-space:nowrap">' + izleBtn + ' ' + link + '</td>'
            + '</tr>';
        }
        html += '</tbody></table></div>';
        var _tp = (data.toplam != null) ? data.toplam : rows.length;
        var _kesik = data.kesildi && (_seg === 'TUMU');
        html += '<div style="margin-top:10px;font-size:12px;text-align:right;color:' + (_kesik ? '#f87171' : '#667') + '">'
          + rows.length + ' ilan gösteriliyor'
          + ((_tp > rows.length) ? (' · <b>toplam ' + _tp.toLocaleString('tr-TR') + '</b> — liste kesildi, aramanızı daraltın') : ' (tümü)')
          + (setCount ? (' · ' + setCount + ' set 4\'lü — birim = fiyat/4') : '')
          + '</div>';
        res.innerHTML = html;
        };
        window._rfRawDraw = draw;
        window.rfSegSec = function(k) {
          window._rfSegment = k;
          // sunucu tarafi filtre: yeniden SORGULA (yalnizca yeniden cizmek cap sorununu cozmez)
          if (typeof window.rfPiyasaAra === 'function') { window.rfPiyasaAra(); return; }
          if (window._rfRawDraw) window._rfRawDraw();
        };
        draw();
      } catch (e) { res.innerHTML = '<div style="color:#e53e3e;padding:20px">Hata: ' + (e && e.message) + '</div>'; }
    };

    // ===== Smart Matched (RAKIP_SMARTMATCH_V1) =====
    function smDeacc(s){var m={'İ':'i','I':'i','ı':'i','Ş':'s','ş':'s','Ğ':'g','ğ':'g','Ü':'u','ü':'u','Ö':'o','ö':'o','Ç':'c','ç':'c','Â':'a','â':'a'};return (s||'').split('').map(function(c){return m[c]||c;}).join('').toLowerCase();}
    var SM_BRAND={continental:['continental','conti']};
    var SM_WINTER=/(kis|kislik|winter|snow|ice|frost|blizzak|eskimo|nordicca|nordic|sottozero|snowproof|snowmaster|wintercontact|wintercommand|winguard|glacier|w462|lm00\d|ws\d|alpin|xice|icept|frigo|snoway|wintercraft|polarmax)/;
    var SM_ALLSEASON=/(4\s*mevsim|dort\s*mevsim|all.?season|4\s*season|4season|crossclimate|vector.*4|quatrac|all.?weather|multiways|4seasons|as210|quartaris|fourtech|multimatch)/;
    function smSeason(t){ if(SM_ALLSEASON.test(t))return '4mevsim'; if(SM_WINTER.test(t)||/\bkis\b|kislik/.test(t))return 'kis'; return 'yaz'; }
    function smLoadSpeed(t){ var m=t.match(/\b(\d{2,3})\s*([hvwtyq])\b/); return m?[m[1],m[2]]:['','']; }
    function smRunflat(t){ return /\b(rft|rof|run.?flat|ssr|zp|dsst)\b/.test(t); }
    function smIsSet(t){ return /4.?l[uü]|4\s*adet|tak[iı]m|set olarak/.test(t); }
    var SM_PHRASE=/(yaz\s*lasti\w*|k[i]s\s*lasti\w*|4\s*mevsim(\s*lasti\w*)?|dort\s*mevsim(\s*lasti\w*)?|4\s*season|set\s*olarak|4.?l[uü]\s*tak[iı]m|\(?\s*4\s*adet\s*\)?|yazl[i]k|kisl[i]k|m\+s|3pmsf)/g;
    var SM_NOISE=/\b(yaz|kis|lastik|lastigi|lastigy|oto|otomobil|binek|mevsim|dort|uretim|yili|yil|hafta|tarihi|son|haftalar|aralik|adet|takim|set|olarak|tl|rft|rof|runflat|ssr|zp|xl|fr|fp|mo|moe|ao|ev|db|kanal|enliten|eld|ready|new|newgen|plus|op|ext|hrs|grubu|yeni|desen|sibop|reft)\b/g;
    function smPattern(marka,title,g,p,c){
      var t=smDeacc(title);
      (SM_BRAND[smDeacc(marka)]||[smDeacc(marka)]).forEach(function(a){ t=t.split(a).join(' '); });
      t=t.replace(/\d{3}\s*\/\s*\d{2,3}\s*r?\s*\d{2}/g,' ').replace(/\b\d{2,3}\s*[hvwtyq]\b/g,' ').replace(SM_PHRASE,' ').replace(/\b\d{4,}\b/g,' ');
      var prev=null; while(prev!==t){ prev=t; t=t.replace(SM_NOISE,' '); }
      return t.replace(/[^a-z0-9]+/g,' ').split(' ').filter(Boolean).join('');
    }
    function segRozet(sg) {
      const M = {
        BINEK:         ['🚗 Tüketici',  '#63b3ed', 'rgba(99,179,237,0.12)'],
        KAMYON_OTOBUS: ['🚚 Kamyon',    '#fbbf24', 'rgba(251,191,36,0.14)'],
        HAFIF_TICARI:  ['🚐 Hafif Tic.', '#4ade80', 'rgba(74,222,128,0.12)'],
        IS_MAKINESI:   ['🚜 İş Mak.',   '#f87171', 'rgba(248,113,113,0.12)']
      };
      const m = M[sg];
      if (!m) return '<span style="color:#556;font-size:11px">—</span>';
      return '<span style="background:' + m[2] + ';color:' + m[1] + ';border-radius:5px;padding:2px 7px;font-size:10.5px;font-weight:700;white-space:nowrap">' + m[0] + '</span>';
    }

    function smKey(marka,title,g,p,c){
      var t=smDeacc(title), ls=smLoadSpeed(t);
      return smDeacc(marka)+'|'+smPattern(marka,title,g,p,c)+'|'+g+'/'+p+'R'+c+'|'+ls[0]+ls[1]+'|'+smSeason(t)+'|'+(smIsSet(t)?'SET':'')+(smRunflat(t)?'RF':'');
    }
    function smDisplayName(grp){
      var best=null;
      grp.models.forEach(function(m){ if(!m)return;
        var hasBrand=smDeacc(m).indexOf(smDeacc(grp.marka))>=0, mixed=/[a-z]/.test(m)&&/[A-Z]/.test(m);
        var score=(hasBrand?0:100)+(mixed?0:40)+m.length*0.1;
        if(!best||score<best.s)best={m:m,s:score};
      });
      var name=best?best.m:(grp.marka||'');
      name=name.replace(/\d{3}\s*\/\s*\d{2,3}\s*[rR]?\s*\d{2}/,' ').replace(/\b\d{2,3}\s*[hvwtyqHVWTYQ]\b/,' ')
        .replace(/\b(19|20)\d{2}\b/g,' ').replace(/\b\d{5,}\b/g,' ')
        .replace(/\b(yaz|k[ıi]ş|kis|4|d[öo]urt)\s*mevsim\s*lasti\w*/gi,' ').replace(/\b(yaz|k[ıi]ş|kis)\s*lasti\w*/gi,' ')
        .replace(/\blasti\w*/gi,' ').replace(/\b(oto|otomobil|binek|[üu]retim|set olarak|takım|takim)\b/gi,' ')
        .replace(/[\(\)\*]/g,' ').replace(/[-–]\s*$/,'').replace(/\s{2,}/g,' ').trim();
      if(smDeacc(name).indexOf(smDeacc(grp.marka))<0) name=grp.marka+' '+name;
      return name;
    }
    function rfSpark(pts){
      if(!pts||pts.length<2) return '<span style="color:#556;font-size:11px">—</span>';
      var w=84,h=22,pad=3; var ts=pts.map(function(p){return p.t;}), fs=pts.map(function(p){return p.fy;});
      var t0=Math.min.apply(null,ts),t1=Math.max.apply(null,ts),f0=Math.min.apply(null,fs),f1=Math.max.apply(null,fs);
      var dx=(t1-t0)||1, dy=(f1-f0)||1;
      var X=function(t){return pad+(t-t0)/dx*(w-2*pad);}, Y=function(f){return h-pad-(f-f0)/dy*(h-2*pad);};
      var d=pts.map(function(p,i){return (i?'L':'M')+X(p.t).toFixed(1)+' '+Y(p.fy).toFixed(1);}).join(' ');
      var up=fs[fs.length-1]>fs[0], flat=fs[fs.length-1]===fs[0]; var col=flat?'#64748b':(up?'#e5766e':'#38a169');
      var lp=pts[pts.length-1];
      return '<svg width="'+w+'" height="'+h+'" style="vertical-align:middle" title="'+pts.length+' nokta"><path d="'+d+'" fill="none" stroke="'+col+'" stroke-width="1.5"/><circle cx="'+X(lp.t).toFixed(1)+'" cy="'+Y(lp.fy).toFixed(1)+'" r="2" fill="'+col+'"/></svg>';
    }
    function rfSeriesFor(urls,histByUrl){
      var byDay={};
      (urls||[]).forEach(function(u){ (histByUrl[u]||[]).forEach(function(pt){ if(isNaN(pt.fy))return; var day=Math.floor(pt.t/86400000); if(byDay[day]==null||pt.fy<byDay[day])byDay[day]=pt.fy; }); });
      return Object.keys(byDay).map(Number).sort(function(a,b){return a-b;}).map(function(day){return {t:day*86400000,fy:byDay[day]};});
    }
    window.rfAkilliAra = async function(){
      var marka=(document.getElementById('rf-ak-marka')?.value||'').trim();
      var ebat=(document.getElementById('rf-ak-ebat')?.value||'').trim();
      if(!marka && !ebat){ alert('Lütfen marka veya ebat girin.'); return; }
      var res=document.getElementById('rf-akilli-result');
      res.innerHTML='<div style="color:#778;padding:20px">Eşleştiriliyor...</div>';
      var qs=new URLSearchParams(); if(marka)qs.set('marka',marka); if(ebat)qs.set('ebat',ebat);
      var _sg=window._rfSegment||'TUMU'; if(_sg!=='TUMU') qs.set('segment',_sg);  // SEGMENT_SERVERSIDE_V1
      qs.set('limit','5000');   // LIMIT_V2
      try{
        var data=await rfApi('/api/rakip/piyasa?'+qs.toString());
        if(!data.rows||!data.rows.length){ res.innerHTML='<div style="color:#778;padding:20px">Sonuç bulunamadı.</div>'; return; }
        var hist=await rfApi('/api/rakip/gecmis?'+qs.toString()).catch(function(){return{rows:[]};});
        var histByUrl={}; (hist.rows||[]).forEach(function(h){ if(!h.url)return; (histByUrl[h.url]=histByUrl[h.url]||[]).push({t:+new Date(h.gecerli_tarih),fy:parseFloat(h.fiyat)}); });
        var esc=function(s){return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');};
        var money=function(n){return (n==null||isNaN(n))?'—':Number(n).toLocaleString('tr-TR',{maximumFractionDigits:0})+' ₺';};
        var groups={}, ks=new Set();
        data.rows.forEach(function(r){
          var g=r.genislik,p=r.profil,c=r.cap; if(!g||!p||!c)return;
          var key=smKey(r.marka,r.model||r.ebat||'',g,p,c);
          if(!groups[key])groups[key]={marka:r.marka,g:g,p:p,c:c,key:key,fiyat:{},models:[],urls:[]};
          var grp=groups[key], pf=parseFloat(r.fiyat);
          if(pf && (!grp.fiyat[r.kaynak]||pf<grp.fiyat[r.kaynak].fy)) grp.fiyat[r.kaynak]={fy:pf,url:r.url,model:r.model};
          grp.models.push(r.model); if(r.url)grp.urls.push(r.url); ks.add(r.kaynak);
        });
        var kaynaklar=Array.from(ks).sort();
        var list=Object.keys(groups).map(function(k){var grp=groups[k];
          var pr=Object.keys(grp.fiyat).map(function(kk){return grp.fiyat[kk].fy;});
          grp.n=pr.length; grp.min=pr.length?Math.min.apply(null,pr):null; grp.max=pr.length?Math.max.apply(null,pr):null;
          grp.spread=grp.min?((grp.max-grp.min)/grp.min*100):0; grp.name=smDisplayName(grp); grp.spark=rfSeriesFor(grp.urls,histByUrl);
          return grp;
        }).filter(function(grp){return grp.n>=2;}).sort(function(a,b){return b.spread-a.spread;});
        if(!list.length){ res.innerHTML='<div style="color:#778;padding:20px">Birden fazla pazaryerinde eşleşen ürün bulunamadı. (Tek kaynaktakiler için Ham Veri sekmesine bakın.)</div>'; return; }
        var seaLbl={yaz:'Yaz',kis:'Kış','4mevsim':'4 Mevsim'};
        var th=function(t,ex){return '<th style="padding:8px 9px;border-bottom:2px solid rgba(255,255,255,0.15);'+(ex||'')+'">'+t+'</th>';};
        var html='<div style="margin-bottom:10px;font-size:12px;color:#8899aa">'+list.length+' birebir eşleşen ürün (≥2 pazaryeri) · yayılıma göre sıralı</div>';
        html+='<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:12.5px">';
        html+='<thead><tr style="background:rgba(255,255,255,0.06);font-weight:600;text-align:left">'+th('Ürün')+th('Ebat')+th('Y/H')+th('Sezon')
          +kaynaklar.map(function(k){return th(k,'text-align:right');}).join('')+th('Min','text-align:right')+th('Yayılım','text-align:right')+th('Trend')+'</tr></thead><tbody>';
        list.forEach(function(grp){
          var ls=grp.key.split('|')[3], sea=grp.key.split('|')[4], fl=grp.key.split('|')[5];
          var badge=(fl.indexOf('SET')>=0?' <span style="background:#7c3f00;color:#ffd9a0;font-size:9px;padding:1px 4px;border-radius:6px">SET</span>':'')
            +(fl.indexOf('RF')>=0?' <span style="background:#334155;color:#93c5fd;font-size:9px;padding:1px 4px;border-radius:6px">RFT</span>':'');
          html+='<tr style="border-bottom:1px solid rgba(255,255,255,0.06)">'
            +'<td style="padding:8px 9px;max-width:300px;color:#e2e8f0">'+esc(grp.name)+badge+'</td>'
            +'<td style="padding:8px 9px;color:#9ab;font-family:monospace;white-space:nowrap">'+grp.g+'/'+grp.p+'R'+grp.c+'</td>'
            +'<td style="padding:8px 9px;color:#9ab;white-space:nowrap">'+esc(ls.toUpperCase())+'</td>'
            +'<td style="padding:8px 9px;color:#9ab;white-space:nowrap">'+(seaLbl[sea]||sea)+'</td>'
            +kaynaklar.map(function(k){var cell=grp.fiyat[k];
              if(!cell)return '<td style="padding:8px 9px;text-align:right;color:#445">—</td>';
              var isMin=cell.fy===grp.min; var inner=money(cell.fy);
              if(cell.url) inner='<a href="'+esc(cell.url)+'" target="_blank" rel="noopener noreferrer" style="text-decoration:none;color:inherit">'+inner+' ↗</a>';
              return '<td style="padding:8px 9px;text-align:right;white-space:nowrap;'+(isMin?'color:#38a169;font-weight:700':'color:#94a3b8')+'">'+inner+'</td>';
            }).join('')
            +'<td style="padding:8px 9px;text-align:right;font-weight:700;white-space:nowrap">'+money(grp.min)+'</td>'
            +'<td style="padding:8px 9px;text-align:right;font-weight:700;color:'+(grp.spread>=20?'#f59e0b':grp.spread>=10?'#eab308':'#64748b')+'">+'+grp.spread.toFixed(0)+'%</td>'
            +'<td style="padding:8px 9px">'+rfSpark(grp.spark)+'</td>'
            +'</tr>';
        });
        html+='</tbody></table></div>';
        res.innerHTML=html;
      }catch(e){ res.innerHTML='<div style="color:#e53e3e;padding:20px">Hata: '+(e&&e.message)+'</div>'; }
    };
    window.rfPiyasaIzleEkle = function() {
      const m = document.getElementById('rf-marka')?.value.trim();
      const e = document.getElementById('rf-ebat')?.value.trim();
      if (!m || !e) { alert('Marka ve ebat giriniz.'); return; }
      rfTab('izleme');
      setTimeout(() => {
        const ym = document.getElementById('rf-yeni-marka'); if (ym) ym.value = m;
        const ye = document.getElementById('rf-yeni-ebat');  if (ye) ye.value = e;
      }, 100);
    };

    window._rfToggleMinSort = function() {
      _rfMinSort = _rfMinSort === 0 ? 1 : _rfMinSort === 1 ? -1 : 0;
      rfPiyasaAra();
    };

        window.rfHizliIzleEkle = async function(marka, ebat) {
      try {
        const data = await rfApi('/api/rakip/izle', 'POST', { marka, ebat, gunluk_cekim: 3 });
        if (data.error) { alert(data.error); return; }
        alert(`"${marka} ${ebat}" izlemeye eklendi (VIP 3x/gün).`);
        rfYukleOzet();
      } catch(e) { alert('Hata: ' + e.message); }
    };

    async function rfYukleIzle() {
      const tbl  = document.getElementById('rf-izle-table');
      const info = document.getElementById('rf-izle-limit-info');
      if (!tbl) return;
      tbl.innerHTML = '<div style="color:#778">Yükleniyor...</div>';
      try {
        const [listData, ozetData, ayarData] = await Promise.all([
          rfApi('/api/rakip/izle'), rfApi('/api/rakip/ozet'), rfApi('/api/rakip/ayar'),
        ]);
        const max   = ozetData.max_izle || 50;
        const count = listData.rows?.length || 0;
        if (info) info.innerHTML = `<span style="font-weight:600">${count}/${max}</span> SKU izleniyor`;
        const esikEl = document.getElementById('rf-esik-ayar');
        if (esikEl) esikEl.value = ayarData.ayar?.alarm_esigi_varsayilan || '10';
        if (!listData.rows?.length) {
          tbl.innerHTML = '<div style="color:#778;padding:20px">İzleme listesi boş. Aşağıdan SKU ekleyin.</div>'; return;
        }
        const em = s => s.replace(/'/g, "\\'");
        let html = '<table style="width:100%;border-collapse:collapse;font-size:13px"><thead><tr style="background:rgba(255,255,255,0.06);font-weight:600">'
          + ['Marka','Ebat','Frekans','Alarm %','Hedef ↓ ₺','Hedef ↑ ₺','Durum','Alarm','İşlem']
              .map(h => `<th style="padding:9px 12px;border-bottom:2px solid rgba(255,255,255,0.15)">${h}</th>`).join('')
          + '</tr></thead><tbody>';
        for (const r of listData.rows) {
          const badge = r.alarm_sayisi
            ? `<span style="background:#e53e3e;color:#fff;border-radius:10px;padding:1px 7px;font-size:11px">${r.alarm_sayisi}</span>`
            : '<span style="color:#445">—</span>';
          html += `<tr style="border-bottom:1px solid rgba(255,255,255,0.06)">
            <td style="padding:9px 12px;font-weight:600">${r.marka}</td>
            <td style="padding:9px 12px;color:#9ab">${r.ebat}</td>
            <td style="padding:9px 12px;text-align:center">
              <select onchange="rfGuncelle(${r.id},'gunluk_cekim',parseInt(this.value))"
                style="padding:3px 6px;border:1px solid rgba(255,255,255,0.18);border-radius:4px;font-size:12px">
                <option value="3" ${r.gunluk_cekim===3?'selected':''}>3x VIP</option>
                <option value="1" ${r.gunluk_cekim===1?'selected':''}>1x Günlük</option>
              </select>
            </td>
            <td style="padding:9px 12px;text-align:center">
              <input type="number" value="${r.alarm_esigi}" min="1" max="100" step="0.5"
                onchange="rfGuncelle(${r.id},'alarm_esigi',parseFloat(this.value))"
                style="width:55px;padding:3px 6px;border:1px solid rgba(255,255,255,0.18);border-radius:4px;font-size:12px;text-align:center"> %
            </td>
            <td style="padding:9px 12px;text-align:center">
              <input type="number" value="${r.hedef_dusuk ?? ''}" min="0" step="1" placeholder="—"
                onchange="rfGuncelle(${r.id},'hedef_dusuk',this.value===''?null:parseFloat(this.value))"
                style="width:82px;padding:3px 6px;border:1px solid rgba(74,222,128,0.45);border-radius:4px;font-size:12px;text-align:right;color:#4ade80">
            </td>
            <td style="padding:9px 12px;text-align:center">
              <input type="number" value="${r.hedef_yuksek ?? ''}" min="0" step="1" placeholder="—"
                onchange="rfGuncelle(${r.id},'hedef_yuksek',this.value===''?null:parseFloat(this.value))"
                style="width:82px;padding:3px 6px;border:1px solid rgba(248,113,113,0.45);border-radius:4px;font-size:12px;text-align:right;color:#f87171">
            </td>
            <td style="padding:9px 12px;text-align:center">
              ${r.aktif ? '<span style="color:#38a169">● Aktif</span>' : '<span style="color:#667">● Pasif</span>'}
            </td>
            <td style="padding:9px 12px;text-align:center">${badge}</td>
            <td style="padding:9px 12px;text-align:center">
              <button onclick="rfToggle(${r.id},${!r.aktif})"
                style="padding:3px 8px;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.12);border-radius:4px;font-size:11px;cursor:pointer;margin-right:4px">
                ${r.aktif ? 'Duraklat' : 'Aktifleştir'}
              </button>
              <button onclick="rfSil(${r.id},'${em(r.marka)}','${em(r.ebat)}')"
                style="padding:3px 8px;background:rgba(229,62,62,0.12);border:1px solid rgba(229,62,62,0.4);border-radius:4px;font-size:11px;cursor:pointer;color:#fc8181">Sil</button>
            </td>
          </tr>`;
        }
        tbl.innerHTML = html + '</tbody></table>';
      } catch(e) { tbl.innerHTML = `<div style="color:#e53e3e">Hata: ${e.message}</div>`; }
    }

    window.rfIzleEkle = async function() {
      const marka    = document.getElementById('rf-yeni-marka')?.value.trim();
      const ebat     = document.getElementById('rf-yeni-ebat')?.value.trim();
      const cekim    = parseInt(document.getElementById('rf-yeni-cekim')?.value || '3', 10);
      const esikRaw  = parseFloat(document.getElementById('rf-yeni-esik')?.value);
      const hdRaw    = parseFloat(document.getElementById('rf-yeni-hedef-dusuk')?.value);
      const hyRaw    = parseFloat(document.getElementById('rf-yeni-hedef-yuksek')?.value);
      const aciklama = document.getElementById('rf-yeni-aciklama')?.value.trim();
      if (!marka || !ebat) { alert('Marka ve ebat zorunlu.'); return; }
      try {
        const payload = { marka, ebat, gunluk_cekim: cekim };
        if (!isNaN(esikRaw)) payload.alarm_esigi = esikRaw;
        if (!isNaN(hdRaw)) payload.hedef_dusuk = hdRaw;
        if (!isNaN(hyRaw)) payload.hedef_yuksek = hyRaw;
        if (aciklama) payload.aciklama = aciklama;
        const data = await rfApi('/api/rakip/izle', 'POST', payload);
        if (data.error) { alert(data.error); return; }
        ['rf-yeni-marka','rf-yeni-ebat','rf-yeni-esik','rf-yeni-hedef-dusuk','rf-yeni-hedef-yuksek','rf-yeni-aciklama']
          .forEach(id => { const el = document.getElementById(id); if (el) el.value = ''; });
        rfYukleIzle(); rfYukleOzet();
      } catch(e) { alert('Hata: ' + e.message); }
    };

    window.rfGuncelle = async function(id, alan, deger) {
      try { await rfApi(`/api/rakip/izle/${id}`, 'PUT', { [alan]: deger }); }
      catch(e) { alert('Güncelleme hatası: ' + e.message); }
    };
    window.rfToggle = async function(id, aktif) {
      try { await rfApi(`/api/rakip/izle/${id}`, 'PUT', { aktif }); rfYukleIzle(); }
      catch(e) { alert('Hata: ' + e.message); }
    };
    window.rfSil = async function(id, marka, ebat) {
      if (!confirm(`"${marka} ${ebat}" izleme listesinden silinsin mi?`)) return;
      try { await rfApi(`/api/rakip/izle/${id}`, 'DELETE'); rfYukleIzle(); rfYukleOzet(); }
      catch(e) { alert('Hata: ' + e.message); }
    };
    window.rfKaydetAyar = async function() {
      const esik = parseFloat(document.getElementById('rf-esik-ayar')?.value);
      if (isNaN(esik) || esik <= 0) { alert('Geçerli bir eşik girin.'); return; }
      try {
        await rfApi('/api/rakip/ayar', 'PUT', { alarm_esigi_varsayilan: esik });
        alert(`Ayar kaydedildi. Yeni SKU'larda varsayılan eşik %${esik} olacak.`);
      } catch(e) { alert('Hata: ' + e.message); }
    };

    async function rfYukleAlarm() {
      const tbl  = document.getElementById('rf-alarm-table');
      const info = document.getElementById('rf-alarm-info');
      if (!tbl) return;
      tbl.innerHTML = '<div style="color:#778">Yükleniyor...</div>';
      try {
        const data = await rfApi('/api/rakip/alarm?limit=100');
        if (info) info.textContent = data.unread ? data.unread + ' okunmamış alarm' : 'Tüm alarmlar okundu';
        const cnt = document.getElementById('rf-alarm-count');
        if (cnt) { cnt.textContent = data.unread || 0; cnt.style.display = data.unread ? 'inline' : 'none'; }
        if (!data.rows?.length) { tbl.innerHTML = '<div style="color:#778;padding:20px">Henüz alarm yok.</div>'; return; }
        let html = '<table style="width:100%;border-collapse:collapse;font-size:13px"><thead><tr style="background:rgba(255,255,255,0.06);font-weight:600">'
          + ['Tarih','SKU','Kaynak','Önceki','Yeni','Değişim','']
              .map(h => `<th style="padding:9px 12px;border-bottom:2px solid rgba(255,255,255,0.15)">${h}</th>`).join('')
          + '</tr></thead><tbody>';
        for (const a of data.rows) {
          const yon = a.yon === 'YUKARI'
            ? '<span style="color:#e53e3e;font-weight:700">▲</span>'
            : '<span style="color:#38a169;font-weight:700">▼</span>';
          const _dp = parseFloat(a.degisim_pct);
          const _hedef = a.tetik === 'HEDEF_ALT' || a.tetik === 'HEDEF_UST';
          const degisimCell = _hedef
            ? (a.tetik === 'HEDEF_ALT'
                ? '<span style="color:#38a169;font-weight:700">▼ Hedefe indi</span>'
                : '<span style="color:#e53e3e;font-weight:700">▲ Hedefe çıktı</span>')
              + (isNaN(_dp) ? '' : ' <span style="color:#8899aa">%' + _dp.toFixed(1) + '</span>')
            : (isNaN(_dp) ? yon : yon + ' %' + _dp.toFixed(1));
          const tarih = new Date(a.alarm_at).toLocaleString('tr-TR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});
          html += `<tr style="border-bottom:1px solid rgba(255,255,255,0.06);${a.goruldu?'':'background:rgba(237,137,54,0.12)'}">
            <td style="padding:9px 12px;color:#8899aa;font-size:12px">${tarih}</td>
            <td style="padding:9px 12px;font-weight:600">${a.marka} ${a.ebat}</td>
            <td style="padding:9px 12px;color:#9ab">${a.kaynak}</td>
            <td style="padding:9px 12px;text-align:right;color:#8899aa">${a.eski_fiyat?parseFloat(a.eski_fiyat).toLocaleString('tr-TR')+' ₺':'—'}</td>
            <td style="padding:9px 12px;text-align:right;font-weight:600">${a.yeni_fiyat?parseFloat(a.yeni_fiyat).toLocaleString('tr-TR')+' ₺':'—'}</td>
            <td style="padding:9px 12px;text-align:center">${degisimCell}</td>
            <td style="padding:9px 12px;text-align:center">
              ${!a.goruldu?`<button onclick="rfOkundu(${a.id})" style="padding:2px 8px;background:rgba(56,161,105,0.18);border:1px solid rgba(56,161,105,0.4);border-radius:4px;font-size:11px;cursor:pointer;color:#68d391">Okundu</button>`:''}
            </td>
          </tr>`;
        }
        tbl.innerHTML = html + '</tbody></table>';
      } catch(e) { tbl.innerHTML = `<div style="color:#e53e3e">Hata: ${e.message}</div>`; }
    }

    window.rfOkundu = async function(id) {
      try { await rfApi(`/api/rakip/alarm/${id}/goruldu`, 'POST'); rfYukleAlarm(); rfYukleOzet(); }
      catch(e) { alert('Hata: ' + e.message); }
    };
    window.rfHepsiniOku = async function() {
      try { await rfApi('/api/rakip/alarm/goruldu-hepsi', 'POST'); rfYukleAlarm(); rfYukleOzet(); }
      catch(e) { alert('Hata: ' + e.message); }
    };

    window.rfYukleStats = async function() {
      const tbody = document.getElementById('rf-stats-tbody');
      const loading = document.getElementById('rf-stats-yukleniyor');
      const grid = document.getElementById('rf-stats-grid');
      if (!tbody) return;
      if (loading) loading.style.display = 'block';
      if (grid) grid.style.display = 'none';
      try {
        const d = await rfApi('/api/rakip/stats');
        const sonTarama = d.son_tarama
          ? new Date(d.son_tarama).toLocaleString('tr-TR', {day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'})
          : '—';
        tbody.innerHTML = [
          ['Toplam fiyat kaydı', (d.toplam_kayit||0).toLocaleString('tr-TR')],
          ['Farklı marka',       d.marka_sayisi || '—'],
          ['Farklı ebat',        d.ebat_sayisi  || '—'],
          ['Aktif izleme SKU',   d.aktif_izleme || '0'],
          ['Okunmamış alarm',    d.okunmamis_alarm || '0'],
          ['Son tarama',         sonTarama],
        ].map(([k,v]) =>
          `<tr style="border-bottom:1px solid rgba(255,255,255,0.08)">
             <td style="padding:8px 4px;color:#8899aa">${k}</td>
             <td style="padding:8px 4px;font-weight:600;text-align:right">${v}</td>
           </tr>`
        ).join('');
        if (loading) loading.style.display = 'none';
        if (grid) { grid.style.display = 'table'; grid.style.display = 'block'; }
        const statsDiv = document.getElementById('rf-stats-grid');
        if (statsDiv) statsDiv.style.display = 'block';
      } catch(e) {
        if (tbody) tbody.innerHTML = `<tr><td colspan="2" style="color:#e53e3e;padding:8px">Hata: ${e.message}</td></tr>`;
        if (loading) loading.style.display = 'none';
      }
    };

    window.rfYukleAyarlar = async function() {
      try {
        const d = await rfApi('/api/rakip/ayar');
        const a = d.ayar || {};
        const el = id => document.getElementById(id);
        if (el('rf-ayar-aktif'))   el('rf-ayar-aktif').checked = (a.scraping_aktif || 'true') === 'true';
        if (el('rf-ayar-sikligi')) el('rf-ayar-sikligi').value = a.scraping_sikligi || '3';
        if (el('rf-ayar-saatler')) el('rf-ayar-saatler').value = a.scraping_saatleri || '08:00,13:00,18:00';
        if (el('rf-ayar-markalar')) el('rf-ayar-markalar').value = a.scraping_markalar || '';
        if (el('rf-ayar-kaynaklar')) el('rf-ayar-kaynaklar').value = a.scraping_kaynaklar || '';
        if (el('rf-ayar-esik2'))   el('rf-ayar-esik2').value = a.alarm_esigi_varsayilan || '10';
      } catch(e) { console.warn('Ayarlar yüklenemedi:', e.message); }
    };

    window.rfKaydetTumAyarlar = async function() {
      const el = id => document.getElementById(id);
      const msg = el('rf-ayar-msg');
      const payload = {
        scraping_aktif:     el('rf-ayar-aktif')?.checked ? 'true' : 'false',
        scraping_sikligi:   el('rf-ayar-sikligi')?.value  || '3',
        scraping_saatleri:  el('rf-ayar-saatler')?.value  || '',
        scraping_markalar:  el('rf-ayar-markalar')?.value || '',
        scraping_kaynaklar: el('rf-ayar-kaynaklar')?.value || '',
        alarm_esigi_varsayilan: el('rf-ayar-esik2')?.value || '10',
      };
      try {
        await rfApi('/api/rakip/ayar', 'PUT', payload);
        if (msg) { msg.style.color = '#38a169'; msg.textContent = '✓ Ayarlar kaydedildi'; }
        setTimeout(() => { if (msg) msg.textContent = ''; }, 3000);
      } catch(e) {
        if (msg) { msg.style.color = '#e53e3e'; msg.textContent = 'Hata: ' + e.message; }
      }
    };

        var _piyasaOzetLoaded = false;  // SESSIZ_HATA_V1: 'let' TDZ hatasi veriyordu
    async function rfYuklePiyasaOzet() {
      if (_piyasaOzetLoaded) return;
      const kartiEl = document.getElementById('rf-marka-karti-listesi');
      const metaEl  = document.getElementById('rf-piyasa-ozet-meta');
      if (!kartiEl) return;
      kartiEl.innerHTML = `<div style="color:#778;font-size:13px">Piyasa yükleniyor...</div>`;
      try {
        // Fetch all data grouped by brand
        const data = await rfApi('/api/rakip/piyasa-ozet');
        if (!data.markalar?.length) {
          kartiEl.innerHTML = '<div style="color:#667;font-size:13px">Henüz veri yok. Önce scraper çalıştırın.</div>';
          return;
        }
        if (metaEl) metaEl.textContent = data.toplam_sku + ' SKU · ' + data.kaynak_sayisi + ' kaynak';

        // Brand price cards
        const renkler = ['#3b82f6','#10b981','#f59e0b','#ef4444','#8b5cf6','#06b6d4','#f97316','#84cc16'];
        kartiEl.innerHTML = data.markalar.slice(0,12).map((m, i) => {
          const renk = renkler[i % renkler.length];
          const range = m.max_fiyat - m.min_fiyat;
          const pct = Math.round((m.sku_sayisi / data.toplam_sku) * 100);
          return `<div style="background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.1);
                   border-radius:10px;padding:12px 16px;min-width:160px;cursor:pointer;transition:background .2s"
                   onmouseenter="this.style.background='rgba(255,255,255,0.09)'"
                   onmouseleave="this.style.background='rgba(255,255,255,0.05)'"
                   onclick="rfFiltreleKart('${m.marka}')">
            <div style="display:flex;align-items:center;gap:6px;margin-bottom:8px">
              <div style="width:8px;height:8px;border-radius:50%;background:${renk};flex-shrink:0"></div>
              <div style="font-size:13px;font-weight:700;color:#e2e8f0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:120px">${m.marka}</div>
            </div>
            <div style="font-size:18px;font-weight:700;color:${renk}">${m.min_fiyat.toLocaleString('tr-TR')} ₺</div>
            <div style="font-size:11px;color:#889;margin-top:2px">min · maks ${m.max_fiyat.toLocaleString('tr-TR')} ₺</div>
            <!-- Price range bar -->
            <div style="margin-top:8px;height:3px;background:rgba(255,255,255,0.1);border-radius:2px;overflow:hidden">
              <div style="height:100%;background:${renk};opacity:.7;width:${Math.min(100,Math.round((range/m.max_fiyat)*200))}%"></div>
            </div>
            <div style="margin-top:6px;font-size:11px;color:#667">${m.sku_sayisi} SKU · %${pct} pay</div>
          </div>`;
        }).join('');

        // Seasonal breakdown
        if (data.mevsimler?.length) {
          const mEl = document.getElementById('rf-mevsim-list');
          const mBar = document.getElementById('rf-mevsim-bar');
          if (mEl && mBar) {
            const mvRenk = { 'Yaz':'#f59e0b', 'Kış':'#3b82f6', '4 Mevsim':'#10b981' };
            const mvKod  = { 'Yaz':'yaz', 'Kış':'kis', '4 Mevsim':'4mevsim' };
            const total = data.mevsimler.reduce((s,m)=>s+m.sayi,0);
            // CHIP_FILTRE_V1: tikla -> o mevsimin urunleri
            mEl.innerHTML = data.mevsimler.map(m => {
              const kod = mvKod[m.mevsim];
              const tiklanir = !!kod;
              return `<div ${tiklanir ? `onclick="rfChipFiltre('mevsim','${kod}')"` : ''}
                   title="${tiklanir ? 'Tıkla: bu mevsimin ürünlerini gör' : ''}"
                   style="display:flex;align-items:center;gap:6px;background:rgba(255,255,255,0.05);
                   border-radius:6px;padding:5px 10px;font-size:12px;${tiklanir ? 'cursor:pointer;border:1px solid rgba(255,255,255,0.08)' : ''}"
                   ${tiklanir ? `onmouseenter="this.style.background='rgba(255,255,255,0.11)'" onmouseleave="this.style.background='rgba(255,255,255,0.05)'"` : ''}>
                <div style="width:8px;height:8px;border-radius:50%;background:${mvRenk[m.mevsim]||'#94a3b8'};flex-shrink:0"></div>
                <span style="color:#cbd5e0">${m.mevsim||'Bilinmiyor'}</span>
                <span style="color:#94a3b8;font-weight:600">${Math.round(m.sayi/total*100)}%</span>
                <span style="color:#64748b;font-size:10px">(${m.sayi.toLocaleString('tr-TR')})</span>
              </div>`;
            }).join('');
            mBar.style.display = 'block';
          }
        }

        // Source wins matrix
        if (data.kaynak_kazanc?.length) {
          const kEl = document.getElementById('rf-kaynak-wins');
          const kBar = document.getElementById('rf-kaynak-matrix');
          if (kEl && kBar) {
            const total = data.kaynak_kazanc.reduce((s,k)=>s+k.kazanc,0);
            // CHIP_FILTRE_V1: tikla -> bu pazaryerinin EN UCUZ oldugu urunler.
            // (Musterinin daha ucuza bulabilecegi urunler — en degerli liste.)
            kEl.innerHTML = data.kaynak_kazanc.map(k =>
              `<div onclick="rfChipFiltre('en_ucuz_kaynak','${k.kaynak}')"
                 title="Tıkla: ${k.kaynak} üzerinde EN UCUZ olan ürünleri gör"
                 onmouseenter="this.style.background='rgba(255,255,255,0.11)'"
                 onmouseleave="this.style.background='rgba(255,255,255,0.05)'"
                 style="background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.08);border-radius:6px;padding:5px 12px;font-size:12px;color:#cbd5e0;cursor:pointer">
                <span style="font-weight:600">${k.kaynak}</span>
                <span style="color:#64748b;margin-left:6px">en ucuz: ${Math.round(k.kazanc/total*100)}%</span>
                <span style="color:#475569;font-size:10px;margin-left:4px">(${k.kazanc.toLocaleString('tr-TR')})</span>
              </div>`
            ).join('');
            kBar.style.display = 'block';
          }
        }

        _piyasaOzetLoaded = true;
      } catch(e) {
        kartiEl.innerHTML = `<div style="color:#667;font-size:13px">Piyasa özeti yüklenemedi.</div>`;
      }
    }

    window.rfFiltreleKart = function(marka) {
      const el = document.getElementById('rf-marka');
      if (el) el.value = marka;
      rfPiyasaAra();
    };

        async function rfYukleOzet() {
      try {
        const data = await rfApi('/api/rakip/ozet');
        const bar = document.getElementById('rf-ozet-bar');
        if (bar) bar.innerHTML = `
          <span>İzlenen: <strong>${data.izlenen_sku}/${data.max_izle}</strong></span>
          ${data.okunmamis_alarm
            ? `<span style="color:#e53e3e">⚠ ${data.okunmamis_alarm} alarm</span>`
            : '<span style="color:#38a169">✓ Alarm yok</span>'}
        `;
        const cnt = document.getElementById('rf-alarm-count');
        if (cnt) { cnt.textContent = data.okunmamis_alarm||0; cnt.style.display = data.okunmamis_alarm?'inline':'none'; }
      } catch(e) { /* sessiz */ }
    }
  }


  async function loadDeptData(dept) {
    if (dept === 'rakip') { loadRakipRoom(container, apiFetch); return; }
    switch(dept) {
      case "sales":     await loadSalesKpis();     break;
      case "pricing":   await loadPricingKpis(); renderPricingExtras();   break;
      case "warehouse": await loadWarehouseKpis(); break;
      case "it":        await loadItKpis();        break;
      case "orders":    loadOrderResults();        break;
      case "brand-analysis": await loadBrandAnalysis(); break;
      case "price-list":    await loadPriceList();    break;
      case "brain":     loadBrainRoom();           break;
    }
  }


  // ── Inline Agent Insight Panels ───────────────────────────────────────────
  async function renderAgentPanel(mountEl, dept, agentLabel, agentEmoji) {
    return; // agent panels disabled — agents are in the left sidebar
    const AUTO = {
      sales:     'Güncel satış verilerine bakarak 2-3 cümleyle performansı değerlendir. Bir olumlu, bir dikkat gerektiren nokta belirt.',
      pricing:   'Nakit döngüsü, ağırlıklı marj ve DPO verilerini 2-3 cümleyle yorumla.',
      warehouse: 'Stok durumunu, kritik ve sıfır stoklu kalemleri 2-3 cümleyle özetle. Yanıtını düz metin olarak ver, JSON veya kod bloğu kullanma.',
    };
    mountEl.innerHTML =
      '<div style="border:1px solid #e0e7ff;border-radius:12px;padding:14px 16px;background:#fafbff;margin-top:4px">' +
      '<div style="display:flex;align-items:center;gap:8px;margin-bottom:10px">' +
      '<span style="font-size:18px">' + agentEmoji + '</span>' +
      '<span style="font-weight:700;color:#1e1b4b;font-size:14px">' + agentLabel + '</span>' +
      '<span style="width:7px;height:7px;background:#10b981;border-radius:50%;margin-left:auto;flex-shrink:0"></span></div>' +
      '<div id="vmo-ap-msgs-' + dept + '" style="min-height:38px;max-height:200px;overflow-y:auto;font-size:13px;line-height:1.5">' +
      '<div class="vmo-ap-loading" style="color:#7c3aed;font-style:italic">\u{1F4AD} Analiz yap\u{131}l\u{131}yor\u2026</div></div>' +
      '<div style="display:flex;gap:8px;margin-top:10px;border-top:1px solid #e0e7ff;padding-top:10px">' +
      '<input id="vmo-ap-inp-' + dept + '" type="text" placeholder="Soru sor\u2026" style="flex:1;border:1px solid #c7d2fe;border-radius:8px;padding:7px 10px;font-size:13px;outline:none">' +
      '<button id="vmo-ap-btn-' + dept + '" style="background:#7c3aed;color:#fff;border:none;border-radius:8px;padding:7px 14px;cursor:pointer;font-size:15px">\u2192</button>' +
      '</div></div>';
    const msgsEl = mountEl.querySelector('#vmo-ap-msgs-' + dept);
    const inputEl = mountEl.querySelector('#vmo-ap-inp-' + dept);
    const btnEl   = mountEl.querySelector('#vmo-ap-btn-' + dept);
    async function sendMsg(msg, isAuto) {
      if (!isAuto) {
        const ud = document.createElement('div'); ud.style.cssText = 'text-align:right;margin:6px 0';
        ud.innerHTML = '<span style="background:#e0e7ff;padding:5px 10px;border-radius:12px 12px 2px 12px;font-size:13px">' + msg + '</span>';
        msgsEl.appendChild(ud);
      }
      const bubble = document.createElement('div');
      bubble.style.cssText = 'background:#f5f3ff;border-radius:8px;padding:8px 11px;margin:6px 0;font-size:13px;line-height:1.5';
      bubble.innerHTML = '<span style="color:#7c3aed;font-size:11px;font-weight:600;display:block;margin-bottom:3px">' + agentLabel + '</span><span class="vmo-ap-txt"></span>';
      const txtEl = bubble.querySelector('.vmo-ap-txt');
      msgsEl.querySelector('.vmo-ap-loading')?.remove();
      msgsEl.appendChild(bubble); msgsEl.scrollTop = msgsEl.scrollHeight;
      inputEl.disabled = true; btnEl.disabled = true;
      try {
        const res = await fetch('/api/bi/department/' + dept + '/chat', {
          method: 'POST', credentials: 'include',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({ message: msg })
        });
        if (!res.ok) { txtEl.textContent = 'Yan\u0131t al\u0131namad\u0131 (' + res.status + ').'; return; }
        const reader = res.body.getReader(); const dec = new TextDecoder(); let buf = '';
        while (true) {
          const { done, value } = await reader.read(); if (done) break;
          buf += dec.decode(value, { stream: true });
          const lines = buf.split('\n'); buf = lines.pop();
          for (const ln of lines) {
            if (!ln.startsWith('data: ')) continue;
            try { const d = JSON.parse(ln.slice(6)); if (d.text) { txtEl.textContent += d.text; msgsEl.scrollTop = msgsEl.scrollHeight; } } catch {}
          }
        }
        // strip markdown code fences + JSON wrapper from auto-insight
        (function(){
          var raw = (txtEl.textContent || '').trim();
          if (raw.startsWith('```')) {
            raw = raw.replace(/^```[a-z]*\n?/, '').replace(/\n?```$/, '').trim();
          }
          try {
            var p = JSON.parse(raw);
            var ds = p.summary || p.text || p.message || p.content || p.analiz;
            if (typeof ds === 'string') txtEl.textContent = ds;
          } catch(e3) {}
        })();
      } catch(e) { txtEl.textContent = 'Ba\u011flant\u0131 hatas\u0131: ' + e.message; }
      finally { inputEl.disabled = false; btnEl.disabled = false; }
    }
    sendMsg(AUTO[dept] || 'Mevcut durumu k\u0131saca de\u011ferlendir.', true);
    btnEl.addEventListener('click', () => { const v = inputEl.value.trim(); if (v) { inputEl.value = ''; sendMsg(v, false); } });
    inputEl.addEventListener('keydown', e => { if (e.key === 'Enter') btnEl.click(); });
  }

  async function loadSalesKpis() {
    const kpiEl   = container.querySelector("#vmo-kpis-sales");
    const chartEl = container.querySelector("#vmo-chart-sales");
    try {
      const [kpiData, trend] = await Promise.all([
        apiFetch("/api/bi/sales/kpis"),
        apiFetch("/api/bi/sales/trend")
      ]);
      const k = kpiData.kpis || {};
      const prev  = parseFloat(k.revenue_prev_30d || 0);
      const cur   = parseFloat(k.revenue_30d || 0);
      const delta = prev > 0 ? ((cur - prev) / prev * 100).toFixed(1) : null;

      kpiEl.innerHTML = `
        ${kpi("Ciro (30g)", formatTRY(k.revenue_30d), delta ? `${delta > 0?"+":""}${delta}% önceki dönem` : null, delta > 0 ? "up" : delta < 0 ? "down" : null)}
        ${kpi("Fatura Sayısı", fmt(k.invoice_count_30d), "son 30 gün")}
        ${kpi("Ort. Satır Değeri", formatTRY(k.avg_line_value_30d), null)}
        ${kpi("Top Müşteri", kpiData.top_customers?.[0]?.musteri_adi || "—", kpiData.top_customers?.[0] ? formatTRY(kpiData.top_customers[0].total) : null)}
      `;

      if (trend.length) {
        // Smart chart: Turkish month labels + filter/metric controls
        const AYLAR = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
        const _trendFull = trend.map(r => ({
          label: (() => { const d=new Date(r.ay); return AYLAR[d.getMonth()]+" '"+(String(d.getFullYear()).slice(2)); })(),
          ciro:  parseFloat(r.ciro),
          adet:  parseFloat(r.adet),
          fatura_sayisi: parseFloat(r.fatura_sayisi)
        }));

        // State
        let _chartRange  = 13; // 3 | 6 | 13 | 0=all
        let _chartMetric = 'ciro'; // ciro | adet | fatura_sayisi

        const METRIC_CFG = {
          ciro:          { label: 'Aylık Ciro (₺)',    color: '#2563eb', fmt: fmtAbbrev },
          adet:          { label: 'Satış Adedi',         color: '#059669', fmt: v => fmtAbbrev(v)+' adet' },
          fatura_sayisi: { label: 'Fatura Sayısı',       color: '#7c3aed', fmt: v => fmtAbbrev(v)+' fatura' }
        };

        function _drawSalesChart() {
          const slice = _chartRange > 0 ? _trendFull.slice(-_chartRange) : _trendFull;
          const m = METRIC_CFG[_chartMetric];
          renderChart(chartEl.querySelector('.vmo-chart-canvas'),
            slice.map(r=>r.label), slice.map(r=>r[_chartMetric]),
            m.label, m.color);
          // Update active buttons
          chartEl.querySelectorAll('.vmo-ctrl-range').forEach(b => b.classList.toggle('active', parseInt(b.dataset.r)===_chartRange));
          chartEl.querySelectorAll('.vmo-ctrl-metric').forEach(b => b.classList.toggle('active', b.dataset.m===_chartMetric));
        }

        chartEl.innerHTML = `
          <div class="vmo-chart-controls">
            <div class="vmo-ctrl-group">
              <button class="vmo-ctrl-range${_chartRange===3?" active":""}" data-r="3">3 Ay</button>
              <button class="vmo-ctrl-range${_chartRange===6?" active":""}" data-r="6">6 Ay</button>
              <button class="vmo-ctrl-range${_chartRange===13?" active":""}" data-r="13">13 Ay</button>
              <button class="vmo-ctrl-range${_chartRange===0?" active":""}" data-r="0">Tümü</button>
            </div>
            <div class="vmo-ctrl-group" style="margin-left:auto">
              <button class="vmo-ctrl-metric${_chartMetric==='ciro'?" active":""}" data-m="ciro">₺ Ciro</button>
              <button class="vmo-ctrl-metric${_chartMetric==='adet'?" active":""}" data-m="adet">📦 Adet</button>
              <button class="vmo-ctrl-metric${_chartMetric==='fatura_sayisi'?" active":""}" data-m="fatura_sayisi">📄 Fatura</button>
            </div>
          </div>
          <div class="vmo-chart-canvas"></div>`;

        chartEl.querySelectorAll('.vmo-ctrl-range').forEach(b => b.addEventListener('click', () => {
          _chartRange = parseInt(b.dataset.r); _drawSalesChart();
        }));
        chartEl.querySelectorAll('.vmo-ctrl-metric').forEach(b => b.addEventListener('click', () => {
          _chartMetric = b.dataset.m; _drawSalesChart();
        }));
        _drawSalesChart();
      } else {
        chartEl.innerHTML = `<div class="vmo-no-data">Satış verisi bulunamadı.</div>`;
      }
    } catch(e) { kpiEl.innerHTML = kpiErr(e.message); }
    { const _w = container.querySelector('#vmo-room-sales .vmo-data-wall');
      if (_w && !_w.querySelector('#vmo-agent-sales')) { const _ap = document.createElement('div'); _ap.id = 'vmo-agent-sales'; _ap.style.cssText = 'margin-top:20px'; _w.appendChild(_ap); renderAgentPanel(_ap, 'sales', 'Sat\u0131\u015f Direkt\u00f6r\u00fc', '\ud83d\udc54'); } }
  }

  // ── Account Health Score ──────────────────────────────────────────
  window._salesTabSwitch = function(tab) {
    const stabsEl = container.querySelector('#vmo-sales-stabs');
    if (stabsEl) stabsEl.querySelectorAll('[data-stab]').forEach(function(b) {
      b.classList.toggle('active', b.dataset.stab === tab);
    });
    const kEl = container.querySelector('#vmo-kpis-sales');
    const cEl = container.querySelector('#vmo-chart-sales');
    const hEl = container.querySelector('#vmo-health-tab');
    if (kEl) kEl.style.display = tab === 'kpi' ? '' : 'none';
    if (cEl) cEl.style.display = tab === 'kpi' ? '' : 'none';
    if (hEl) {
      hEl.style.display = tab === 'health' ? '' : 'none';
      if (tab === 'health' && !hEl._loaded) loadAccountHealth();
    }
  };

  window._reloadAccountHealth = async function() {
    const mo = parseInt((container.querySelector('#vmo-health-months') || {}).value || '12');
    const bodyEl = container.querySelector('#vmo-health-body');
    if (!bodyEl) return;
    bodyEl.innerHTML = '<div class="vmo-kpi-loading">Skorlar hesaplanıyor…</div>';
    try {
      const data = await apiFetch('/api/bi/account-health?months=' + mo);
      const customers = data.customers || [];
      if (!customers.length) {
        bodyEl.innerHTML = '<div class="vmo-no-data">Veri bulunamadı.</div>';
        return;
      }
      const GC = { 'A+':'#22c55e','A':'#4ade80','B+':'#86efac','B':'#fbbf24','C+':'#f97316','C':'#ef4444','D':'#dc2626' };
      bodyEl.innerHTML = '<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:12px">' +
        '<thead><tr style="border-bottom:2px solid rgba(255,255,255,0.12)">' +
        '<th style="text-align:left;padding:6px 10px;color:#94a3b8">#</th>' +
        '<th style="text-align:left;padding:6px 10px;color:#94a3b8">Müşteri</th>' +
        '<th style="text-align:center;padding:6px 10px;color:#94a3b8;cursor:help" title="0–100 arası ağırlıklı müşteri sağlık skoru">Skor</th>' +
        '<th style="text-align:center;padding:6px 10px;color:#94a3b8;cursor:help" title="Harf notu: A+ ≥90 · A ≥80 · B+ ≥70 · B ≥60 · C+ ≥50 · C ≥40 · D <40">Not</th>' +
        '<th style="text-align:right;padding:6px 10px;color:#94a3b8;cursor:help" title="Seçili dönemdeki TBR+OTR toplam fatura cirosu (ağırlık %15)">Ciro</th>' +
        '<th style="text-align:right;padding:6px 10px;color:#94a3b8;cursor:help" title="Tahmini brüt kâr marjı — ortalama stok maliyeti bazlı (ağırlık %25). Maliyet kaydı eksik ürünlerde sapma görülebilir.">GP%</th>' +
        '<th style="text-align:center;padding:6px 10px;color:#94a3b8;cursor:help" title="Dönem içinde aktif alım yapılan ay oranı (ağırlık %20)">Tutarlılık</th>' +
        '<th style="text-align:center;padding:6px 10px;color:#94a3b8;cursor:help" title="Önceki eşdeğer döneme göre ciro büyümesi (ağırlık %15)">Büyüme</th>' +
        '<th style="text-align:center;padding:6px 10px;color:#94a3b8;cursor:help" title="Ortalama Sipariş Değeri — Ciro ÷ Fatura adedi (ağırlık %10)">AOV</th>' +
        '<th style="text-align:center;padding:6px 10px;color:#94a3b8;cursor:help" title="Satın alınan farklı kalem sayısı (ağırlık %10)">Çeşitlilik</th>' +
        '</tr></thead><tbody>' +
        customers.map(function(c, i) {
          var sc = Math.round(parseFloat(c.score) || 0);
          var gp = parseFloat(c.gp_pct);
          var gr = parseFloat(c.growth_pct);
          var barColor = sc >= 70 ? '#22c55e' : sc >= 50 ? '#fbbf24' : '#ef4444';
          return '<tr style="border-bottom:1px solid rgba(255,255,255,0.05);' + (i%2===0?'background:rgba(255,255,255,0.02)':'') + '">' +
            '<td style="padding:6px 10px;color:#64748b">' + (i+1) + '</td>' +
            '<td style="padding:6px 10px;color:#f1f5f9;font-weight:500">' + (c.musteri_adi || '—') + '</td>' +
            '<td style="padding:6px 10px;text-align:center">' +
              '<div style="display:inline-flex;align-items:center;gap:6px">' +
                '<div style="width:46px;height:5px;background:rgba(255,255,255,0.1);border-radius:3px;overflow:hidden">' +
                  '<div style="height:100%;width:' + Math.min(100,Math.max(0,sc)) + '%;background:' + barColor + ';border-radius:3px"></div>' +
                '</div>' +
                '<span style="color:#f1f5f9;font-weight:700">' + sc + '</span>' +
              '</div></td>' +
            '<td style="padding:6px 10px;text-align:center;font-weight:800;font-size:13px;color:' + (GC[c.grade]||'#94a3b8') + '">' + (c.grade||'?') + '</td>' +
            '<td style="padding:6px 10px;text-align:right;color:#94a3b8">' + fmtAbbrev(parseFloat(c.revenue)||0) + ' ₺</td>' +
            '<td style="padding:6px 10px;text-align:right;color:' + (gp>0?'#4ade80':'#f87171') + '"' + (!isNaN(gp)&&Math.abs(gp)>100?' title="Ham değer: '+gp.toFixed(1)+'% — maliyet kaydı eksik veya hatalı olabilir"':'') + '>' + (isNaN(gp)?'—':Math.abs(gp)>100?(gp<0?'<-99%':'>99%')+' ⚠':gp.toFixed(1)+'%') + '</td>' +
            '<td style="padding:6px 10px;text-align:center;color:#94a3b8">' + (c.consistency_pct!=null?Math.round(parseFloat(c.consistency_pct))+'%':'—') + '</td>' +
            '<td style="padding:6px 10px;text-align:center;color:' + (gr>=0?'#4ade80':'#f87171') + '">' + (isNaN(gr)?'—':(gr>0?'+':'')+gr.toFixed(1)+'%') + '</td>' +
            '<td style="padding:6px 10px;text-align:center;color:#94a3b8">' + fmtAbbrev(parseFloat(c.avg_order_value)||0) + ' ₺</td>' +
            '<td style="padding:6px 10px;text-align:center;color:#94a3b8">' + (parseInt(c.product_breadth)||0) + ' kat.</td>' +
            '</tr>';
        }).join('') +
        '</tbody></table></div>';
    } catch(e) {
      bodyEl.innerHTML = '<div class="vmo-kpi-err">Yüklenemedi: ' + e.message + '</div>';
    }
  };

  async function loadAccountHealth() {
    const el = container.querySelector('#vmo-health-tab');
    if (!el) return;
    el._loaded = true;
    el.innerHTML = `
      <div style="display:flex;align-items:center;gap:12px;padding:4px 0 14px;border-bottom:1px solid rgba(255,255,255,0.08);margin-bottom:12px;flex-wrap:wrap">
        <span style="font-weight:700;color:#f1f5f9;font-size:14px">🚛 Ticari Müşteri Sağlığı Skoru</span>
        <select id="vmo-health-months" style="background:#1a1a2e;color:#94a3b8;border:1px solid rgba(255,255,255,0.15);border-radius:6px;padding:4px 8px;font-size:12px;cursor:pointer" onchange="window._reloadAccountHealth()">
          <option value="12">12 Ay</option>
          <option value="24">24 Ay</option>
          <option value="36">36 Ay</option>
        </select>
        <span style="font-size:11px;color:#64748b;flex:1">GP 25% · Ciro 15% · Tutarlılık 20% · Büyüme 15% · AOV 10% · Çeşitlilik 10% · Sadakat 5%</span>
      </div>
      <div style="display:flex;align-items:center;gap:5px;margin-bottom:10px;flex-wrap:wrap">
        <span style="font-size:11px;color:#64748b;margin-right:2px">Not skalası:</span>
        <span style="display:inline-flex;align-items:center;gap:3px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:5px;padding:2px 8px;font-size:11px"><span style="font-weight:800;color:#22c55e">A+</span><span style="color:#64748b">≥90</span></span><span style="display:inline-flex;align-items:center;gap:3px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:5px;padding:2px 8px;font-size:11px"><span style="font-weight:800;color:#4ade80">A</span><span style="color:#64748b">≥80</span></span><span style="display:inline-flex;align-items:center;gap:3px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:5px;padding:2px 8px;font-size:11px"><span style="font-weight:800;color:#86efac">B+</span><span style="color:#64748b">≥70</span></span><span style="display:inline-flex;align-items:center;gap:3px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:5px;padding:2px 8px;font-size:11px"><span style="font-weight:800;color:#fbbf24">B</span><span style="color:#64748b">≥60</span></span><span style="display:inline-flex;align-items:center;gap:3px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:5px;padding:2px 8px;font-size:11px"><span style="font-weight:800;color:#f97316">C+</span><span style="color:#64748b">≥50</span></span><span style="display:inline-flex;align-items:center;gap:3px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:5px;padding:2px 8px;font-size:11px"><span style="font-weight:800;color:#ef4444">C</span><span style="color:#64748b">≥40</span></span><span style="display:inline-flex;align-items:center;gap:3px;background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.08);border-radius:5px;padding:2px 8px;font-size:11px"><span style="font-weight:800;color:#dc2626">D</span><span style="color:#64748b"><40</span></span>
      </div>
      <div id="vmo-health-body"><div class="vmo-kpi-loading">Skorlar hesaplanıyor…</div></div>
    `;
    await window._reloadAccountHealth();
  }

  async function loadPricingKpis() {
    const kpiEl   = container.querySelector("#vmo-kpis-pricing");
    const chartEl = container.querySelector("#vmo-chart-pricing");
    try {
      const [kpis, ccc] = await Promise.all([
        apiFetch("/api/bi/pricing/kpis"),
        apiFetch("/api/bi/pricing/ccc")
      ]);
      kpiEl.innerHTML = `
        ${kpi("Ağırlıklı Marj %", kpis.weighted_marj_pct != null ? `%${parseFloat(kpis.weighted_marj_pct).toFixed(1)}` : "—", kpis.yil ? `${kpis.yil} kalem · son 30g satış / 12ay maliyet` : "Veri yok")}
        ${kpi("Nakit Döngüsü", ccc.ccc != null ? `${ccc.ccc} gün` : "—", `Son 90g · DIS:${ccc.dis??'—'} DSO:${ccc.dso??'—'} DPO:${ccc.dpo??'—'}`, (ccc.ccc||0) > 60 ? "down" : "up")}
        ${kpi("Finansman Maliyeti", formatTRY(ccc.financing_cost_per_unit), `Son 90g · @%${(ccc.cost_of_capital*100||0).toFixed(0)} sermaye`)}
      `;
      renderChart(chartEl, ["DIS (Stok)","DSO (Tahsilat)","DPO (Ödeme)","CCC"],
        [ccc.dis, ccc.dso, -ccc.dpo, ccc.ccc],
        "Nakit Döngüsü (Gün)", ["#7c3aed","#2563eb","#059669","#d97706"], true);
      chartEl.insertAdjacentHTML("beforeend", `<details style="margin-top:14px;font-size:12.5px;border-top:1px solid #e5e7eb;padding-top:10px"><summary style="cursor:pointer;color:#7c3aed;font-weight:600;list-style:none;padding:4px 0">ⓘ Göstergeler ne anlama gelir?</summary><div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:10px"><div style="background:#f5f3ff;border-radius:8px;padding:10px 12px"><b style="color:#5b21b6;display:block;margin-bottom:3px">Ağırlıklı Marj %</b>Tedarikçi alım maliyetine göre brüt kâr yüzdesi. Satış fiyatından gerçek alım maliyeti düşülerek hesaplanır.</div><div style="background:#f5f3ff;border-radius:8px;padding:10px 12px"><b style="color:#5b21b6;display:block;margin-bottom:3px">DIS — Stok Süresi</b>Bir ürünün depoda ortalama kaç gün beklediği. Düşükse stok hızlı dönüyor demektir.</div><div style="background:#f5f3ff;border-radius:8px;padding:10px 12px"><b style="color:#5b21b6;display:block;margin-bottom:3px">DSO — Tahsilat Süresi</b>Müşteri faturasının ortalama kaç günde tahsil edildiği. Düşükse nakit girişi hızlıdır.</div><div style="background:#f5f3ff;border-radius:8px;padding:10px 12px"><b style="color:#5b21b6;display:block;margin-bottom:3px">DPO — Ödeme Vadesi</b>Tedarikçi faturalarının ortalama ödeme vadesi. Yüksekse nakit çıkışı gecikiyor — şirket için avantajlıdır.</div><div style="background:#f5f3ff;border-radius:8px;padding:10px 12px"><b style="color:#5b21b6;display:block;margin-bottom:3px">Nakit Döngüsü (CCC)</b>DIS + DSO − DPO. Tedarikçiye ödeme yapıp müşteriden tahsilata kadar geçen gün sayısı. Ne kadar düşükse o kadar iyidir.</div><div style="background:#f5f3ff;border-radius:8px;padding:10px 12px"><b style="color:#5b21b6;display:block;margin-bottom:3px">Finansman Maliyeti</b>Stokta bekleyen ürünlerin bağladığı sermaye maliyeti. Nakit döngüsü × yıllık sermaye faiz oranı ile hesaplanır.</div></div></details>`);
    } catch(e) { kpiEl.innerHTML = kpiErr(e.message); }

    const pricingRoom = container.querySelector("#vmo-room-pricing .vmo-data-wall");
    if (pricingRoom && !pricingRoom.querySelector("#vmo-incentives-mount")) {
      const m = document.createElement("div");
      m.id = "vmo-incentives-mount";
      m.style.cssText = "margin-top:20px;";
      pricingRoom.appendChild(m);
      try {
        const { initBrandIncentives } = await import("/components/brand-incentives.js");
        initBrandIncentives(m, me, { apiFetch });
      } catch(e) { m.innerHTML = `<div class="vmo-kpi-err">Teşvik paneli yüklenemedi: ${e.message}</div>`; }
    }
    if (pricingRoom && !pricingRoom.querySelector('#vmo-agent-pricing')) { const _ap = document.createElement('div'); _ap.id = 'vmo-agent-pricing'; _ap.style.cssText = 'margin-top:20px'; pricingRoom.appendChild(_ap); renderAgentPanel(_ap, 'pricing', 'Fiyatland\u0131rma Direkt\u00f6r\u00fc', '\ud83d\udcca'); }
  }

  async function loadWarehouseKpis() {
    const kpiEl   = container.querySelector("#vmo-kpis-warehouse");
    const chartEl = container.querySelector("#vmo-chart-warehouse");
    try {
      const [kpis, movements] = await Promise.all([
        apiFetch("/api/bi/warehouse/kpis"),
        apiFetch("/api/bi/warehouse/movements")
      ]);
      if (kpis.no_data) { kpiEl.innerHTML = `<div class="vmo-no-data">Stok verisi bulunamadı.</div>`; return; }
      const k = kpis.kpis || {};
      kpiEl.innerHTML = `
        ${kpi("Toplam SKU", fmt(k.sku_sayisi), null)}
        ${kpi("Stok Değeri", formatTRY(k.stok_degeri), `Veri: ${kpis.as_of||"—"}`)}
        ${kpi("Kritik Stok", fmt(k.kritik_stok_sayisi)+" kalem", null, parseInt(k.kritik_stok_sayisi)>0?"down":"up")}
        ${kpi("Sıfır Stok", fmt(k.sifir_stok_sayisi)+" kalem", null, parseInt(k.sifir_stok_sayisi)>0?"down":null)}
      `;
      if (movements.length) {
        renderChart(chartEl, movements.slice(0,8).map(r=>r.belge_turu||"?"),
          movements.slice(0,8).map(r=>parseFloat(r.hareket_sayisi)), "Hareket Türleri (Adet)", "#059669");
      }
      if (kpis.dead_stock?.length) {
        chartEl.insertAdjacentHTML("beforeend",`
          <div class="vmo-dead-stock">
            <div class="vmo-dead-title">90 Gün Hareketsiz Stok</div>
            ${kpis.dead_stock.slice(0,5).map(r=>`
              <div class="vmo-dead-row">
                <span>${esc(r.kalem_tanimi||r.kalem_kodu)}</span>
                <strong>${formatTRY(r.toplam_deger)}</strong>
              </div>`).join("")}
          </div>`);
      }
    } catch(e) { kpiEl.innerHTML = kpiErr(e.message); }
    { const _w = container.querySelector('#vmo-room-warehouse .vmo-data-wall');
      if (_w && !_w.querySelector('#vmo-agent-warehouse')) { const _ap = document.createElement('div'); _ap.id = 'vmo-agent-warehouse'; _ap.style.cssText = 'margin-top:20px'; _w.appendChild(_ap); renderAgentPanel(_ap, 'warehouse', 'Depo M\u00fcd\u00fcr\u00fc', '\ud83d\udce6'); } }
  }

  // ── Order Management ────────────────────────────────────────────────────────
  // ── Order Management: sort · export · budget display ─────────────────────────
  // Injected by patch_orders_ui.mjs — replaces the old loadOrderResults block.
  // All helpers are closures inside initBiSurface so they share its scope.

  // Sort an items array by a field key; numeric values compared as numbers.
  function _sortItems(items, key, dir) {
    if (!key) return [...items];
    return [...items].sort((a, b) => {
      let va = a[key], vb = b[key];
      const na = parseFloat(va), nb = parseFloat(vb);
      if (!isNaN(na) && !isNaN(nb)) { va = na; vb = nb; }
      else { va = (va == null ? '' : String(va)).toLowerCase(); vb = (vb == null ? '' : String(vb)).toLowerCase(); }
      return va < vb ? -dir : va > vb ? dir : 0;
    });
  }

  // Column schema: [fieldKey, headerLabel, tooltip]
  // fieldKey=null means the column is not sortable (rank #)
  function _orderCols(isDaily, isBudget) {
    const c = [];
    if (isDaily) {
      c.push(
        [null,               '#',              'Sıra numarası'],
        ['kalem_tanimi',     'Ürün Adı',       'Ürün tam adı — üzerine gelin tam adı görün'],
        ['kalem_kodu',       'Kalem Kodu',     'SAP kalem kodu'],
        ['gunluk_satis',     'Günlük Satış',   'Günlük ortalama satış (son 12 ay / 365)'],
        ['kac_gun_yeter',    'Kaç Gün Yeter',  '7 gün altı KRİTİK · 14 gün altı DÜŞÜK'],
        ['mevcut_stok',      'Mevcut Stok',    'Güncel eldeki stok miktarı'],
        ['ort_birim_fiyat',  'Fiyat',          'Ortalama birim satış fiyatı'],
        ['son_birim_maliyet', 'Son Alış',        'En son tedarikçi faturasından alış birim maliyeti'],
        ['marj_pct',          'Marj %',           'Brüt kar marjı: (satış fiyatı − alış maliyeti) / satış fiyatı × 100'],
        ['stok_durumu',      'Durum',          'Stok aciliyeti'],
        ['onerilen_adet',    'Önerilen Adet',  'Önerilen 30 günlük sipariş miktarı'],
        ['onerilen_maliyet', 'Tahmini Maliyet','Önerilen adet × ortalama birim fiyat']
      );
    } else {
      c.push(
        [null,                   '#',              'Sıra numarası'],
        ['kalem_tanimi',         'Ürün Adı',       'Ürün tam adı — üzerine gelin tam adı görün'],
        ['kalem_kodu',           'Kalem Kodu',     'SAP kalem kodu'],
        ['marka',                'Marka',          'Lastik markası'],
        ['avg_sezon_satis',      'Sezon Ort.',     'Geçmiş tüm sezonların ortalama satışı — sipariş hedef miktarı'],
        ['avg_dis_sezon_satis',  'Dışı Talep',     'Sezon dışı aylarda yıllık ort. satış — bu talep de siparişe eklenir'],
        ['kac_sezon',            'Sezon / Trend',  'Kaç sezon veri kullanıldı · ↑ artıyor / ↓ azalıyor / → stabil'],
        ['mevcut_stok',          'Mevcut Stok',    'Güncel eldeki stok'],
        ['tire_boyutu',          'Boyut',          'Ürün adından ayrıştırılan lastik boyutu (genişlik/profil R jant)'],
        ['ort_birim_fiyat',      'Fiyat / Endeks', 'Ortalama fiyat · % aynı boyut piyasa ortalamasına göre konum'],
        ['son_birim_maliyet',    'Son Alış',       'En son tedarikçi faturasından alış birim maliyeti'],
        ['marj_pct',              'Marj %',         'Brüt kar marjı: (satış fiyatı − alış maliyeti) / satış fiyatı × 100'],
        ['stok_durumu',          'Durum',          'KRİTİK: sıfır stok · DÜŞÜK: 1 aylık satıştan az · YETERLİ'],
        ['onerilen_adet',        'Önerilen Adet',  'Sezon ort + dışı talep − mevcut stok'],
        ['onerilen_maliyet',     'Tahmini Maliyet','Tahmini sipariş maliyeti']
      );
    }
    if (isBudget) c.push(['kumulatif_maliyet', 'Kümülatif', 'Bütçe içindeki birikimli maliyet toplamı']);
    return c;
  }

  // Render <tbody> rows for the given (possibly re-sorted) items.
  function _renderTbody(rows, isDaily, isBudget) {
    if (!rows.length) return `<tr><td colspan="20" style="text-align:center;padding:28px;color:rgba(255,255,255,0.25)">Sonuç bulunamadı</td></tr>`;
    return rows.map((r, i) => {
      const status  = r.stok_durumu || (parseFloat(r.kac_gun_yeter) < 7 ? 'KRİTİK' : parseFloat(r.kac_gun_yeter) < 14 ? 'DÜŞÜK' : 'YETERLİ');
      const rowCls  = status === 'KRİTİK' ? 'vmo-ord-kritik' : status === 'DÜŞÜK' ? 'vmo-ord-dusuk' : '';
      const adet         = parseFloat(r.onerilen_adet ?? r.otuz_gunluk_siparis ?? 0);
      const fiyat        = parseFloat(r.ort_birim_fiyat || 0);
      const maliyet      = parseFloat(r.onerilen_maliyet || (adet * fiyat) || 0);
      const alis_birim   = parseFloat(r.son_birim_maliyet || 0);
      const marj_pct     = (fiyat > 0 && alis_birim > 0) ? ((fiyat - alis_birim) / fiyat * 100) : null;
      const badge   = status === 'KRİTİK' ? 'kritik' : status === 'DÜŞÜK' ? 'dusuk' : 'ok';

      let seasonCells = '';
      if (isDaily) {
        const gc = parseFloat(r.kac_gun_yeter) < 7 ? 'vmo-red' : parseFloat(r.kac_gun_yeter) < 14 ? 'vmo-amber' : '';
        seasonCells = `<td>${r.gunluk_satis || '—'}</td><td class="${gc}">${r.kac_gun_yeter || '—'}</td>`;
      } else {
        const dis = parseFloat(r.avg_dis_sezon_satis || 0);
        const tc  = r.talep_trendi === 'ARTIYOR' ? '#4ade80' : r.talep_trendi === 'AZALIYOR' ? '#f87171' : '#94a3b8';
        const ta  = r.talep_trendi === 'ARTIYOR' ? '↑' : r.talep_trendi === 'AZALIYOR' ? '↓' : '→';
        seasonCells = `
          <td title="Geçmiş ${r.kac_sezon || 1} sezon ortalaması">${fmt(r.avg_sezon_satis)}</td>
          <td>${dis > 0 ? `<span style="color:#fbbf24">+${fmt(dis)}</span>` : '<span style="color:rgba(255,255,255,0.2)">—</span>'}</td>
          <td style="font-size:11px;color:rgba(255,255,255,0.55)">${r.kac_sezon || 1}s <span style="color:${tc}">${ta}</span></td>`;
      }

      const sizeCell = !isDaily ? `<td style="font-size:11px">${r.tire_boyutu
        ? `<code style="background:rgba(255,255,255,0.07);padding:2px 5px;border-radius:3px;color:#93c5fd;font-size:10px">${esc(r.tire_boyutu)}</code>`
        : '<span style="color:rgba(255,255,255,0.2)">—</span>'}</td>` : '';

      let endeks = '';
      if (!isDaily && r.fiyat_endeksi != null) {
        const ei  = parseInt(r.fiyat_endeksi);
        const clr = r.fiyat_firsat === 'UCUZ' ? '#4ade80' : r.fiyat_firsat === 'PAHALI' ? '#f87171' : 'rgba(255,255,255,0.3)';
        endeks = `<span title="${r.kac_sku_ayni_boyut || '?'} SKU aynı boyut · piyasa ort: ${formatTRY(r.piyasa_ort_fiyat)}" style="font-size:10px;color:${clr};margin-left:4px">${ei > 0 ? '+' : ''}${ei}%</span>`;
      }

      const kumCell = isBudget
        ? `<td class="${parseFloat(r.kumulatif_maliyet || 0) > ordersBudget * 0.9 ? 'vmo-amber' : ''}">${formatTRY(r.kumulatif_maliyet)}</td>`
        : '';

      return `<tr class="${rowCls}">
        <td class="vmo-ord-idx">${i + 1}</td>
        <td class="vmo-ord-name" title="${esc(r.kalem_tanimi || '')}">${esc((r.kalem_tanimi || '').slice(0, 45))}</td>
        <td class="vmo-ord-code"><code>${esc(r.kalem_kodu || '—')}</code></td>
        ${!isDaily ? `<td style="font-size:12px;white-space:nowrap;color:#93c5fd">${esc(r.marka || '—')}</td>` : ''}
        ${seasonCells}
        <td>${fmt(r.mevcut_stok)}</td>
        ${sizeCell}
        <td style="white-space:nowrap">${formatTRY(fiyat)}${endeks}</td>
        <td style="white-space:nowrap">${r.son_birim_maliyet ? formatTRY(r.son_birim_maliyet) : '<span style="color:rgba(255,255,255,0.2)">—</span>'}</td>
        <td style="white-space:nowrap;font-weight:600;${marj_pct != null ? (marj_pct >= 20 ? 'color:#4ade80' : marj_pct >= 10 ? 'color:#fbbf24' : 'color:#f87171') : ''}">${marj_pct != null ? marj_pct.toFixed(1) + '%' : '<span style="color:rgba(255,255,255,0.2)">—</span>'}</td>
        <td><span class="vmo-status-badge vmo-status-${badge}">${esc(status)}</span></td>
        <td><strong>${fmt(adet)}</strong></td>
        <td class="vmo-ord-cost">${formatTRY(maliyet)}</td>
        ${kumCell}
      </tr>`;
    }).join('');
  }

  // Export current ordersItems to xlsx using SheetJS (loaded on demand from CDN).
  async function exportOrdersExcel() {
    if (!ordersItems.length) return;
    const btn = container.querySelector('#vmo-export-btn');
    if (btn) { btn.textContent = '⏳'; btn.disabled = true; }
    try {
      if (!window.XLSX) {
        await new Promise((ok, fail) => {
          const s = document.createElement('script');
          s.src = 'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js';
          s.onload = ok; s.onerror = fail;
          document.head.appendChild(s);
        });
      }
      const X = window.XLSX;
      const isDaily  = ordersSection === 'daily';
      const isBudget = ordersMode === 'budget';
      const season   = ordersSection === 'winter' ? 'Kis' : ordersSection === 'summer' ? 'Yaz' : 'Gunluk';

      const hdrs = isDaily
        ? ['#','Ürün Adı','Kalem Kodu','Günlük Satış','Kaç Gün Yeter','Mevcut Stok','Ort Fiyat (₺)','Son Alış (₺)','Marj %','Durum','Önerilen Adet','Tahmini Maliyet (₺)']
        : ['#','Ürün Adı','Kalem Kodu','Marka','Sezon Ort (adet)','Dışı Talep (adet)','Sezon Sayısı','Trend','Mevcut Stok','Boyut','Ort Fiyat (₺)','Fiyat Endeksi (%)','Fiyat Notu','Son Alış (₺)','Marj %','Durum','Önerilen Adet','Tahmini Maliyet (₺)'];
      if (isBudget) hdrs.push('Kümülatif Maliyet (₺)');

      const _searchEl = container.querySelector('#vmo-search-input');
      const _q = (_searchEl ? _searchEl.value.trim().toLowerCase() : '');
      const _exportItems = _q
        ? ordersItems.filter(r => (r.kalem_tanimi||'').toLowerCase().includes(_q) || (r.marka||'').toLowerCase().includes(_q) || (r.kalem_kodu||'').toLowerCase().includes(_q) || (r.tire_boyutu||'').toLowerCase().includes(_q))
        : ordersItems;
      const dataRows = _exportItems.map((r, i) => {
        const adet    = parseFloat(r.onerilen_adet ?? r.otuz_gunluk_siparis ?? 0);
        const fiyat   = parseFloat(r.ort_birim_fiyat || 0);
        const maliyet = parseFloat(r.onerilen_maliyet || (adet * fiyat) || 0);
        if (isDaily) {
          const row = [i+1, r.kalem_tanimi||'', r.kalem_kodu||'', parseFloat(r.gunluk_satis||0),
            parseFloat(r.kac_gun_yeter||0), parseFloat(r.mevcut_stok||0), fiyat, r.son_birim_maliyet?parseFloat(r.son_birim_maliyet):null, (fiyat>0&&r.son_birim_maliyet>0)?parseFloat(((fiyat-parseFloat(r.son_birim_maliyet))/fiyat*100).toFixed(1)):null, r.stok_durumu||'', adet, maliyet];
          if (isBudget) row.push(parseFloat(r.kumulatif_maliyet||0));
          return row;
        } else {
          const row = [i+1, r.kalem_tanimi||'', r.kalem_kodu||'', r.marka||'',
            parseFloat(r.avg_sezon_satis||0), parseFloat(r.avg_dis_sezon_satis||0),
            r.kac_sezon||1, r.talep_trendi||'', parseFloat(r.mevcut_stok||0),
            r.tire_boyutu||'', fiyat,
            r.fiyat_endeksi != null ? parseFloat(r.fiyat_endeksi) : null,
            r.fiyat_firsat||'', r.son_birim_maliyet?parseFloat(r.son_birim_maliyet):null, (fiyat>0&&r.son_birim_maliyet>0)?parseFloat(((fiyat-parseFloat(r.son_birim_maliyet))/fiyat*100).toFixed(1)):null, r.stok_durumu||'', adet, maliyet];
          if (isBudget) row.push(parseFloat(r.kumulatif_maliyet||0));
          return row;
        }
      });

      const ws = X.utils.aoa_to_sheet([hdrs, ...dataRows]);
      ws['!cols'] = hdrs.map((_, ci) => ({ wch: ci === 1 ? 44 : ci === 2 ? 16 : 15 }));
      const wb = X.utils.book_new();
      X.utils.book_append_sheet(wb, ws, `Siparis_${season}`);
      X.writeFile(wb, `KRB_Siparis_${season}_${new Date().toISOString().slice(0,10)}.xlsx`);
    } catch(err) {
      console.error('[Excel export]', err);
      alert('Excel oluşturulamadı: ' + err.message);
    } finally {
      if (btn) { btn.textContent = '📥 Excel'; btn.disabled = false; }
    }
  }

  // Re-render the table (thead + tbody) preserving current sort state.
  function renderOrderTable() {
    const resultsEl = container.querySelector('#vmo-orders-results');
    if (!resultsEl || !ordersItems.length) return;

    const isDaily  = ordersSection === 'daily';
    const isBudget = ordersMode === 'budget';
    const cols     = _orderCols(isDaily, isBudget);
    const sorted   = _sortItems(ordersItems, ordersSortKey, ordersSortDir);

    const thStyle = 'color:var(--color-text);font-weight:700;font-size:11px;text-transform:uppercase;' +
      'letter-spacing:.07em;padding:9px 10px;background:var(--color-surface-raised);' +
      'border-bottom:2px solid var(--color-border-strong);white-space:nowrap;' +
      'position:sticky;top:0;z-index:2;cursor:pointer;user-select:none';

    const thead = cols.map(([key, label, title]) => {
      const arrow = key && key === ordersSortKey ? (ordersSortDir > 0 ? ' ↑' : ' ↓') : '';
      const sortable = key ? '' : ' style="cursor:default"';
      return `<th data-sk="${esc(key || '')}" style="${thStyle}"${sortable} title="${esc(title)}">${esc(label)}${arrow}</th>`;
    }).join('');

    const totalAdet    = ordersItems.reduce((s,r) => s + parseFloat(r.onerilen_adet || r.otuz_gunluk_siparis || 0), 0);
    const totalMaliyet = ordersItems.reduce((s,r) => s + parseFloat(r.onerilen_maliyet || 0), 0);
    // Weighted avg gross margin: Σ((satış-alış)×adet) / Σ(satış×adet) × 100
    let _wRev = 0, _wKar = 0;
    ordersItems.forEach(r => {
      const f = parseFloat(r.ort_birim_fiyat || 0);
      const m = parseFloat(r.son_birim_maliyet || 0);
      const a = parseFloat(r.onerilen_adet || r.otuz_gunluk_siparis || 0);
      if (f > 0 && m > 0 && a > 0) { _wRev += f * a; _wKar += (f - m) * a; }
    });
    const avgMarj = _wRev > 0 ? (_wKar / _wRev * 100) : null;

    resultsEl.innerHTML = `
      <div class="vmo-order-table-wrap">
        <table class="vmo-order-table vmo-order-table-full">
          <thead><tr>${thead}</tr></thead>
          <tbody id="vmo-orders-tbody">${_renderTbody(sorted, isDaily, isBudget)}</tbody>
          <tfoot>
            <tr class="vmo-ord-total">
              <td colspan="${cols.length - 3}"><strong>Toplam / Ağırlıklı Ort.</strong></td>
              <td><strong>${fmt(totalAdet)}</strong></td>
              <td><strong>${formatTRY(totalMaliyet)}</strong></td>
              <td style="font-weight:700;${avgMarj != null ? (avgMarj >= 20 ? 'color:#4ade80' : avgMarj >= 10 ? 'color:#fbbf24' : 'color:#f87171') : ''}">${avgMarj != null ? avgMarj.toFixed(1) + '%' : '—'}</td>
              ${isBudget ? '<td></td>' : ''}
            </tr>
          </tfoot>
        </table>
      </div>`;

    // Attach column sort listeners
    resultsEl.querySelectorAll('thead th[data-sk]').forEach(th => {
      const key = th.dataset.sk;
      if (!key) return;
      th.addEventListener('click', () => {
        if (ordersSortKey === key) {
          ordersSortDir = -ordersSortDir;
        } else {
          ordersSortKey = key;
          ordersSortDir = 1;
        }
        // Fast tbody-only re-render
        const tbody = resultsEl.querySelector('#vmo-orders-tbody');
        if (tbody) tbody.innerHTML = _renderTbody(_sortItems(ordersItems, ordersSortKey, ordersSortDir), isDaily, isBudget);
        // Refresh sort arrows
        resultsEl.querySelectorAll('thead th[data-sk]').forEach(h => {
          const k = h.dataset.sk;
          const col = cols.find(c => c[0] === k);
          if (!col) return;
          const arr = k === ordersSortKey ? (ordersSortDir > 0 ? ' ↑' : ' ↓') : '';
          h.textContent = col[1] + arr;
        });
      });
    });
  }

  async function loadOrderResults() {
    const resultsEl = container.querySelector('#vmo-orders-results');
    const summaryEl = container.querySelector('#vmo-orders-summary');
    const exportBtn = container.querySelector('#vmo-export-btn');
    if (!resultsEl) return;
    if (ordersSection === 'winter' || ordersSection === 'summer') {
      await loadPreorderData(ordersSection === 'winter' ? 'KIS' : 'YAZ');
      return;
    }

    resultsEl.innerHTML = '<div class="vmo-kpi-loading">Yükleniyor…</div>';
    if (summaryEl) summaryEl.innerHTML = '';
    if (exportBtn) exportBtn.style.display = 'none';
    ordersSortKey = null;
    ordersSortDir = 1;

    try {
      const endpoint = ordersSection === 'daily' ? '/api/bi/orders/daily' : '/api/bi/orders/preorder';
      const params   = new URLSearchParams({ segment: ordersSegment, mode: ordersMode });
      if (ordersSection !== 'daily') params.set('season', ordersSection === 'winter' ? 'kis' : 'yaz');
      if (ordersMode === 'budget') params.set('budget', String(ordersBudget));

      const data    = await apiFetch(`${endpoint}?${params}`);
      ordersItems   = data.items || [];
      const sum     = data.summary || {};
      const isDaily  = ordersSection === 'daily';
      const isBudget = ordersMode === 'budget';

      // Show export button
      if (exportBtn && ordersItems.length) {
        exportBtn.style.display = 'inline-flex';
        exportBtn.onclick = exportOrdersExcel;
      }

      // ── Summary bar ─────────────────────────────────────────────────────────
      if (summaryEl) {
        const pct = (isBudget && sum.budget > 0 && sum.toplam_maliyet != null)
          ? Math.min(100, (sum.toplam_maliyet / sum.budget) * 100).toFixed(0) : null;

        summaryEl.innerHTML = `
          <div class="vmo-ord-summary">
            <div class="vmo-ord-stat vmo-ord-stat-red">
              <div class="vmo-ord-stat-val">${sum.kritik ?? '—'}</div>
              <div class="vmo-ord-stat-lbl">KRİTİK</div>
            </div>
            <div class="vmo-ord-stat vmo-ord-stat-amber">
              <div class="vmo-ord-stat-val">${sum.dusuk ?? '—'}</div>
              <div class="vmo-ord-stat-lbl">DÜŞÜK</div>
            </div>
            <div class="vmo-ord-stat">
              <div class="vmo-ord-stat-val">${ordersItems.length}</div>
              <div class="vmo-ord-stat-lbl">${isBudget ? 'Bütçe İçi Kalem' : 'Toplam Kalem'}</div>
            </div>
            ${!isDaily && sum.kac_sezon ? `
            <div class="vmo-ord-stat" title="Bu kadar geçmiş sezon ortalamasına dayanıyor">
              <div class="vmo-ord-stat-val">${sum.kac_sezon}</div>
              <div class="vmo-ord-stat-lbl">Sezon Verisi</div>
            </div>` : ''}
            ${!isDaily && sum.ucuz_firsat > 0 ? `
            <div class="vmo-ord-stat" title="Aynı boyuta göre piyasadan %15+ ucuz SKU sayısı">
              <div class="vmo-ord-stat-val" style="color:#4ade80">↓${sum.ucuz_firsat}</div>
              <div class="vmo-ord-stat-lbl">Ucuz Fırsat</div>
            </div>` : ''}
            ${!isDaily && sum.pahali_uyari > 0 ? `
            <div class="vmo-ord-stat" title="Aynı boyutta piyasadan %20+ pahalı SKU sayısı">
              <div class="vmo-ord-stat-val" style="color:#f87171">↑${sum.pahali_uyari}</div>
              <div class="vmo-ord-stat-lbl">Pahalı Uyarı</div>
            </div>` : ''}
            <div class="vmo-ord-stat">
              <div class="vmo-ord-stat-val">${formatTRY(sum.toplam_maliyet)}</div>
              <div class="vmo-ord-stat-lbl">${isBudget ? 'Bütçe Kullanımı' : 'Toplam Maliyet'}</div>
            </div>
            ${isBudget && sum.budget ? `
            <div class="vmo-ord-stat" title="Tanımlanan sipariş bütçesi">
              <div class="vmo-ord-stat-val">${formatTRY(sum.budget)}</div>
              <div class="vmo-ord-stat-lbl">Bütçe</div>
            </div>
            <div class="vmo-ord-budget-bar-wrap">
              <div class="vmo-ord-budget-track">
                <div class="vmo-ord-budget-fill" style="width:${pct}%;background:${parseFloat(pct)>90?'#ef4444':parseFloat(pct)>70?'#f59e0b':'#10b981'}"></div>
              </div>
              <div class="vmo-ord-budget-label">${pct}% kullanıldı</div>
            </div>` : ''}
          </div>`;
      }

      if (!ordersItems.length) {
        resultsEl.innerHTML = '<div class="vmo-no-data">Bu filtre için sipariş önerisi bulunamadı.</div>';
        return;
      }

      renderOrderTable();

    } catch(e) {
      resultsEl.innerHTML = `<div class="vmo-kpi-err">Yüklenemedi: ${esc(e.message)}</div>`;
    }
  }


  async function loadPreorderData(initialSezon) {
    const resultsEl = container.querySelector('#vmo-orders-results');
    if (!resultsEl) return;
    let _sezon    = initialSezon || 'KIS';
    let _expRow   = '';
    let _filterMarka = '';
    let _minTavsiye  = 0;

    async function fetchAndRender() {
      resultsEl.innerHTML = '<div class="vmo-kpi-loading">Ön sipariş analizi yapılıyor…</div>';
      try {
        const data = await apiFetch('/api/bi/preorder/recommend-v2?sezon=' + _sezon);
        if (!data || !Array.isArray(data.items)) {
          resultsEl.innerHTML = '<div class="vmo-kpi-empty">Ön sipariş verisi bulunamadı.</div>';
          return;
        }
        renderTable(data.items);
      } catch(e) {
        resultsEl.innerHTML = '<div class="vmo-kpi-err">Analiz yüklenemedi: ' + e.message + '</div>';
      }
    }

    function renderTable(allItems) {
      var items = allItems;
      if (_filterMarka) items = items.filter(function(it){ return it.marka === _filterMarka; });
      if (_minTavsiye > 0) items = items.filter(function(it){ return it.tavsiye >= _minTavsiye; });

      var markas = Array.from(new Set(allItems.map(function(it){ return it.marka; }).filter(Boolean))).sort();
      var critCnt  = items.filter(function(it){ return it.stock_status === 'CRITICAL'; }).length;
      var lowCnt   = items.filter(function(it){ return it.stock_status === 'LOW'; }).length;
      var highCnt  = items.filter(function(it){ return it.confLevel === 'HIGH'; }).length;
      var totalCost = items.reduce(function(s,it){ return s + it.tahmini_maliyet; }, 0);

      var fmtN  = function(n) { return (n === null || n === undefined) ? '—' : Number(n).toLocaleString('tr-TR'); };
      var fmtTL = function(n) { return (!n || n === 0) ? '—' : '₺' + Math.round(n).toLocaleString('tr-TR'); };
      var tCol  = function(t) { return t==='GROWING' ? '#22c55e' : t==='DECLINING' ? '#ef4444' : 'var(--text-muted,#888)'; };
      var stCol = function(c) { return (c==='EXCELLENT'||c==='GOOD') ? '#22c55e' : c==='MODERATE' ? '#f59e0b' : c==='POOR' ? '#ef4444' : 'var(--text-muted,#777)'; };
      var gCol  = function(c) { return c==='FAST' ? '#22c55e' : c==='SLOW' ? '#ef4444' : 'var(--text,#ccc)'; };
      var cCol  = function(lv) { return lv==='HIGH' ? '#22c55e' : lv==='MEDIUM' ? '#f59e0b' : '#ef4444'; };
      var sCol  = function(s) { return s==='CRITICAL' ? '#ef4444' : s==='LOW' ? '#f59e0b' : '#22c55e'; };
      var tuCol = function(t) { return t>=75 ? '#22c55e' : t>=50 ? '#f59e0b' : '#ef4444'; };

      var btnS = function(active) {
        return 'padding:6px 16px;border-radius:20px;cursor:pointer;font-size:13px;border:1px solid #3b82f6;'
          + (active ? 'background:#3b82f6;color:#fff;' : 'background:transparent;color:var(--text,#e0e0e0);');
      };

      var html = '';

      // Season tabs
      html += '<div style="display:flex;gap:8px;margin-bottom:14px;align-items:center;flex-wrap:wrap;">'
        + '<button id="po-tab-kis" style="' + btnS(_sezon==='KIS') + '">❄️ Kış Ön Sipariş</button>'
        + '<button id="po-tab-yaz" style="' + btnS(_sezon==='YAZ') + '">☀️ Yaz Ön Sipariş</button>'
        + '<span style="font-size:11px;color:var(--text-muted,#888);margin-left:8px;">'
        + (_sezon==='KIS' ? 'Sipariş Penceresi: Temmuz–Ağustos · Sezon: Ekim–Mart' : 'Sipariş Penceresi: Şubat–Mart · Sezon: Nisan–Eylül')
        + '</span></div>';

      // KPI strip
      html += '<div style="display:flex;gap:10px;margin-bottom:14px;flex-wrap:wrap;">'
        + '<div style="padding:8px 14px;background:var(--bg2,#1e1e1e);border-radius:6px;border-left:3px solid #ef4444;min-width:90px;">'
        + '<div style="font-size:9px;color:var(--text-muted,#888);text-transform:uppercase;">Kritik Stok</div>'
        + '<div style="font-size:22px;font-weight:800;color:#ef4444;">' + critCnt + '</div></div>'
        + '<div style="padding:8px 14px;background:var(--bg2,#1e1e1e);border-radius:6px;border-left:3px solid #f59e0b;min-width:90px;">'
        + '<div style="font-size:9px;color:var(--text-muted,#888);text-transform:uppercase;">Düşük Stok</div>'
        + '<div style="font-size:22px;font-weight:800;color:#f59e0b;">' + lowCnt + '</div></div>'
        + '<div style="padding:8px 14px;background:var(--bg2,#1e1e1e);border-radius:6px;border-left:3px solid #22c55e;min-width:90px;">'
        + '<div style="font-size:9px;color:var(--text-muted,#888);text-transform:uppercase;">Yüksek Güven</div>'
        + '<div style="font-size:22px;font-weight:800;color:#22c55e;">' + highCnt + '</div></div>'
        + '<div style="padding:8px 14px;background:var(--bg2,#1e1e1e);border-radius:6px;border-left:3px solid #3b82f6;min-width:130px;">'
        + '<div style="font-size:9px;color:var(--text-muted,#888);text-transform:uppercase;">Tahmini Sipariş Maliyeti</div>'
        + '<div style="font-size:16px;font-weight:800;color:#3b82f6;">' + fmtTL(totalCost) + '</div></div>'
        + '</div>';

      // Filter bar
      var markaOpts = '<option value="">Tüm Markalar</option>'
        + markas.map(function(m){ return '<option value="' + m + '"' + (m===_filterMarka?' selected':'') + '>' + m + '</option>'; }).join('');
      html += '<div style="display:flex;gap:10px;margin-bottom:12px;align-items:center;flex-wrap:wrap;">'
        + '<select id="po-marka-sel" style="padding:5px 8px;border-radius:4px;border:1px solid var(--border,#333);background:var(--bg2,#1e1e1e);color:var(--text,#e0e0e0);font-size:12px;">' + markaOpts + '</select>'
        + '<label style="font-size:12px;color:var(--text-muted,#999);">Min Tavsiye Adet:</label>'
        + '<input id="po-min-tavsiye" type="number" min="0" value="' + _minTavsiye + '" style="width:64px;padding:3px 6px;border-radius:4px;border:1px solid var(--border,#333);background:var(--bg2,#1e1e1e);color:var(--text,#e0e0e0);font-size:12px;">'
        + '<span style="font-size:11px;color:var(--text-muted,#777);">' + items.length + ' SKU gösteriliyor</span>'
        + '<button id="po-xl-btn" style="margin-left:auto;padding:5px 14px;border-radius:4px;border:none;background:#27ae60;color:#fff;font-size:12px;cursor:pointer;">⬇️ Excel</button>'
        + '</div>';

      // Table
      var th = function(txt, align, tip) {
        var titleAttr = tip ? ' title="' + tip + '"' : '';
        var cursor = tip ? 'cursor:help;' : '';
        var label = tip ? txt + ' <span style="font-size:9px;opacity:0.6;vertical-align:super;">ⓘ</span>' : txt;
        return '<th' + titleAttr + ' style="' + cursor + 'padding:7px 6px;text-align:' + (align||'right') + ';border-bottom:1px solid var(--border,#333);font-size:10px;color:var(--text-muted,#888);white-space:nowrap;">' + label + '</th>';
      };
      html += '<div style="overflow-x:auto;">';
      html += '<table id="po-tbl" style="width:100%;border-collapse:collapse;font-size:11px;min-width:960px;">';
      html += '<thead><tr style="background:var(--bg2,#181818);">'
        + th('ÜRÜN / SKU', 'left')
        + th('SEZON<br>ORT.')
        + th('MEVCUT<br>STOK')
        + th('TREND', 'right', 'Satış trendi: ↑ artıyor, → stabil, ↓ azalıyor. Geçen sezonla karşılaştırılır.')
        + th('SATIŞ<br>ORANI', 'right', 'Stokun satılan yüzdesi (%). Yüksek oran = hızlı satan ürün.')
        + th('TUTARLILIK<br>/100', 'right', 'Satış düzenliliği puanı (0–100). 100 = her dönem düzenli satış, düşük = mevsimsel/düzensiz.')
        + th('HAREKET<br>(GÜN)', 'right', 'Ortalama satış hızı: bir ürünün satılması için geçen ortalama gün sayısı. Düşük = hızlı hareket.')
        + th('GÜVEN<br>/100', 'right', 'Önerinin güvenilirlik puanı (0–100). Veri kalitesi ve satış geçmişine göre hesaplanır.')
        + th('TAVSİYE<br>ADET')
        + th('TAHMİNİ<br>MALİYET')
        + '</tr></thead><tbody>';

      if (!items.length) {
        html += '<tr><td colspan="10" style="padding:24px;text-align:center;color:var(--text-muted,#666);">Kriter karşılayan SKU bulunamadı.</td></tr>';
      }

      items.forEach(function(it) {
        var isExp  = it.kalem_kodu === _expRow;
        var rowBg  = isExp
          ? 'background:var(--bg-hover,#1a2a3a);'
          : it.stock_status === 'CRITICAL' ? 'background:rgba(239,68,68,0.04);'
          : '';

        html += '<tr class="po-row" data-kodu="' + it.kalem_kodu + '" style="cursor:pointer;border-bottom:1px solid var(--border-light,#1a1a1a);' + rowBg + '">';

        // Product
        var title = (it.kalem_tanimi || '').replace(/"/g,'&quot;');
        html += '<td style="padding:6px 8px;max-width:200px;">'
          + '<div style="font-weight:600;font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="' + title + '">'
          + (isExp ? '▾ ' : '▸ ') + (it.kalem_tanimi||'—').slice(0,38)
          + '</div>'
          + '<div style="font-size:9px;color:var(--text-muted,#888);margin-top:1px;">'
          + (it.marka||'') + (it.ebat ? ' · ' + it.ebat : '') + ' · ' + it.yil_sayisi + ' yıl veri'
          + '</div></td>';

        // Seasonal avg
        html += '<td style="padding:6px;text-align:right;font-weight:600;">' + fmtN(it.ort_satis) + '</td>';

        // Current stock
        html += '<td style="padding:6px;text-align:right;color:' + sCol(it.stock_status) + ';font-weight:700;">'
          + fmtN(it.eldeki)
          + '<div style="font-size:9px;font-weight:400;">' + it.stockTR + '</div></td>';

        // Trend
        html += '<td style="padding:6px;text-align:right;color:' + tCol(it.trend) + ';font-weight:600;">'
          + it.trendTR
          + '<div style="font-size:9px;color:var(--text-muted,#777);">' + fmtN(it.son_sezon_satis) + ' son</div></td>';

        // Sell-through
        html += '<td style="padding:6px;text-align:right;color:' + stCol(it.stClass) + ';font-weight:600;">'
          + (it.sell_through_pct !== null ? '%' + it.sell_through_pct.toFixed(0) : '—')
          + '<div style="font-size:9px;">' + it.stTR + '</div></td>';

        // Consistency
        html += '<td style="padding:6px;text-align:right;">'
          + '<span style="font-weight:700;font-size:13px;color:' + tuCol(it.tutarlilik) + ';">' + it.tutarlilik + '</span>'
          + '</td>';

        // Days to sell
        html += '<td style="padding:6px;text-align:right;color:' + gCol(it.gunClass) + ';font-weight:600;">'
          + (it.gun !== null ? it.gun + '' : '—')
          + '<div style="font-size:9px;">' + it.gunTR + '</div></td>';

        // Confidence
        html += '<td style="padding:6px;text-align:right;">'
          + '<span style="font-weight:700;font-size:13px;color:' + cCol(it.confLevel) + ';">' + it.confidence + '</span>'
          + '<div style="font-size:9px;color:' + cCol(it.confLevel) + ';">' + it.confTR + '</div></td>';

        // Recommended qty
        html += '<td style="padding:6px;text-align:right;'
          + (it.tavsiye > 0 ? 'font-weight:800;font-size:14px;color:#3b82f6;' : 'color:var(--text-muted,#555);') + '">'
          + fmtN(it.tavsiye) + '</td>';

        // Estimated cost
        html += '<td style="padding:6px;text-align:right;color:' + (it.tahmini_maliyet > 0 ? 'var(--text,#ccc)' : 'var(--text-muted,#444)') + ';">'
          + fmtTL(it.tahmini_maliyet) + '</td>';

        html += '</tr>';

        // Inline expand: explanation + detail
        if (isExp) {
          html += '<tr><td colspan="10" style="padding:0;">'
            + '<div style="padding:12px 16px;background:var(--bg2,#101820);border-left:3px solid #3b82f6;border-bottom:1px solid var(--border,#333);font-size:12px;line-height:1.7;color:var(--text,#ccc);">'
            + '<strong style="color:var(--text,#e0e0e0);">📋 ' + (it.kalem_kodu||'') + ' — ' + (it.kalem_tanimi||'') + '</strong>'
            + '<br><br>💡 ' + it.aciklama
            + '<br><br><div style="display:flex;gap:20px;flex-wrap:wrap;margin-top:4px;font-size:10px;color:var(--text-muted,#888);">'
            + '<span>Birim Maliyet: <strong>' + fmtTL(it.birim_maliyet) + '</strong></span>'
            + '<span>5Y Ort. Satış: <strong>' + fmtN(it.ort_satis) + ' adet</strong></span>'
            + '<span>Son Sezon: <strong>' + fmtN(it.son_sezon_satis) + ' adet</strong></span>'
            + '<span>Veri Yılı: <strong>' + it.yil_sayisi + '</strong></span>'
            + (it.sell_through_pct !== null ? '<span>Satış Oranı: <strong>%' + it.sell_through_pct.toFixed(0) + '</strong></span>' : '')
            + (it.gun !== null ? '<span>Ort. Hareket: <strong>' + it.gun + ' gün</strong></span>' : '')
            + '</div></div>'
            + '</td></tr>';
        }
      });

      html += '</tbody></table></div>';
      resultsEl.innerHTML = html;

      // Wire events
      resultsEl.querySelector('#po-tab-kis').addEventListener('click', function() { _sezon='KIS'; fetchAndRender(); });
      resultsEl.querySelector('#po-tab-yaz').addEventListener('click', function() { _sezon='YAZ'; fetchAndRender(); });

      resultsEl.querySelector('#po-marka-sel').addEventListener('change', function(e) {
        _filterMarka = e.target.value; renderTable(allItems);
      });
      resultsEl.querySelector('#po-min-tavsiye').addEventListener('input', function(e) {
        _minTavsiye = parseInt(e.target.value) || 0; renderTable(allItems);
      });

      // Row click: expand/collapse
      resultsEl.querySelectorAll('.po-row').forEach(function(row) {
        row.addEventListener('click', function() {
          _expRow = (row.dataset.kodu === _expRow) ? '' : row.dataset.kodu;
          renderTable(allItems);
        });
      });

      // Excel export
      resultsEl.querySelector('#po-xl-btn').addEventListener('click', function() {
        var sezonLbl = _sezon === 'KIS' ? 'Kis' : 'Yaz';
        var header = ['SKU','Ürün','Marka','Ebat','Sezon','5Y Ort.Satış','Son Sezon',
          'Mevcut Stok','Stok Durumu','Trend','Satış Oranı%','Tutarlılık',
          'Hareket(gün)','Güven','Güven Seviye','Tavsiye Adet','Tahmini Maliyet','Açıklama'].join('\t');
        var lines = items.map(function(it) {
          return [
            it.kalem_kodu, it.kalem_tanimi, it.marka, it.ebat, _sezon,
            it.ort_satis, it.son_sezon_satis, it.eldeki, it.stockTR, it.trendTR,
            it.sell_through_pct !== null ? it.sell_through_pct.toFixed(1) : '',
            it.tutarlilik,
            it.gun !== null ? it.gun : '',
            it.confidence, it.confTR,
            it.tavsiye, it.tahmini_maliyet,
            it.aciklama.replace(/\t/g,' ')
          ].join('\t');
        });
        var tsv = header + '\n' + lines.join('\n');
        var a = document.createElement('a');
        a.href = URL.createObjectURL(new Blob([tsv], { type: 'text/tab-separated-values' }));
        a.download = 'onsiparisv2_' + sezonLbl + '.tsv';
        a.click();
      });
    }

    await fetchAndRender();
  }

    async function loadItKpis() {
    const kpiEl   = container.querySelector("#vmo-kpis-it");
    const chartEl = container.querySelector("#vmo-chart-it");
    try {
      const rows = await apiFetch("/api/bi/it/kpis");
      if (!rows.length) { kpiEl.innerHTML = `<div class="vmo-no-data">Henüz veri alınmamış.</div>`; return; }
      kpiEl.innerHTML = rows.map(r => kpi(r.query_type,
        r.saat_once ? `${parseFloat(r.saat_once).toFixed(1)}s önce` : "—",
        `Son: ${r.son_veri_tarihi||"—"}`,
        r.haftalik_hata > 0 ? "down" : "up")).join("");
      chartEl.innerHTML = `
        <div class="vmo-it-table">
          <table>
            <thead><tr><th>Sorgu</th><th>Son Veri</th><th>Güncelleme</th><th>Bugün</th><th>7g Hata</th></tr></thead>
            <tbody>${rows.map(r=>`
              <tr>
                <td><code>${esc(r.query_type)}</code></td>
                <td>${r.son_veri_tarihi||"—"}</td>
                <td>${r.son_guncelleme?new Date(r.son_guncelleme).toLocaleString("tr-TR"):"—"}</td>
                <td>${fmt(r.bugunki_satirlar||0)} satır</td>
                <td class="${r.haftalik_hata>0?"vmo-red":"vmo-green"}">${r.haftalik_hata||0}</td>
              </tr>`).join("")}
            </tbody>
          </table>
        </div>`;
    } catch(e) { kpiEl.innerHTML = kpiErr(e.message); }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Chat
  // ═════════════════════════════════════════════════════════════════════════

  async function sendChat(dept, message) {
    const chatEl = container.querySelector(`#vmo-chat-${dept}`);
    if (!chatEl) return;
    chatEl.querySelector(".vmo-chat-welcome")?.remove();

    addBubble(chatEl, "user", message);
    const assistant = addBubble(chatEl, "assistant", "");
    const textEl = assistant.querySelector(".vmo-bubble-text");

    try {
      await streamChat(dept, message, chunk => {
        textEl.textContent += chunk;
        chatEl.scrollTop = chatEl.scrollHeight;
      });
    } catch(err) {
      textEl.textContent = `Hata: ${err.message}`;
      textEl.style.color = "#f87171";
    }
    chatEl.scrollTop = chatEl.scrollHeight;
  }

  function addBubble(chatEl, role, text) {
    const div = document.createElement("div");
    div.className = `vmo-bubble vmo-bubble-${role}`;
    div.innerHTML = `<div class="vmo-bubble-text">${esc(text)}</div>`;
    chatEl.appendChild(div);
    chatEl.scrollTop = chatEl.scrollHeight;
    return div;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Chart renderer
  // ═════════════════════════════════════════════════════════════════════════

  // [patch: smart-chart]
  function fmtAbbrev(v) {
    const n = parseFloat(v);
    if (isNaN(n)) return "—";
    const abs = Math.abs(n);
    if (abs >= 1e9) return (n/1e9).toLocaleString("tr-TR",{maximumFractionDigits:1}) + 'Mr';
    if (abs >= 1e6) return (n/1e6).toLocaleString("tr-TR",{maximumFractionDigits:1}) + 'M';
    if (abs >= 1e3) return (n/1e3).toLocaleString("tr-TR",{maximumFractionDigits:0}) + 'K';
    return n.toLocaleString("tr-TR",{maximumFractionDigits:0});
  }

  function renderChart(el, labels, values, title, color, multiColor = false) {
    if (!values.length) { el.innerHTML = `<div class="vmo-no-data">Veri yok.</div>`; return; }
    const W=700, H=220, PL=58, PR=16, PT=24, PB=44;
    const cW=W-PL-PR, cH=H-PT-PB;
    const maxV = Math.max(...values.map(Math.abs), 1);
    const minV = Math.min(...values, 0);
    const range = maxV - Math.min(minV, 0);
    const barW = Math.min(32, Math.max(8, (cW/labels.length)-4));
    const colors = Array.isArray(color) ? color : values.map(v => v<0 ? "#ef4444" : color);
    const zeroY = PT + cH - (0 - Math.min(minV,0)) / range * cH;

    const bars = labels.map((lbl,i) => {
      const v = values[i];
      const bH = Math.max(2, (Math.abs(v)/range)*cH);
      const x  = PL + (i+0.5)*(cW/labels.length) - barW/2;
      const y  = v >= 0 ? zeroY - bH : zeroY;
      const c  = colors[i%colors.length];
      // Highlight last bar (current period)
      const opacity = i === values.length-1 ? "1" : "0.78";
      const stroke  = i === values.length-1 ? `stroke="${c}" stroke-width="1.5"` : "";
      return `<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${barW}" height="${bH.toFixed(1)}"
                fill="${c}" rx="3" opacity="${opacity}" ${stroke}>
                <title>${esc(lbl)}: ${fmtAbbrev(v)}</title>
              </rect>`;
    }).join("");

    // x-axis labels — every label shown
    const xLabels = labels.map((lbl,i) => {
      const x = PL + (i+0.5)*(cW/labels.length);
      // Skip every other if crowded
      if (labels.length > 12 && i % 2 !== 0) return "";
      return `<text x="${x.toFixed(1)}" y="${H-PB+14}" text-anchor="middle" font-size="9.5" fill="#6b7280">${esc(lbl)}</text>`;
    }).join("");

    // y-axis grid + ticks — 4 levels, abbreviated
    const ticks = [0, 0.25, 0.5, 0.75, 1].map(p => {
      const val = maxV * p;
      const y2  = (zeroY - p * (zeroY - PT)).toFixed(1);
      return `<line x1="${PL}" y1="${y2}" x2="${W-PR}" y2="${y2}" stroke="rgba(255,255,255,0.05)" stroke-width="1"/>
              <text x="${PL-6}" y="${parseFloat(y2)+3.5}" text-anchor="end" font-size="9.5" fill="#6b7280">${fmtAbbrev(val)}</text>`;
    }).join("");

    el.innerHTML = `<div class="vmo-chart-title">${esc(title)}</div>
      <svg viewBox="0 0 ${W} ${H}" style="width:100%;max-height:220px;display:block">
        ${ticks}${bars}${xLabels}
        <line x1="${PL}" y1="${PT}" x2="${PL}" y2="${PT+cH}" stroke="rgba(255,255,255,0.1)" stroke-width="1"/>
        <line x1="${PL}" y1="${zeroY.toFixed(1)}" x2="${W-PR}" y2="${zeroY.toFixed(1)}" stroke="rgba(255,255,255,0.15)" stroke-width="1"/>
      </svg>`;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Utilities
  // ═════════════════════════════════════════════════════════════════════════

  function kpi(label, value, sub, trend) {
    const badge = trend==="up" ? `<span class="vmo-trend-up">↑</span>` :
                  trend==="down" ? `<span class="vmo-trend-down">↓</span>` : "";
    return `<div class="vmo-kpi-card">
      <div class="vmo-kpi-label">${esc(label)}</div>
      <div class="vmo-kpi-value">${esc(String(value??"—"))} ${badge}</div>
      ${sub?`<div class="vmo-kpi-sub">${esc(sub)}</div>`:""}
    </div>`;
  }

  function kpiErr(msg) { return `<div class="vmo-kpi-err" style="grid-column:1/-1">Yüklenemedi: ${esc(msg)}</div>`; }
  function formatTRY(v) { const n=parseFloat(v); return isNaN(n)?"—":n.toLocaleString("tr-TR",{minimumFractionDigits:0,maximumFractionDigits:0})+" ₺"; }
  function fmt(v) { const n=parseFloat(v); return isNaN(n)?"—":n.toLocaleString("tr-TR"); }
  function esc(s) { return String(s??"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;"); }

  function quickPrompts(dept) {
    return ({
      sales:     ["Geçen aya göre ciro nasıl değişti?","En çok satan 5 markamız?","Hangi müşteriler büyüyor?"],
      pricing:   ["Nakit döngümüz kaç gün?","Marjı düşen ürünler hangileri?","CCC'yi nasıl iyileştirebiliriz?"],
      warehouse: ["Kritik stok seviyeleri nerede?","90 günde hareketsiz ürünler?","Stok devir hızımız nasıl?"],
      it:        ["SAP verileri ne zaman güncellendi?","Veri aktarımında sorun var mı?","Hangi sorgular en eskide kaldı?"],
      orders:    ["Kış lastiği ne zaman sipariş verilmeli?","Kritik stokta kaç ürün var?","Bütçe planı nasıl yapabiliriz?"]
    })[dept] || [];
  }
}

// ── Styles ───────────────────────────────────────────────────────────────────
function vmoStyles() {
  return `
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


  #bi-surface, #vmo-shell-mount { height:100%; overflow:hidden; }
  .vmo-shell { display:flex; flex-direction:column; height:100vh; background:#0a0a1e; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; color:#e0e6f0; }

  /* ── Header ── */
  .vmo-header { display:grid; grid-template-columns:auto 1fr auto; align-items:center; gap:8px; padding:0 16px; height:54px; background:rgba(255,255,255,0.03); border-bottom:1px solid rgba(255,255,255,0.07); flex-shrink:0; overflow:hidden; }
  .vmo-brand { display:flex; align-items:center; gap:10px; flex-shrink:0; }
  .vmo-brand-text { font-size:14px; color:#ccc; }
  .vmo-brand-text strong { color:#e2b04a; }
  .vmo-brand-sub { color:rgba(255,255,255,0.25); font-size:11px; margin-left:6px; }
  .vmo-tabs { flex:1; display:flex; justify-content:center; gap:4px; }
  .vmo-tab { display:flex; align-items:center; gap:7px; padding:6px 18px; border:none; border-radius:8px; background:rgba(255,255,255,0.05); color:rgba(255,255,255,0.45); font-size:13px; font-weight:500; cursor:pointer; transition:all .15s; }
  .vmo-tab:hover { background:rgba(255,255,255,0.1); color:#fff; }
  .vmo-tab.active { background:var(--c); color:#fff; font-weight:600; box-shadow:0 0 20px color-mix(in srgb,var(--c) 40%,transparent); }
  .vmo-header-right { display:flex; align-items:center; gap:8px; min-width:0; overflow:hidden; }
  .vmo-macro-ticker { display:flex; align-items:center; gap:5px; font-size:11px; color:rgba(255,255,255,0.5); background:rgba(255,255,255,0.05); border:1px solid rgba(255,255,255,0.09); border-radius:6px; padding:3px 10px; white-space:nowrap; overflow:hidden; flex-shrink:1; min-width:0; max-width:30vw; }
  .vmo-logout { display:flex; align-items:center; gap:5px; padding:6px 12px; background:rgba(239,68,68,0.12); border:1px solid rgba(239,68,68,0.35); border-radius:7px; color:#f87171; font-size:12px; font-weight:600; cursor:pointer; white-space:nowrap; flex-shrink:0; }
  .vmo-logout:hover { background:rgba(239,68,68,0.22); border-color:rgba(239,68,68,0.6); }
  .vmo-macro-ticker .vmo-mt-item { display:flex; gap:3px; align-items:center; }
  .vmo-macro-ticker .vmo-mt-item span { color:#e2b04a; font-weight:700; }
  .vmo-macro-ticker .vmo-mt-sep { color:rgba(255,255,255,0.2); }
  .vmo-macro-ticker .vmo-mt-date { color:rgba(255,255,255,0.3); font-size:10px; margin-left:2px; }
  .vmo-size-search { display:flex; align-items:center; gap:8px; padding:6px 0; }
  .vmo-search-input { flex:1; background:rgba(255,255,255,0.05); border:1px solid rgba(255,255,255,0.12); border-radius:6px; color:#fff; font-size:12px; padding:5px 10px; outline:none; max-width:320px; }
  .vmo-search-input:focus { border-color:rgba(226,176,74,0.5); background:rgba(255,255,255,0.08); }
  .vmo-search-input::placeholder { color:rgba(255,255,255,0.3); }
  .vmo-search-clear { background:none; border:none; color:rgba(255,255,255,0.4); cursor:pointer; font-size:14px; padding:2px 4px; border-radius:4px; }
  .vmo-search-clear:hover { color:#fff; }
  .vmo-tenant { font-size:12px; color:rgba(255,255,255,0.3); }
  .vmo-feedback-btn {
    background:linear-gradient(135deg,rgba(102,126,234,0.2),rgba(118,75,162,0.2));
    border:1px solid rgba(102,126,234,0.4);
    color:#c4b5fd;
    border-radius:8px;
    padding:6px 12px;
    font-size:12px;
    font-weight:600;
    cursor:pointer;
    transition:all 0.2s;
  }
  .vmo-feedback-btn:hover {
    background:linear-gradient(135deg,rgba(102,126,234,0.4),rgba(118,75,162,0.4));
    color:#fff;
  }
  .vmo-logout { background:none; border:none; color:rgba(255,255,255,0.3); cursor:pointer; padding:6px; border-radius:6px; display:flex; }
  .vmo-logout:hover { color:#fff; background:rgba(255,255,255,0.1); }

  /* ── Office & rooms ── */
  .vmo-office { flex:1; overflow:hidden; position:relative; }
  .vmo-room { display:flex; height:100%; }
  .vmo-room-hidden { display:none !important; }  /* ANA_UI_FIX */
  /* ⚠ Eski koyu-tema CSS'i (#e2e8f0 vb.) metin rengini eziyordu.
     ID secicisi + inherit ile yeni odada TOKENLER kazansin. */
  #vmo-room-bugun, #vmo-room-bugun * { color: inherit; }
  #vmo-room-bugun { color: var(--tx-0) !important; background: var(--zemin-0) !important; }
  #vmo-room-bugun .etiket { color: var(--tx-2) !important; }
  #vmo-room-bugun .d-kirmizi { color: var(--kirmizi) !important; }
  #vmo-room-bugun .d-sari    { color: var(--sari)    !important; }
  #vmo-room-bugun .d-yesil   { color: var(--yesil)   !important; }
  #vmo-room-bugun .kart      { background: var(--zemin-1) !important; border-color: var(--cizgi) !important; }
  #vmo-room-bugun .dg        { color: var(--tx-0) !important; border-color: var(--cizgi-g) !important; }
  /* ── Hub ── */
  .vmo-hub-wrap{position:relative;width:100%;height:100%;background:radial-gradient(ellipse at 50% 42%,#0c1b3a 0%,#080818 65%);display:flex;flex-direction:column;align-items:center;justify-content:center;overflow:hidden}
  .vmo-hub-glow{position:absolute;top:42%;left:50%;transform:translate(-50%,-50%);width:440px;height:440px;background:radial-gradient(circle,rgba(225,29,72,0.07) 0%,transparent 70%);pointer-events:none}
  #vmo-hub-canvas{position:absolute;inset:0;pointer-events:none;display:block}
  .vmo-hub-center{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;gap:6px;z-index:10;text-align:center;pointer-events:none}
  .vmo-hub-ring{position:absolute;border-radius:50%;border:1px solid rgba(225,29,72,0.22);top:50%;left:50%;transform:translate(-50%,-50%)}
  @keyframes vmo-rpulse{0%,100%{opacity:0.4}50%{opacity:1}}
  .r1{width:88px;height:88px;animation:vmo-rpulse 3s ease-in-out 0s infinite}
  .r2{width:122px;height:122px;border-color:rgba(225,29,72,0.11);animation:vmo-rpulse 3s ease-in-out 1s infinite}
  .r3{width:160px;height:160px;border-color:rgba(225,29,72,0.05);animation:vmo-rpulse 3s ease-in-out 2s infinite}
  .vmo-hub-brain-circle{width:70px;height:70px;border-radius:50%;background:radial-gradient(circle,#2d0818 0%,#130310 100%);border:2px solid rgba(225,29,72,0.5);display:flex;align-items:center;justify-content:center;font-size:30px;box-shadow:0 0 30px rgba(225,29,72,0.28),0 0 70px rgba(225,29,72,0.07);position:relative;z-index:2}
  .vmo-hub-center-name{color:#f1f5f9;font-size:13px;font-weight:700;position:relative;z-index:2;white-space:nowrap}
  .vmo-hub-center-sub{color:#475569;font-size:10px;position:relative;z-index:2}
  .vmo-hub-nodes{position:absolute;inset:0;pointer-events:none;z-index:5}
  .vmo-hub-node{position:absolute;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;gap:5px;cursor:pointer;pointer-events:all;text-align:center;transition:transform 0.2s,filter 0.2s;user-select:none}
  .vmo-hub-node:hover{transform:translate(-50%,-50%) scale(1.13);filter:brightness(1.25)}
  .vmo-hub-node-icon{width:52px;height:52px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:22px;border:1.5px solid;transition:box-shadow 0.2s}
  .vmo-hub-node-label{color:#94a3b8;font-size:10px;font-weight:700;white-space:nowrap}
  .vmo-hub-node-name{color:#475569;font-size:9px;white-space:nowrap}
  .vmo-hub-cmd-bar{position:absolute;bottom:22px;left:50%;transform:translateX(-50%);width:min(580px,88%);z-index:20}
  .vmo-hub-cmd-bar form{display:flex;background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.09);border-radius:14px;overflow:hidden;backdrop-filter:blur(8px);transition:border-color 0.2s}
  .vmo-hub-cmd-bar form:focus-within{border-color:rgba(225,29,72,0.4)}
  #vmo-hub-inp{flex:1;background:transparent;border:none;outline:none;color:#f1f5f9;font-size:14px;padding:13px 18px}
  #vmo-hub-inp::placeholder{color:#2d3f5a}
  .vmo-hub-cmd-bar button{background:#e11d48;border:none;color:#fff;padding:0 20px;cursor:pointer;transition:background 0.15s}
  .vmo-hub-cmd-bar button:hover{background:#be123c}
  @media(max-width:700px){
    #vmo-room-home{overflow-y:auto}
    .vmo-hub-wrap{min-height:100%;height:auto;justify-content:flex-start;padding:16px 12px 110px}
    .vmo-hub-svg,.vmo-hub-glow{display:none}
    .vmo-hub-center{position:static;transform:none;margin:14px auto 22px}
    .vmo-hub-nodes{position:static;display:grid;grid-template-columns:1fr 1fr;gap:10px;width:100%;pointer-events:all}
    .vmo-hub-node{position:static;transform:none;flex-direction:row;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.07);border-radius:12px;padding:12px;text-align:left;gap:10px}
    .vmo-hub-node:last-child:nth-child(odd){grid-column:1 / -1;max-width:calc(50% - 5px);margin:0 auto}
    .vmo-hub-node:hover{transform:scale(1.02)}
    .vmo-hub-node-icon{flex-shrink:0;width:44px;height:44px}
    .vmo-hub-cmd-bar{position:fixed;bottom:0;left:0;right:0;transform:none;width:100%;padding:10px 12px;background:rgba(8,8,24,0.96);backdrop-filter:blur(12px);border-top:1px solid rgba(255,255,255,0.07)}
  }


  /* ── Officer panel (left) ── */
  .vmo-officer-panel {
    width:300px; min-width:300px; flex-shrink:0;
    display:flex; flex-direction:column;
    background:var(--bg);
    border-right:1px solid rgba(255,255,255,0.06);
    position:relative; overflow:hidden;
  }
  .vmo-officer-panel::before {
    content:""; position:absolute; inset:0;
    background:radial-gradient(ellipse at 50% 30%, color-mix(in srgb,var(--c) 15%,transparent) 0%,transparent 70%);
    pointer-events:none;
  }
  .vmo-officer-stage {
    padding:32px 20px 20px;
    display:flex; flex-direction:column; align-items:center;
    flex-shrink:0; gap:16px;
  }
  .vmo-avatar-wrap { position:relative; width:110px; height:110px; display:flex; align-items:center; justify-content:center; }
  .vmo-pulse-ring {
    position:absolute; inset:-8px;
    border-radius:50%;
    border:2px solid color-mix(in srgb,var(--c) 40%,transparent);
    animation:vmoPulse 2.4s ease-out infinite;
  }
  .vmo-pulse-ring-2 { inset:-16px; animation-delay:.8s; }
  @keyframes vmoPulse { 0%{opacity:0.7;transform:scale(0.9)} 70%{opacity:0;transform:scale(1.15)} 100%{opacity:0} }
  .vmo-avatar-circle {
    width:100px; height:100px; border-radius:50%;
    background:color-mix(in srgb,var(--c) 20%,#1a1a2e);
    border:2.5px solid color-mix(in srgb,var(--c) 60%,transparent);
    display:flex; align-items:center; justify-content:center;
    font-size:44px;
    box-shadow:0 0 40px color-mix(in srgb,var(--c) 30%,transparent), inset 0 1px 1px rgba(255,255,255,0.1);
  }
  .vmo-officer-info { text-align:center; }
  .vmo-officer-name { font-size:16px; font-weight:700; color:#f0f4ff; margin-bottom:4px; }
  .vmo-officer-dept { font-size:12px; color:rgba(255,255,255,0.4); margin-bottom:10px; }
  .vmo-live-badge { display:inline-flex; align-items:center; gap:6px; background:rgba(5,150,105,0.15); border:1px solid rgba(5,150,105,0.3); border-radius:20px; padding:4px 12px; font-size:11px; color:#34d399; }
  .vmo-live-dot { width:6px; height:6px; border-radius:50%; background:#34d399; animation:vmoBlink 1.8s ease-in-out infinite; flex-shrink:0; }
  @keyframes vmoBlink { 0%,100%{opacity:1} 50%{opacity:0.3} }

  /* ── Chat ── */
  .vmo-chat-area { flex:1; display:flex; flex-direction:column; overflow:hidden; border-top:1px solid rgba(255,255,255,0.06); }
  .vmo-chat-messages { flex:1; overflow-y:auto; padding:16px; display:flex; flex-direction:column; gap:10px; scrollbar-width:thin; scrollbar-color:rgba(255,255,255,0.1) transparent; }
  .vmo-chat-welcome { padding:4px 0; }
  .vmo-welcome-text { font-size:12.5px; color:rgba(255,255,255,0.5); line-height:1.6; margin-bottom:12px; }
  .vmo-quick-btns { display:flex; flex-direction:column; gap:6px; }
  .vmo-qbtn { background:rgba(255,255,255,0.05); border:1px solid rgba(255,255,255,0.1); border-radius:8px; padding:7px 10px; text-align:left; font-size:11.5px; color:rgba(255,255,255,0.55); cursor:pointer; transition:all .12s; line-height:1.4; }
  .vmo-qbtn:hover { background:color-mix(in srgb,var(--c) 15%,transparent); border-color:color-mix(in srgb,var(--c) 50%,transparent); color:#fff; }
  /* color-mix() fallbacks for Safari < 16.2 and other older browsers */
  @supports not (color: color-mix(in srgb, red, blue)) {
    .vmo-officer-panel::before { background: radial-gradient(ellipse at 50% 30%, rgba(99,102,241,0.12) 0%, transparent 70%); }
    .vmo-pulse-ring { border-color: rgba(99,102,241,0.4); }
    .vmo-avatar-circle { background: rgba(26,26,46,0.85); border-color: rgba(99,102,241,0.6); box-shadow: 0 0 40px rgba(99,102,241,0.25), inset 0 1px 1px rgba(255,255,255,0.1); }
    .vmo-qbtn:hover { background: rgba(99,102,241,0.12); border-color: rgba(99,102,241,0.4); }
    .vmo-chat-input:focus { box-shadow: 0 0 0 3px rgba(99,102,241,0.2); }
  }
  .vmo-bubble { max-width:92%; }
  .vmo-bubble-user { align-self:flex-end; }
  .vmo-bubble-assistant { align-self:flex-start; }
  .vmo-bubble-user .vmo-bubble-text { background:var(--c); color:#fff; padding:9px 13px; border-radius:14px 14px 4px 14px; font-size:12.5px; line-height:1.5; }
  .vmo-bubble-assistant .vmo-bubble-text { background:rgba(255,255,255,0.07); color:#e0e6f0; padding:9px 13px; border-radius:14px 14px 14px 4px; font-size:12.5px; line-height:1.6; white-space:pre-wrap; }
  .vmo-chat-form { display:flex; gap:8px; padding:12px; border-top:1px solid rgba(255,255,255,0.06); flex-shrink:0; }
  .vmo-chat-input { flex:1; background:rgba(255,255,255,0.07); border:1px solid rgba(255,255,255,0.12); border-radius:10px; padding:8px 12px; font-size:13px; color:#fff; outline:none; }
  .vmo-chat-input::placeholder { color:rgba(255,255,255,0.25); }
  .vmo-chat-input:focus { border-color:var(--c); box-shadow:0 0 0 3px color-mix(in srgb,var(--c) 20%,transparent); }
  .vmo-send-btn { background:var(--c); border:none; border-radius:10px; padding:8px 12px; color:#fff; cursor:pointer; display:flex; align-items:center; transition:filter .15s; }
  .vmo-send-btn:hover { filter:brightness(1.15); }

  /* ── Data wall (right) ── */
  .vmo-data-wall { flex:1; overflow-y:auto; padding:20px; display:flex; flex-direction:column; gap:16px; background:#0d0d20; scrollbar-width:thin; scrollbar-color:rgba(255,255,255,0.1) transparent; }

  /* Briefing */
  .vmo-briefing-bar { flex-shrink:0; }
  .vmo-briefing { display:flex; align-items:flex-start; gap:12px; background:linear-gradient(135deg,rgba(37,99,235,0.15),rgba(26,26,46,0.8)); border:1px solid rgba(37,99,235,0.25); border-radius:12px; padding:14px 16px; }
  .vmo-briefing-sun { font-size:20px; flex-shrink:0; margin-top:1px; }
  .vmo-briefing-body { flex:1; }
  .vmo-briefing-text { font-size:13px; color:#c7d7f4; line-height:1.55; margin-bottom:10px; }
  .vmo-briefing-pills { display:flex; flex-wrap:wrap; gap:8px; }
  .vmo-pill { padding:3px 10px; border-radius:20px; font-size:11px; font-weight:500; }
  .vmo-pill-blue   { background:rgba(37,99,235,.2); color:#93c5fd; }
  .vmo-pill-orange { background:rgba(217,119,6,.2); color:#fcd34d; }
  .vmo-pill-purple { background:rgba(124,58,237,.2); color:#c4b5fd; }
  .vmo-briefing-x { background:none; border:none; color:rgba(255,255,255,.3); cursor:pointer; font-size:14px; padding:2px 4px; }

  /* KPI grid */
  .vmo-kpi-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; flex-shrink:0; }
  .vmo-kpi-card { background:rgba(255,255,255,0.04); border:1px solid rgba(255,255,255,0.08); border-radius:12px; padding:16px; transition:border-color .15s; }
  .vmo-kpi-card:hover { border-color:color-mix(in srgb,var(--c) 50%,transparent); }
  .vmo-kpi-label { font-size:10px; text-transform:uppercase; letter-spacing:.06em; color:rgba(255,255,255,0.4); font-weight:600; margin-bottom:8px; }
  .vmo-kpi-value { font-size:20px; font-weight:700; color:#f0f4ff; display:flex; align-items:center; gap:6px; }
  .vmo-kpi-sub { font-size:11px; color:rgba(255,255,255,0.3); margin-top:5px; }
  .vmo-trend-up   { color:#34d399; font-size:14px; }
  .vmo-trend-down { color:#f87171; font-size:14px; }
  .vmo-kpi-loading { grid-column:1/-1; color:rgba(255,255,255,.3); padding:20px; text-align:center; font-size:13px; }
  .vmo-kpi-err { background:rgba(239,68,68,.1); color:#f87171; border-radius:8px; padding:12px; font-size:13px; }

  /* Chart */
  .vmo-chart-panel { background:rgba(255,255,255,0.03); border:1px solid rgba(255,255,255,0.07); border-radius:12px; padding:20px; }
  .vmo-chart-controls { display:flex; align-items:center; gap:8px; padding:8px 4px 4px; flex-wrap:wrap; }
  .vmo-ctrl-group { display:flex; gap:3px; background:rgba(255,255,255,0.04); border-radius:8px; padding:3px; }
  .vmo-ctrl-range, .vmo-ctrl-metric { background:transparent; border:none; color:rgba(255,255,255,0.4); cursor:pointer; font-size:11px; padding:4px 10px; border-radius:6px; transition:all .12s; white-space:nowrap; }
  .vmo-ctrl-range:hover, .vmo-ctrl-metric:hover { background:rgba(255,255,255,0.1); color:#fff; }
  .vmo-ctrl-range.active, .vmo-ctrl-metric.active { background:rgba(37,99,235,0.25); color:#60a5fa; font-weight:600; }
  .vmo-chart-canvas { flex:1; }
  .vmo-chart-title { font-size:12px; font-weight:600; color:rgba(255,255,255,0.5); text-transform:uppercase; letter-spacing:.05em; margin-bottom:16px; }
  .vmo-chart-placeholder { text-align:center; color:rgba(255,255,255,.2); padding:60px 0; }
  .vmo-no-data { text-align:center; color:rgba(255,255,255,.25); padding:40px; font-size:13px; }
  .vmo-warn { background:rgba(217,119,6,.1); border:1px solid rgba(217,119,6,.3); border-radius:8px; padding:10px 14px; margin-top:12px; font-size:13px; color:#fcd34d; }

  /* Dead stock */
  .vmo-dead-stock { background:rgba(255,255,255,0.03); border:1px solid rgba(255,255,255,0.07); border-radius:12px; padding:16px; }
  .vmo-dead-title { font-size:11px; font-weight:600; color:rgba(255,255,255,0.4); text-transform:uppercase; letter-spacing:.05em; margin-bottom:12px; }
  .vmo-dead-row { display:flex; justify-content:space-between; padding:8px 0; border-bottom:1px solid rgba(255,255,255,0.05); font-size:12.5px; color:rgba(255,255,255,0.65); }
  .vmo-dead-row:last-child { border-bottom:none; }

  /* IT table */
  .vmo-it-table { overflow-x:auto; }
  .vmo-it-table table { width:100%; border-collapse:collapse; font-size:12.5px; }
  .vmo-it-table th { padding:10px 12px; text-align:left; background:rgba(255,255,255,0.04); border-bottom:1px solid rgba(255,255,255,0.08); font-size:10px; text-transform:uppercase; letter-spacing:.05em; color:rgba(255,255,255,0.4); }
  .vmo-it-table td { padding:10px 12px; border-bottom:1px solid rgba(255,255,255,0.05); color:rgba(255,255,255,0.7); }
  .vmo-red { color:#f87171; font-weight:600; }
  .vmo-green { color:#34d399; font-weight:600; }

  /* Order panels */
  .vmo-order-panel { background:rgba(255,255,255,0.03); border:1px solid rgba(255,255,255,0.07); border-radius:12px; padding:20px; }
  .vmo-order-header { display:flex; align-items:baseline; justify-content:space-between; margin-bottom:16px; gap:12px; }
  .vmo-order-title { font-size:14px; font-weight:700; color:#f0f4ff; }
  .vmo-order-meta  { font-size:11px; color:rgba(255,255,255,0.35); }
  .vmo-order-table-wrap { overflow-x:auto; }
  .vmo-order-table { width:100%; border-collapse:collapse; font-size:12px; }
  .vmo-order-table th { padding:8px 10px; text-align:left; background:rgba(255,255,255,0.04); border-bottom:1px solid rgba(255,255,255,0.08); font-size:10px; text-transform:uppercase; letter-spacing:.05em; color:rgba(255,255,255,0.4); white-space:nowrap; }
  .vmo-order-table td { padding:8px 10px; border-bottom:1px solid rgba(255,255,255,0.04); color:rgba(255,255,255,0.7); white-space:nowrap; }
  .vmo-order-table tr:last-child td { border-bottom:none; }
  .vmo-ord-kritik td { background:rgba(239,68,68,0.06); }
  .vmo-ord-dusuk  td { background:rgba(245,158,11,0.06); }
  .vmo-ord-krtk   td { background:rgba(239,68,68,0.06); }
  .vmo-status-badge { display:inline-block; padding:2px 8px; border-radius:20px; font-size:10px; font-weight:700; }
  .vmo-status-kritik { background:rgba(239,68,68,.2); color:#fca5a5; }
  .vmo-status-dusuk  { background:rgba(245,158,11,.2); color:#fcd34d; }
  .vmo-status-ok     { background:rgba(5,150,105,.2); color:#6ee7b7; }
  .vmo-amber { color:#fcd34d; font-weight:600; }
  .vmo-red   { color:#fca5a5; font-weight:600; }

  /* ── Orders Room ── */
  .vmo-orders-wall { display:flex; flex-direction:column; gap:0; padding:0; overflow:hidden; height:100%; }
  .vmo-section-tabs,
  .vmo-segment-tabs,
  .vmo-mode-tabs { display:flex; gap:6px; padding:10px 16px 6px; flex-shrink:0; flex-wrap:wrap; align-items:center; }
  .vmo-section-tabs { border-bottom:1px solid rgba(255,255,255,0.08); padding-bottom:8px; background:rgba(0,0,0,0.15); }
  .vmo-segment-tabs { padding-top:8px; padding-bottom:4px; }
  .vmo-mode-tabs { padding-top:4px; padding-bottom:8px; border-bottom:1px solid rgba(255,255,255,0.06); }
  .vmo-stab-section,
  .vmo-stab-seg,
  .vmo-stab-mode { padding:5px 12px; border:1px solid rgba(255,255,255,0.18); border-radius:20px; background:rgba(255,255,255,0.06); color:rgba(255,255,255,0.75); font-size:12px; font-weight:500; cursor:pointer; transition:all .15s; white-space:nowrap; }
  .vmo-stab-section:hover, .vmo-stab-seg:hover, .vmo-stab-mode:hover { background:rgba(255,255,255,0.14); color:#fff; }
  .vmo-stab-section.active { background:#0891b2; border-color:#0891b2; color:#fff; font-weight:600; }
  .vmo-stab-seg.active     { background:rgba(8,145,178,0.3); border-color:#38bdf8; color:#e0f2fe; font-weight:600; }
  .vmo-stab-mode.active    { background:rgba(124,58,237,0.3); border-color:#a78bfa; color:#ede9fe; font-weight:600; }
  .vmo-budget-input { display:flex; align-items:center; gap:6px; margin-left:8px; color:rgba(255,255,255,0.7); font-size:12px; }
  .vmo-budget-input input { background:rgba(255,255,255,0.08); border:1px solid rgba(255,255,255,0.2); border-radius:8px; padding:4px 8px; color:#fff; font-size:12px; width:110px; }
  .vmo-budget-input input:focus { outline:none; border-color:#a78bfa; }
  .vmo-budget-apply { padding:4px 12px; background:#7c3aed; border:none; border-radius:8px; color:#fff; font-size:12px; cursor:pointer; font-weight:600; }
  .vmo-budget-apply:hover { background:#6d28d9; }

  /* Summary stat bar */
  .vmo-ord-summary { display:flex; align-items:center; gap:20px; padding:10px 16px; background:rgba(255,255,255,0.02); border-bottom:1px solid rgba(255,255,255,0.06); flex-shrink:0; flex-wrap:wrap; }
  .vmo-ord-stat { display:flex; flex-direction:column; align-items:center; min-width:56px; }
  .vmo-ord-stat-val { font-size:22px; font-weight:700; color:#e0e6f0; line-height:1; }
  .vmo-ord-stat-lbl { font-size:9px; text-transform:uppercase; letter-spacing:.08em; color:rgba(255,255,255,0.5); margin-top:3px; }
  .vmo-ord-stat-red   .vmo-ord-stat-val { color:#fca5a5; }
  .vmo-ord-stat-amber .vmo-ord-stat-val { color:#fcd34d; }
  .vmo-ord-budget-bar-wrap { flex:1; min-width:140px; }
  .vmo-ord-budget-label { font-size:10px; color:rgba(255,255,255,0.5); margin-bottom:4px; }
  .vmo-ord-budget-track { height:6px; background:rgba(255,255,255,0.08); border-radius:4px; overflow:hidden; }
  .vmo-ord-budget-fill  { height:100%; border-radius:4px; transition:width .4s; }

  /* Orders results table */
  .vmo-orders-results { flex:1; overflow-y:auto; overflow-x:auto; padding:0; min-height:0; }
  .vmo-orders-summary { flex-shrink:0; }
  .vmo-order-table-full { width:100%; border-collapse:collapse; font-size:12px; }
  .vmo-order-table-full th { padding:8px 10px; text-align:left; background:#0c1526 !important; border-bottom:2px solid rgba(255,255,255,0.25); font-size:11px; font-weight:700 !important; text-transform:uppercase; letter-spacing:.07em; color:#e2e8f0 !important; white-space:nowrap; position:sticky; top:0; z-index:2; }
#owner-surface .vmo-order-table-full th,
#consultant-surface .vmo-order-table-full th,
#manager-surface .vmo-order-table-full th,
#platform-surface .vmo-order-table-full th,
.assessment-workspace-component .vmo-order-table-full th {
  color: var(--color-text) !important;
  background: var(--color-surface-raised) !important;
  border-color: var(--color-border-strong) !important;
}
  .vmo-order-table-full td { padding:7px 10px; border-bottom:1px solid rgba(255,255,255,0.05); color:rgba(255,255,255,0.8); white-space:nowrap; vertical-align:middle; }
  .vmo-order-table-full tbody tr:hover td { background:rgba(255,255,255,0.04); }
  .vmo-ord-idx  { color:rgba(255,255,255,0.3); font-size:11px; width:28px; }
  .vmo-ord-name { max-width:220px; overflow:hidden; text-overflow:ellipsis; color:#f0f4ff; font-weight:500; }
  .vmo-ord-code code { font-size:10px; background:rgba(255,255,255,0.08); padding:2px 6px; border-radius:4px; color:#93c5fd; }
  .vmo-ord-cost { font-weight:600; color:#c4b5fd; }
  .vmo-ord-total td { background:rgba(255,255,255,0.06); font-weight:700; border-top:2px solid rgba(255,255,255,0.15); color:#fff; }

  @media (max-width:960px) {
    .vmo-officer-panel { width:240px; min-width:240px; }
    .vmo-kpi-grid { grid-template-columns:repeat(2,1fr); }
  }
  @media (max-width:768px) {
    /* Stack room vertically so officer panel sits above data wall */
    .vmo-room { flex-direction:column !important; height:auto; overflow:visible; }
    /* Let the office container scroll vertically */
    .vmo-office { overflow-y:auto; }
    /* Compact header padding */
    .vmo-header { padding:6px 8px 0; gap:2px; }
    /* Hide ticker on mobile — too narrow */
    .vmo-macro-ticker { display:none; }
    .vmo-tenant { display:none; }
    .vmo-feedback-btn { display:none; }
    /* Nav tabs: horizontal scroll, no wrap, hidden scrollbar */
    .vmo-tabs { overflow-x:auto; flex-wrap:nowrap; scrollbar-width:none; width:100%; box-sizing:border-box; }
    .vmo-tabs::-webkit-scrollbar { display:none; }
    .vmo-tab { flex-shrink:0; padding:5px 8px; font-size:11px; white-space:nowrap; }
    /* Officer panel: full-width compact strip at top of room */
    .vmo-officer-panel { width:100% !important; min-width:0 !important; max-height:45vh; min-height:280px; overflow-y:auto; border-right:none !important; border-bottom:1px solid rgba(255,255,255,0.09); flex-shrink:0; }
    /* Data wall: full width with comfortable mobile padding */
    .vmo-data-wall { padding:10px 8px; flex:1; overflow-x:hidden; }
    /* KPI grid: 2 columns on mobile */
    .vmo-kpi-grid { grid-template-columns:repeat(2,1fr) !important; gap:8px; }
    /* Section sub-tabs: horizontal scroll, hidden scrollbar */
    .vmo-section-tabs { overflow-x:auto; white-space:nowrap; scrollbar-width:none; }
    .vmo-section-tabs::-webkit-scrollbar { display:none; }
    /* Tables: block display + horizontal scroll */
    .vmo-data-wall table { display:block; overflow-x:auto; max-width:100%; }
    /* Price list scenario bar: wrap on small screens */
    ._scenario-bar,#_scenario-bar,.pl-scenario-bar { flex-wrap:wrap; gap:6px; }
  }
  `;
}
