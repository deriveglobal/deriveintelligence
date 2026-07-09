// ============================================================
// Derive Intelligence — Brand Incentives Component
// Teşvik Yönetimi: brand cards, YAZ/KIŞ status, full table
// Usage: initBrandIncentives(container, me, callbacks)
//   callbacks.apiFetch(path, opts) — authenticated API call
// ============================================================

const CURRENCY_FLAG = { TRY: '🇹🇷', EUR: '🇪🇺', USD: '🇺🇸' };
const CURRENCY_COLOR = { TRY: '#22c55e', EUR: '#f59e0b', USD: '#3b82f6' };
const SEGMENT_LABEL = { PSR: 'Binek', HRD: 'SUV/HRD', TBR: 'Ağır Ticari', OTR: 'Off-Road' };
const KANAL_LABEL = { perakende: 'Perakende', toptan: 'Toptan' };

function escH(s) {
  return String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function pctBar(val, max = 45) {
  const w = Math.min(100, (val / max) * 100).toFixed(1);
  const color = val >= 35 ? '#22c55e' : val >= 25 ? '#f59e0b' : '#94a3b8';
  return `<div style="display:flex;align-items:center;gap:6px;">
    <div style="flex:1;height:6px;background:#334155;border-radius:3px;">
      <div style="width:${w}%;height:100%;background:${color};border-radius:3px;"></div>
    </div>
    <span style="font-size:12px;font-weight:600;color:${color};min-width:36px;">%${val}</span>
  </div>`;
}

function sezonBadge(yaz, kis) {
  const yazBadge = `<span style="padding:2px 7px;border-radius:10px;font-size:11px;font-weight:600;
    background:${yaz ? '#14532d' : '#1e1e2e'};color:${yaz ? '#86efac' : '#475569'};">
    ☀️ YAZ ${yaz ? '✓' : '—'}</span>`;
  const kisBadge = `<span style="padding:2px 7px;border-radius:10px;font-size:11px;font-weight:600;
    background:${kis ? '#1e3a5f' : '#1e1e2e'};color:${kis ? '#93c5fd' : '#475569'};">
    ❄️ KIŞ ${kis ? '✓' : '—'}</span>`;
  return `<div style="display:flex;gap:5px;flex-wrap:wrap;">${yazBadge}${kisBadge}</div>`;
}

function statusDot(yaz, kis) {
  if (yaz && kis)  return { color: '#22c55e', label: 'Tam' };
  if (yaz || kis)  return { color: '#f59e0b', label: 'Eksik Sezon' };
  return { color: '#ef4444', label: 'Yüklenmedi' };
}

function daysSince(dateStr) {
  if (!dateStr) return null;
  return Math.floor((Date.now() - new Date(dateStr).getTime()) / 86400000);
}

function staleness(dateStr) {
  const d = daysSince(dateStr);
  if (d === null) return { color: '#ef4444', label: 'Hiç yüklenmedi' };
  if (d <= 30)  return { color: '#22c55e', label: `${d} gün önce` };
  if (d <= 90)  return { color: '#f59e0b', label: `${d} gün önce` };
  return { color: '#ef4444', label: `${d} gün önce — güncelleme önerilir` };
}

export function initBrandIncentives(container, me, callbacks) {
  const { apiFetch } = callbacks;

  let state = {
    loading: true,
    error: null,
    data: null,
    view: 'cards',      // 'cards' | 'detail' | 'table'
    activeBrand: null,  // marka string
    sezonFilter: 'YAZ', // 'YAZ' | 'KIŞ' | 'TÜMÜ'
    yil: new Date().getFullYear(),
  };

  function render() {
    if (state.loading) {
      container.innerHTML = `<div style="padding:48px;text-align:center;color:#94a3b8;">
        <div style="font-size:32px;margin-bottom:12px;">⏳</div>
        <p>Teşvik verileri yükleniyor…</p>
      </div>`;
      return;
    }
    if (state.error) {
      container.innerHTML = `<div style="padding:32px;color:#ef4444;">Hata: ${escH(state.error)}</div>`;
      return;
    }

    const { brands, incentives, available_years } = state.data;

    const yearOpts = (available_years || [state.yil]).map(y =>
      `<option value="${y}" ${y == state.yil ? 'selected' : ''}>${y}</option>`
    ).join('');

    // Top bar
    const topBar = `
      <div style="display:flex;align-items:center;justify-content:space-between;
                  padding:16px 20px;border-bottom:1px solid #1e293b;gap:12px;flex-wrap:wrap;">
        <div style="display:flex;align-items:center;gap:12px;">
          ${state.view === 'detail' ? `<button id="bi-back-btn" style="
            padding:6px 12px;border-radius:8px;border:1px solid #334155;
            background:transparent;color:#94a3b8;cursor:pointer;font-size:13px;">
            ← Markalar
          </button>` : ''}
          <h2 style="margin:0;font-size:17px;font-weight:700;color:#e2e8f0;">
            ${state.view === 'detail'
              ? `${state.activeBrand} — Teşvik Detayı`
              : 'Teşvik Yönetimi'}
          </h2>
          <span style="padding:3px 9px;border-radius:20px;font-size:12px;
                       background:#1e293b;color:#94a3b8;">${state.yil}</span>
        </div>
        <div style="display:flex;align-items:center;gap:10px;">
          <!-- Year selector -->
          <select id="bi-year-sel" style="padding:6px 10px;border-radius:8px;
                  border:1px solid #334155;background:#0f172a;color:#e2e8f0;font-size:13px;">
            ${yearOpts}
          </select>
          <!-- Season filter (cards & table view) -->
          ${state.view !== 'detail' ? `
          <div style="display:flex;border:1px solid #334155;border-radius:8px;overflow:hidden;">
            ${['YAZ','KIŞ','TÜMÜ'].map(s => `
              <button data-sezon="${s}" style="
                padding:6px 13px;border:none;cursor:pointer;font-size:12px;font-weight:600;
                background:${state.sezonFilter===s ? '#1d4ed8' : 'transparent'};
                color:${state.sezonFilter===s ? '#fff' : '#94a3b8'};">
                ${s === 'YAZ' ? '☀️ Yaz' : s === 'KIŞ' ? '❄️ Kış' : '📋 Tümü'}
              </button>`).join('')}
          </div>` : ''}
          <!-- View toggle -->
          ${state.view !== 'detail' ? `
          <div style="display:flex;border:1px solid #334155;border-radius:8px;overflow:hidden;">
            <button data-nav-view="cards" style="padding:6px 12px;border:none;cursor:pointer;font-size:13px;
              background:${state.view==='cards' ? '#334155' : 'transparent'};color:#e2e8f0;">
              ▦ Kartlar
            </button>
            <button data-nav-view="table" style="padding:6px 12px;border:none;cursor:pointer;font-size:13px;
              background:${state.view==='table' ? '#334155' : 'transparent'};color:#e2e8f0;">
              ≡ Tablo
            </button>
          </div>` : ''}
        </div>
      </div>`;

    let body = '';
    if (state.view === 'cards') {
      body = renderCards(brands, incentives);
    } else if (state.view === 'detail') {
      body = renderDetail(brands, incentives, state.activeBrand);
    } else {
      body = renderFullTable(incentives, state.sezonFilter);
    }

    container.innerHTML = `<div style="display:flex;flex-direction:column;height:100%;overflow:hidden;font-family:system-ui,sans-serif;">
      ${topBar}
      <div style="flex:1;overflow:auto;padding:20px;">${body}</div>
    </div>`;
    bindEvents();
  }

  function renderCards(brands, incentives) {
    if (!brands.length) return `<p style="color:#94a3b8;padding:24px;">Henüz teşvik verisi yüklenmedi.</p>`;

    // Filter by sezon if not TÜMÜ
    const filteredBrands = brands.filter(b => {
      if (state.sezonFilter === 'YAZ')  return parseInt(b.yaz_kayit, 10) > 0;
      if (state.sezonFilter === 'KIŞ')  return parseInt(b.kis_kayit, 10) > 0;
      return true;
    });

    const cards = filteredBrands.map(b => {
      const yazOk = parseInt(b.yaz_kayit, 10) > 0;
      const kisOk = parseInt(b.kis_kayit, 10) > 0;
      const st = statusDot(yazOk, kisOk);
      const stale = staleness(b.son_guncelleme);
      const maxPct = state.sezonFilter === 'KIŞ' ? b.max_kis_pct
                   : state.sezonFilter === 'YAZ' ? b.max_yaz_pct
                   : Math.max(b.max_yaz_pct || 0, b.max_kis_pct || 0);
      const curColor = CURRENCY_COLOR[b.fatura_kuru] || '#94a3b8';
      const fxRisk = b.fatura_kuru !== 'TRY';

      return `
        <div class="bi-brand-card" data-brand="${escH(b.marka)}" style="
          border:1px solid #1e293b;border-radius:12px;padding:20px;cursor:pointer;
          background:#0f172a;transition:border-color 0.15s;
          display:flex;flex-direction:column;gap:12px;
          &:hover{border-color:#334155;}">
          <!-- Header row -->
          <div style="display:flex;justify-content:space-between;align-items:flex-start;">
            <div>
              <div style="font-size:16px;font-weight:700;color:#f1f5f9;">${escH(b.marka)}</div>
              <div style="font-size:12px;color:#64748b;margin-top:2px;">${escH(b.tedarikci_adi)}</div>
            </div>
            <div style="display:flex;gap:6px;align-items:center;">
              <span style="padding:3px 8px;border-radius:8px;font-size:11px;font-weight:700;
                           background:${curColor}22;color:${curColor};border:1px solid ${curColor}44;">
                ${CURRENCY_FLAG[b.fatura_kuru] || ''} ${escH(b.fatura_kuru)}
              </span>
              ${fxRisk ? `<span title="Kur riski" style="font-size:14px;">⚠️</span>` : ''}
            </div>
          </div>

          <!-- Status dot + staleness -->
          <div style="display:flex;align-items:center;gap:8px;">
            <div style="width:8px;height:8px;border-radius:50%;background:${st.color};flex-shrink:0;"></div>
            <span style="font-size:12px;color:${st.color};font-weight:600;">${st.label}</span>
            <span style="font-size:11px;color:${stale.color};margin-left:auto;">${stale.label}</span>
          </div>

          <!-- Season badges -->
          ${sezonBadge(yazOk, kisOk)}

          <!-- Max incentive bar -->
          <div>
            <div style="font-size:11px;color:#64748b;margin-bottom:4px;">Max Teşvik (${state.sezonFilter === 'TÜMÜ' ? 'En yüksek' : state.sezonFilter})</div>
            ${maxPct ? pctBar(parseFloat(maxPct)) : '<span style="font-size:12px;color:#475569;">—</span>'}
          </div>

          <!-- Meta row -->
          <div style="display:flex;gap:12px;font-size:11px;color:#64748b;border-top:1px solid #1e293b;padding-top:10px;">
            <span>⏱ Vade: ${b.min_vade_gun}${b.maks_vade_gun > b.min_vade_gun ? '–'+b.maks_vade_gun : ''} gün</span>
            ${b.max_erken_odeme_pct ? `<span>💰 Erken: %${b.max_erken_odeme_pct}</span>` : ''}
            <span style="margin-left:auto;">${b.toplam_kayit} kayıt →</span>
          </div>
        </div>`;
    }).join('');

    return `
      <div style="margin-bottom:16px;display:flex;align-items:center;gap:8px;">
        <span style="font-size:13px;color:#64748b;">${filteredBrands.length} marka</span>
        ${state.sezonFilter !== 'TÜMÜ' ? `<span style="font-size:12px;color:#475569;">
          · ${state.sezonFilter === 'YAZ' ? '☀️ Yaz programı gösteriliyor' : '❄️ Kış programı gösteriliyor'}
        </span>` : ''}
        <div style="margin-left:auto;font-size:11px;color:#475569;background:#1e293b;
                    padding:4px 10px;border-radius:20px;">
          ⚠️ = EUR/USD fatura → kur riski
        </div>
      </div>
      <div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px;">
        ${cards}
      </div>`;
  }

  function renderDetail(brands, incentives, marka) {
    const brand = brands.find(b => b.marka === marka);
    if (!brand) return `<p style="color:#ef4444;">Marka bulunamadı.</p>`;

    const rows = incentives.filter(i => i.marka === marka);
    const yazRows = rows.filter(r => r.sezon === 'YAZ');
    const kisRows = rows.filter(r => r.sezon === 'KIŞ');

    function componentTable(items) {
      if (!items.length) return `<p style="color:#475569;font-size:13px;">Bu sezon için veri yok.</p>`;
      return `<div style="overflow-x:auto;">
        <table style="width:100%;border-collapse:collapse;font-size:13px;">
          <thead>
            <tr style="background:#1e293b;">
              <th style="padding:8px 12px;text-align:left;color:#94a3b8;font-weight:600;">Segment</th>
              <th style="padding:8px 12px;text-align:left;color:#94a3b8;font-weight:600;">Kanal</th>
              <th style="padding:8px 12px;text-align:right;color:#94a3b8;font-weight:600;">Fatura Altı</th>
              <th style="padding:8px 12px;text-align:right;color:#94a3b8;font-weight:600;">Dönem P.</th>
              <th style="padding:8px 12px;text-align:right;color:#94a3b8;font-weight:600;">Sellout P.</th>
              <th style="padding:8px 12px;text-align:right;color:#94a3b8;font-weight:600;">K.Sipariş</th>
              <th style="padding:8px 12px;text-align:right;color:#94a3b8;font-weight:600;">Büyüme B.</th>
              <th style="padding:8px 12px;text-align:right;color:#22c55e;font-weight:700;">MAX %</th>
              <th style="padding:8px 12px;text-align:right;color:#94a3b8;font-weight:600;">Vade</th>
              <th style="padding:8px 12px;text-align:right;color:#94a3b8;font-weight:600;">Erken Ö.</th>
            </tr>
          </thead>
          <tbody>
            ${items.map(r => `
              <tr style="border-bottom:1px solid #1e293b;">
                <td style="padding:8px 12px;color:#e2e8f0;">${escH(SEGMENT_LABEL[r.segment] || r.segment)}</td>
                <td style="padding:8px 12px;color:#94a3b8;">${escH(KANAL_LABEL[r.kanal] || r.kanal)}</td>
                <td style="padding:8px 12px;text-align:right;color:#e2e8f0;">%${r.fatura_alti_pct}</td>
                <td style="padding:8px 12px;text-align:right;color:#94a3b8;">%${r.donem_primi_pct}</td>
                <td style="padding:8px 12px;text-align:right;color:#94a3b8;">%${r.sellout_primi_pct}</td>
                <td style="padding:8px 12px;text-align:right;color:#94a3b8;">%${r.kesin_siparis_pct}</td>
                <td style="padding:8px 12px;text-align:right;color:#94a3b8;">
                  ${parseFloat(r.buyume_bonus_pct) > 0 ? `%${r.buyume_bonus_pct}` : '—'}
                </td>
                <td style="padding:8px 12px;text-align:right;color:#22c55e;font-weight:700;">%${r.max_toplam_pct}</td>
                <td style="padding:8px 12px;text-align:right;color:#94a3b8;">${r.odeme_vadesi_gun} gün</td>
                <td style="padding:8px 12px;text-align:right;color:#94a3b8;">
                  ${r.erken_odeme_iskonto_pct ? `%${r.erken_odeme_iskonto_pct}/${r.erken_odeme_gun}g` : '—'}
                </td>
              </tr>`).join('')}
          </tbody>
        </table>
      </div>`;
    }

    const curColor = CURRENCY_COLOR[brand.fatura_kuru] || '#94a3b8';
    const stale = staleness(brand.son_guncelleme);

    return `
      <!-- Brand summary strip -->
      <div style="display:flex;gap:16px;flex-wrap:wrap;margin-bottom:24px;">
        ${[
          { label: 'Para Birimi', value: `${CURRENCY_FLAG[brand.fatura_kuru]||''} ${brand.fatura_kuru}`, color: curColor },
          { label: 'Max Teşvik (YAZ)', value: brand.max_yaz_pct ? `%${brand.max_yaz_pct}` : '—', color: '#22c55e' },
          { label: 'Max Teşvik (KIŞ)', value: brand.max_kis_pct ? `%${brand.max_kis_pct}` : '—', color: '#93c5fd' },
          { label: 'Ödeme Vadesi', value: `${brand.min_vade_gun}${brand.maks_vade_gun > brand.min_vade_gun ? '–'+brand.maks_vade_gun : ''} gün`, color: '#e2e8f0' },
          { label: 'Son Güncelleme', value: stale.label, color: stale.color },
        ].map(m => `
          <div style="background:#0f172a;border:1px solid #1e293b;border-radius:10px;
                      padding:14px 18px;flex:1;min-width:140px;">
            <div style="font-size:11px;color:#64748b;margin-bottom:4px;">${m.label}</div>
            <div style="font-size:16px;font-weight:700;color:${m.color};">${m.value}</div>
          </div>`).join('')}
      </div>

      <!-- YAZ section -->
      <div style="margin-bottom:28px;">
        <h3 style="font-size:14px;font-weight:700;color:#f59e0b;margin:0 0 12px;">
          ☀️ Yaz Programı (${yazRows.length} kayıt)
        </h3>
        ${componentTable(yazRows)}
      </div>

      <!-- KIŞ section -->
      <div>
        <h3 style="font-size:14px;font-weight:700;color:#93c5fd;margin:0 0 12px;">
          ❄️ Kış Programı (${kisRows.length} kayıt)
        </h3>
        ${componentTable(kisRows)}
      </div>

      <!-- Notes -->
      ${rows.some(r => r.notlar) ? `
        <div style="margin-top:24px;">
          <h3 style="font-size:13px;font-weight:600;color:#64748b;margin:0 0 8px;">Notlar</h3>
          ${rows.filter(r => r.notlar).map(r => `
            <div style="background:#1e293b;border-radius:8px;padding:10px 14px;margin-bottom:6px;font-size:12px;color:#94a3b8;">
              <strong style="color:#e2e8f0;">${escH(r.segment)} / ${escH(r.kanal)} / ${escH(r.sezon)}:</strong>
              ${escH(r.notlar)}
            </div>`).join('')}
        </div>` : ''}`;
  }

  function renderFullTable(incentives, sezonFilter) {
    let rows = sezonFilter === 'TÜMÜ' ? incentives
             : incentives.filter(i => i.sezon === sezonFilter);

    if (!rows.length) return `<p style="color:#94a3b8;">Bu sezon için henüz veri yok.</p>`;

    const tableRows = rows.map(r => {
      const curColor = CURRENCY_COLOR[r.fatura_kuru] || '#94a3b8';
      return `
        <tr style="border-bottom:1px solid #1e293b;" class="bi-trow-brand" data-brand="${escH(r.marka)}">
          <td style="padding:7px 10px;color:#e2e8f0;font-weight:600;">${escH(r.marka)}</td>
          <td style="padding:7px 10px;color:#94a3b8;">${escH(r.tedarikci_adi)}</td>
          <td style="padding:7px 10px;">
            <span style="padding:2px 7px;border-radius:8px;font-size:11px;font-weight:600;
              background:${r.sezon==='YAZ'?'#92400e22':'#1e3a5f'};
              color:${r.sezon==='YAZ'?'#f59e0b':'#93c5fd'};">
              ${r.sezon === 'YAZ' ? '☀️ YAZ' : '❄️ KIŞ'}
            </span>
          </td>
          <td style="padding:7px 10px;color:#94a3b8;">${SEGMENT_LABEL[r.segment] || r.segment}</td>
          <td style="padding:7px 10px;color:#94a3b8;">${KANAL_LABEL[r.kanal] || r.kanal}</td>
          <td style="padding:7px 10px;text-align:right;color:#e2e8f0;">%${r.fatura_alti_pct}</td>
          <td style="padding:7px 10px;text-align:right;color:#94a3b8;">%${r.donem_primi_pct}</td>
          <td style="padding:7px 10px;text-align:right;color:#94a3b8;">%${r.sellout_primi_pct}</td>
          <td style="padding:7px 10px;text-align:right;color:#94a3b8;">%${r.kesin_siparis_pct}</td>
          <td style="padding:7px 10px;text-align:right;color:#22c55e;font-weight:700;font-size:14px;">
            %${r.max_toplam_pct}
          </td>
          <td style="padding:7px 10px;text-align:right;color:#94a3b8;">${r.odeme_vadesi_gun}g</td>
          <td style="padding:7px 10px;text-align:center;">
            <span style="padding:2px 7px;border-radius:6px;font-size:11px;font-weight:700;
              background:${curColor}22;color:${curColor};">${r.fatura_kuru}</span>
          </td>
          <td style="padding:7px 10px;text-align:center;">
            <button class="bi-trow-detail" data-brand="${escH(r.marka)}" style="
              padding:3px 8px;border-radius:6px;border:1px solid #334155;
              background:transparent;color:#94a3b8;cursor:pointer;font-size:11px;">Detay</button>
          </td>
        </tr>`;
    }).join('');

    return `
      <div style="overflow-x:auto;">
        <table style="width:100%;border-collapse:collapse;font-size:12px;">
          <thead>
            <tr style="background:#1e293b;position:sticky;top:0;">
              <th style="padding:9px 10px;text-align:left;color:#94a3b8;font-weight:600;white-space:nowrap;">Marka</th>
              <th style="padding:9px 10px;text-align:left;color:#94a3b8;font-weight:600;">Tedarikçi</th>
              <th style="padding:9px 10px;text-align:left;color:#94a3b8;font-weight:600;">Sezon</th>
              <th style="padding:9px 10px;text-align:left;color:#94a3b8;font-weight:600;">Segment</th>
              <th style="padding:9px 10px;text-align:left;color:#94a3b8;font-weight:600;">Kanal</th>
              <th style="padding:9px 10px;text-align:right;color:#94a3b8;font-weight:600;">Fatura Altı</th>
              <th style="padding:9px 10px;text-align:right;color:#94a3b8;font-weight:600;">Dönem P.</th>
              <th style="padding:9px 10px;text-align:right;color:#94a3b8;font-weight:600;">Sellout P.</th>
              <th style="padding:9px 10px;text-align:right;color:#94a3b8;font-weight:600;">K.Sipariş</th>
              <th style="padding:9px 10px;text-align:right;color:#22c55e;font-weight:700;">MAX %</th>
              <th style="padding:9px 10px;text-align:right;color:#94a3b8;font-weight:600;">Vade</th>
              <th style="padding:9px 10px;text-align:center;color:#94a3b8;font-weight:600;">Kur</th>
              <th style="padding:9px 10px;"></th>
            </tr>
          </thead>
          <tbody>${tableRows}</tbody>
        </table>
      </div>
      <div style="margin-top:12px;font-size:11px;color:#475569;">
        Toplam ${rows.length} kayıt
        ${sezonFilter !== 'TÜMÜ' ? `· ${sezonFilter === 'YAZ' ? '☀️ Yaz' : '❄️ Kış'} filtresi aktif` : ''}
      </div>`;
  }

  function bindEvents() {
    // Back button
    container.querySelector('#bi-back-btn')?.addEventListener('click', () => {
      state.view = 'cards'; state.activeBrand = null; render();
    });

    // Year selector
    container.querySelector('#bi-year-sel')?.addEventListener('change', e => {
      state.yil = parseInt(e.target.value, 10); loadData();
    });

    // Season filter buttons
    container.querySelectorAll('[data-sezon]').forEach(btn => {
      btn.addEventListener('click', () => {
        state.sezonFilter = btn.dataset.sezon; render();
      });
    });

    // View toggle
    container.querySelectorAll('[data-nav-view]').forEach(btn => {
      btn.addEventListener('click', () => { state.view = btn.dataset.navView; render(); });
    });

    // Brand card click → detail
    container.querySelectorAll('.bi-brand-card').forEach(card => {
      card.addEventListener('click', () => {
        state.activeBrand = card.dataset.brand;
        state.view = 'detail';
        render();
      });
      card.addEventListener('mouseenter', () => { card.style.borderColor = '#334155'; });
      card.addEventListener('mouseleave', () => { card.style.borderColor = '#1e293b'; });
    });

    // Table detail buttons
    container.querySelectorAll('.bi-trow-detail').forEach(btn => {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        state.activeBrand = btn.dataset.brand;
        state.view = 'detail';
        render();
      });
    });
  }

  async function loadData() {
    state.loading = true; state.error = null;
    render();
    try {
      const data = await apiFetch(`/api/bi/pricing/brand-incentives?yil=${state.yil}`);
      if (data.error) throw new Error(data.error);
      state.data = data;
      state.yil = data.yil;
    } catch(e) {
      state.error = e.message || 'Veri yüklenemedi.';
    }
    state.loading = false;
    render();
  }

  // Boot
  loadData();

  return {
    destroy() { container.innerHTML = ''; }
  };
}
