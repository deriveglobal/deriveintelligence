#!/usr/bin/env node
/**
 * add_rakip_piyasa_visual.mjs
 * Enhances the Piyasa tab with an auto-loading market overview:
 *   - Brand price cards (avg price + min price + source count)
 *   - Price distribution bar chart per brand (min→max range)
 *   - Seasonal breakdown summary (yazlık/kışlık/dört mevsim)
 *   - Source cheapest-wins matrix
 * The existing search form moves below the overview.
 * Idempotency: PIYASA_VISUAL_V1 marker
 */
import { readFileSync, writeFileSync } from 'fs';

const TARGET = '/opt/krb-assessment/shells/bi.js';
let src = readFileSync(TARGET, 'utf8');

if (src.includes('// PIYASA_VISUAL_V1')) {
  console.log('Zaten uygulandı'); process.exit(0);
}

// ── 1. Add /api/rakip/piyasa-ozet endpoint call in rfYukleOzet ───────────────
// Also add auto-load of market overview when Piyasa tab is first opened

// Find rfTab and add market overview auto-load on piyasa
const OLD_RFTAB_PIYASA = `      if (tab === 'izleme')   rfYukleIzle();
      if (tab === 'alarmlar') rfYukleAlarm();
      if (tab === 'ayarlar')  { rfYukleStats(); rfYukleAyarlar(); }`;

const NEW_RFTAB_PIYASA = `      if (tab === 'piyasa')   rfYuklePiyasaOzet();
      if (tab === 'izleme')   rfYukleIzle();
      if (tab === 'alarmlar') rfYukleAlarm();
      if (tab === 'ayarlar')  { rfYukleStats(); rfYukleAyarlar(); }`;

if (!src.includes(OLD_RFTAB_PIYASA)) {
  console.error('✗ rfTab bulunamadı'); process.exit(1);
}
src = src.replace(OLD_RFTAB_PIYASA, NEW_RFTAB_PIYASA);

// ── 2. Add market overview HTML block to Piyasa pane ─────────────────────────
const OLD_PIYASA_PANE = `        <div id="rf-pane-piyasa">
          <div style="display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap">`;

const NEW_PIYASA_PANE = `        <div id="rf-pane-piyasa">
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
          <div style="display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap">`;

if (!src.includes(OLD_PIYASA_PANE)) {
  console.error('✗ Piyasa pane bulunamadı'); process.exit(1);
}
src = src.replace(OLD_PIYASA_PANE, NEW_PIYASA_PANE);

// ── 3. Add rfYuklePiyasaOzet function before rfYukleOzet ─────────────────────
const BEFORE_OZET_FN = `    async function rfYukleOzet() {`;

const PIYASA_OZET_FN = `    let _piyasaOzetLoaded = false;
    async function rfYuklePiyasaOzet() {
      if (_piyasaOzetLoaded) return;
      const kartiEl = document.getElementById('rf-marka-karti-listesi');
      const metaEl  = document.getElementById('rf-piyasa-ozet-meta');
      if (!kartiEl) return;
      kartiEl.innerHTML = \`<div style="color:#778;font-size:13px">Piyasa yükleniyor...</div>\`;
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
          return \`<div style="background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.1);
                   border-radius:10px;padding:12px 16px;min-width:160px;cursor:pointer;transition:background .2s"
                   onmouseenter="this.style.background='rgba(255,255,255,0.09)'"
                   onmouseleave="this.style.background='rgba(255,255,255,0.05)'"
                   onclick="rfFiltreleKart('\${m.marka}')">
            <div style="display:flex;align-items:center;gap:6px;margin-bottom:8px">
              <div style="width:8px;height:8px;border-radius:50%;background:\${renk};flex-shrink:0"></div>
              <div style="font-size:13px;font-weight:700;color:#e2e8f0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:120px">\${m.marka}</div>
            </div>
            <div style="font-size:18px;font-weight:700;color:\${renk}">\${m.min_fiyat.toLocaleString('tr-TR')} ₺</div>
            <div style="font-size:11px;color:#889;margin-top:2px">min · maks \${m.max_fiyat.toLocaleString('tr-TR')} ₺</div>
            <!-- Price range bar -->
            <div style="margin-top:8px;height:3px;background:rgba(255,255,255,0.1);border-radius:2px;overflow:hidden">
              <div style="height:100%;background:\${renk};opacity:.7;width:\${Math.min(100,Math.round((range/m.max_fiyat)*200))}%"></div>
            </div>
            <div style="margin-top:6px;font-size:11px;color:#667">\${m.sku_sayisi} SKU · %\${pct} pay</div>
          </div>\`;
        }).join('');

        // Seasonal breakdown
        if (data.mevsimler?.length) {
          const mEl = document.getElementById('rf-mevsim-list');
          const mBar = document.getElementById('rf-mevsim-bar');
          if (mEl && mBar) {
            const mvRenk = { YAZLIK:'#f59e0b', KISLIK:'#3b82f6', DORTMEVSIM:'#10b981' };
            const total = data.mevsimler.reduce((s,m)=>s+m.sayi,0);
            mEl.innerHTML = data.mevsimler.map(m =>
              \`<div style="display:flex;align-items:center;gap:6px;background:rgba(255,255,255,0.05);
                   border-radius:6px;padding:5px 10px;font-size:12px">
                <div style="width:8px;height:8px;border-radius:50%;background:\${mvRenk[m.mevsim]||'#94a3b8'};flex-shrink:0"></div>
                <span style="color:#cbd5e0">\${m.mevsim||'Bilinmiyor'}</span>
                <span style="color:#94a3b8;font-weight:600">\${Math.round(m.sayi/total*100)}%</span>
              </div>\`
            ).join('');
            mBar.style.display = 'block';
          }
        }

        // Source wins matrix
        if (data.kaynak_kazanc?.length) {
          const kEl = document.getElementById('rf-kaynak-wins');
          const kBar = document.getElementById('rf-kaynak-matrix');
          if (kEl && kBar) {
            const total = data.kaynak_kazanc.reduce((s,k)=>s+k.kazanc,0);
            kEl.innerHTML = data.kaynak_kazanc.map(k =>
              \`<div style="background:rgba(255,255,255,0.05);border-radius:6px;padding:5px 12px;font-size:12px;color:#cbd5e0">
                <span style="font-weight:600">\${k.kaynak}</span>
                <span style="color:#64748b;margin-left:6px">en ucuz: \${Math.round(k.kazanc/total*100)}%</span>
              </div>\`
            ).join('');
            kBar.style.display = 'block';
          }
        }

        _piyasaOzetLoaded = true;
      } catch(e) {
        kartiEl.innerHTML = \`<div style="color:#667;font-size:13px">Piyasa özeti yüklenemedi.</div>\`;
      }
    }

    window.rfFiltreleKart = function(marka) {
      const el = document.getElementById('rf-marka');
      if (el) el.value = marka;
      rfPiyasaAra();
    };

    `;

if (!src.includes(BEFORE_OZET_FN)) {
  console.error('✗ rfYukleOzet bulunamadı'); process.exit(1);
}
src = src.replace(BEFORE_OZET_FN, PIYASA_OZET_FN + BEFORE_OZET_FN);

// Also auto-load on initial room render
const OLD_INIT = `    rfYukleOzet();

    window.rfPiyasaAra`;
const NEW_INIT = `    rfYukleOzet();
    rfYuklePiyasaOzet();

    window.rfPiyasaAra`;

if (src.includes(OLD_INIT)) {
  src = src.replace(OLD_INIT, NEW_INIT);
}

writeFileSync(TARGET, src, 'utf8');
console.log('✓ Piyasa visual overview eklendi');
console.log('  → Marka fiyat kartları (tıklanabilir filtre)');
console.log('  → Mevsim dağılımı + kaynak kazanç matrisi');
console.log('  → /api/rakip/piyasa-ozet endpoint gerekiyor');
